//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-nio-irc open source project
//
// Copyright (c) 2018 ZeeZide GmbH. and the swift-nio-irc project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIOIRC project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import NIOHTTP1
import NIOWebSocket
import class NIOConcurrencyHelpers.Atomic
import IRC

/**
 * A small HTTP server which can deliver the single-page webapp included in the
 * module, and which also serves as the WebSocket endpoint (does the WebSocket
 * upgrade).
 *
 * Usage is trivial:
 *
 *     let webServer = IRCWebClientServer()
 *     webServer.listen()
 *
 * Options can be passed in using the `Configuration` object.
 */
open class IRCWebClientServer {
  
  open class Configuration {
    
    open var host           : String?         = "localhost"
    open var port           : Int             = 1337
    open var eventLoopGroup : EventLoopGroup? = nil
    open var backlog        : Int             = 256
    open var ircHost        : String?         = nil
    open var ircPort        : Int?            = nil
    open var externalHost   : String?         = nil
    open var externalPort   : Int?            = nil

    public init(eventLoopGroup: EventLoopGroup? = nil) {
      self.eventLoopGroup = eventLoopGroup
    }
  }

  public let configuration  : Configuration
  public let eventLoopGroup : EventLoopGroup

  public init(configuration: Configuration = Configuration()) {
    self.configuration  = configuration
    
    self.eventLoopGroup = configuration.eventLoopGroup
           ?? MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
  }

  public private(set) var serverChannel : Channel?
  
  open func listenAndWait() {
    listen()
    
    do {
      try serverChannel?.closeFuture.wait() // no close, no exit
    }
    catch {
      print("ERROR: failed to wait on server:", error)
    }
  }
  
  open func listen() {
    let bootstrap = makeBootstrap()
    
    do {
      let address : SocketAddress
      
      if let host = configuration.host {
        address = try SocketAddress
          .newAddressResolving(host: host, port: configuration.port)
      }
      else {
        var addr = sockaddr_in()
        addr.sin_port = in_port_t(configuration.port).bigEndian
        address = SocketAddress(addr, host: "*")
      }
      
      serverChannel = try bootstrap.bind(to: address)
                        .wait()
      
      
      if let addr = serverChannel?.localAddress {
        print("IRCWebClientServer running on:", addr)
      }
    }
    catch {
      print("failed to start server:", type(of:error), error)
    }
  }
  
  open func stopOnSignal(_ signal: Int32) {
    print("Received SIGINT scheduling shutdown...")
    // Safe? Unsafe. No idea. Probably not :-)
    exit(0)
  }

  // MARK: - Bootstrap

  lazy var upgrader : WebSocketUpgrader = {
    var sessionCounter = Atomic<Int>(value: 1)
    let config         = configuration
    
    let upgrader = WebSocketUpgrader(
      shouldUpgrade: { (head: HTTPRequestHead) in HTTPHeaders() },
      upgradePipelineHandler: { ( channel: Channel, _: HTTPRequestHead ) in
        channel.pipeline.remove(name: "de.zeezide.irc.miniirc.web.http")
          .then { _ in
            let nick = IRCNickName("Guest\(sessionCounter.add(1))")!
            let options = IRCClientOptions(
              port           : config.ircPort ?? DefaultIRCPort,
              host           : config.ircHost ?? config.host ?? "localhost",
              nickname       : nick,
              eventLoopGroup : channel.eventLoop
            )
            
            return channel.pipeline.add(
              name: "de.zeezide.irc.miniirc.web.socket",
              handler: IRCWebSocketBridge(options: options)
            )
          }
      }
    )
    return upgrader
  }()
  
  open func makeBootstrap() -> ServerBootstrap {
    let upgrader = self.upgrader
    let endPoint = IRCWebClientEndPoint(content)
    
    let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),
                                             SO_REUSEADDR)
    let bootstrap = ServerBootstrap(group: eventLoopGroup)
      // Specify backlog and enable SO_REUSEADDR for the server itself
      .serverChannelOption(ChannelOptions.backlog,
                           value: Int32(256))
      .serverChannelOption(reuseAddrOpt, value: 1)
      
      // Set the handlers that are applied to the accepted Channels
      .childChannelInitializer { channel in
        let config: HTTPUpgradeConfiguration = (
          upgraders: [ upgrader ], completionHandler: { _ in }
        )
        return channel.pipeline
          .configureHTTPServerPipeline(withServerUpgrade: config)
          .then {
            channel.pipeline.add(name: "de.zeezide.irc.miniirc.web.http",
                                 handler: endPoint)
          }
      }
      
      // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
      .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY),
                          value: 1)
      .childChannelOption(reuseAddrOpt, value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    
    return bootstrap
  }
  
  
  // MARK: - HTML Payload
  
  open lazy var content : ByteBuffer = {
    var bb = ByteBufferAllocator().buffer(capacity: 4096)
    
    let host = configuration.externalHost ?? configuration.host ?? "localhost"
    let port = configuration.externalPort ?? configuration.port
    
    let patterns = [
      "title":                         "MiniIRC ✭ ZeeZide",
      "endpoint":                      "ws://\(host):\(port)/websocket",
      "defaultNick":                   "nick",
      "style":                         rsrc_Client_css,
      "script.model.ClientUtils":      rsrc_ClientUtils_js,
      "script.model.ClientConnection": rsrc_ClientConnection_js,
      "script.model.ChatItem":         rsrc_ChatItem_js,
      "script.vc.SidebarVC":           rsrc_SidebarVC_js,
      "script.vc.MessagesVC":          rsrc_MessagesVC_js,
      "script.vc.MainVC":              rsrc_MainVC_js
    ]
    
    var s = rsrc_ClientInline_html
    
    for ( variable, text ) in patterns {
      if variable.lowercased().contains("script") {
        s = s.replacingOccurrences(of: "{{\(variable)}}", with: text)
      }
      else {
        s = s.replacingOccurrences(of: "{{\(variable)}}",
                                   with: text.htmlEscaped)
      }
    }
    
    bb.changeCapacity(to: s.utf8.count)
    bb.write(string: s)
    
    return bb
  }()

}

fileprivate extension String {
  var htmlEscaped : String {
    let escapeMap : [ Character : String ] = [
      "<" : "&lt;", ">": "&gt;", "&": "&amp;", "\"": "&quot;"
    ]
    return map { escapeMap[$0] ?? String($0) }.reduce("", +)
  }
}
