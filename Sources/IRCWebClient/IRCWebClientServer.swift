//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-nio-irc open source project
//
// Copyright (c) 2018-2020 ZeeZide GmbH. and the swift-nio-irc project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIOIRC project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import class NIOConcurrencyHelpers.NIOAtomic
import NIO
import NIOHTTP1
import NIOWebSocket
import class NIOConcurrencyHelpers.Atomic
import struct Foundation.TimeInterval
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
    
    // When the IRC client successfully connects, those channels are
    // automagically joined.
    open var autoJoinChannels       : Set<String> = [ "#NIO", "#SwiftDE" ]
    
    // We can automatically send some messages after a timeout
    open var autoSendMessageTimeout : TimeInterval = 3.0
    open var autoSendMessages       : [ ( String, String ) ] = []
    
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
          .makeAddressResolvingHost(host, port: configuration.port)
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

  lazy var upgrader : HTTPServerProtocolUpgrader = {
    var sessionCounter = NIOAtomic.makeAtomic(value: 1)
    let config         = configuration
    
    func shouldUpgrade(channel: Channel, head: HTTPRequestHead)
         -> EventLoopFuture<HTTPHeaders?>
    {
      let promise = channel.eventLoop.makePromise(of: HTTPHeaders?.self)
      promise.succeed(HTTPHeaders())
      return promise.futureResult
    }
  
    func upgradeHandler(channel: Channel, head: HTTPRequestHead)
         -> EventLoopFuture<Void>
    {
      return channel.pipeline
        .removeHandler(name: "de.zeezide.irc.miniirc.web.http")
        .flatMap { ( _ ) -> EventLoopFuture<Void> in
          let nick = IRCNickName("Guest\(sessionCounter.add(1))")!
          let options = IRCClientOptions(
            port           : config.ircPort ?? DefaultIRCPort,
            host           : config.ircHost ?? config.host ?? "localhost",
            nickname       : nick,
            eventLoopGroup : channel.eventLoop
          )
          
          return channel.pipeline
            .addHandler(IRCWebSocketBridge(options: options),
                        name: "de.zeezide.irc.miniirc.web.socket")
        }
    }
  
    return NIOWebSocketServerUpgrader(shouldUpgrade: shouldUpgrade,
                                      upgradePipelineHandler: upgradeHandler)
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
        let config: NIOHTTPServerUpgradeConfiguration = (
          upgraders: [ upgrader ], completionHandler: { _ in }
        )
        return channel.pipeline
          .configureHTTPServerPipeline(withServerUpgrade: config)
          .flatMap {
            channel.pipeline
              .addHandler(endPoint, name: "de.zeezide.irc.miniirc.web.http")
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
    let host = configuration.externalHost ?? configuration.host ?? "localhost"
    let port = configuration.externalPort ?? configuration.port
    let scheme = port == 443 ? "wss" : "ws"
    
    func escapeJSString(_ s: String) -> String { return s } // TODO
    
    let onConnect = configuration.autoJoinChannels.map { channel in
      "self.connection.call('JOIN', '\(escapeJSString(channel))');"
    }.joined(separator: "\n")
    
    let onStartup : String = {
      // TBD: this should probably just move to onConnect
      guard !configuration.autoSendMessages.isEmpty else { return "" }
      let timeoutInMS = Int(configuration.autoSendMessageTimeout * 1000)
      var ms = "window.setTimeout(function() {\n"
      for ( recipient, message ) in configuration.autoSendMessages {
        ms += "   self.sendMessageToTarget("
        ms += "'\(escapeJSString(recipient))'"
        ms += ", "
        ms += "'\(escapeJSString(message))'"
        ms += ");\n"
      }
      ms += "}, \(timeoutInMS));\n"
      return ms
    }()
    
    let scripts = [
      "style"                         : rsrc_Client_css,
      "script.vc.MainVC.onConnect"    : onConnect,
      "script.app.onStartup"          : onStartup,
      
      "script.model.ClientUtils"      : rsrc_ClientUtils_js,
      "script.model.ClientConnection" : rsrc_ClientConnection_js,
      "script.model.ChatItem"         : rsrc_ChatItem_js,
      "script.vc.SidebarVC"           : rsrc_SidebarVC_js,
      "script.vc.MessagesVC"          : rsrc_MessagesVC_js,
      "script.vc.MainVC"              : rsrc_MainVC_js,
    ]
    
    var patterns = [
      "title"                         : "MiniIRC ✭ ZeeZide",
      "endpoint"                      : "\(scheme)://\(host):\(port)/websocket",
      "defaultNick"                   : "nick",
    ]
    
    func replacePatterns(in s: String, using variables: [ String : String ])
         -> String
    {
      var s = s
      for ( variable, text ) in variables {
        if variable.lowercased().contains("script") {
          s = s.replacingOccurrences(of: "{{\(variable)}}", with: text)
        }
        else {
          s = s.replacingOccurrences(of: "{{\(variable)}}",
                                     with: text.htmlEscaped)
        }
      }
      return s
    }
    
    for ( name, script ) in scripts {
      patterns[name] = replacePatterns(in: script, using: patterns)
    }
    
    var s = replacePatterns(in: rsrc_ClientInline_html, using: patterns)
    
    var bb = ByteBufferAllocator().buffer(capacity: 4096)
    bb.reserveCapacity(s.utf8.count)
    bb.writeString(s)
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
