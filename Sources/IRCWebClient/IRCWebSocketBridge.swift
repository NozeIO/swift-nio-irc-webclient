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

import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import NIO
import NIOFoundationCompat
import NIOWebSocket
import IRC

/**
 * A very simple IRC<->WebSocket bridge.
 *
 * This just exchanges `IRCMessage` objects on the wire. The objects are
 * encoded using the JSONEncoder (and `IRCMessage` itself already supports
 * `Codable`).
 */
open class IRCWebSocketBridge: ChannelInboundHandler {
  
  public typealias InboundIn   = WebSocketFrame
  public typealias OutboundOut = WebSocketFrame
  
  private var awaitingClose : Bool = false
  open    var ircClient     : IRCClient?
  
  open    var options : IRCClientOptions
  open    var channel : Channel?
  open    var nick    : IRCNickName
  
  public init(options: IRCClientOptions) {
    self.options = options
    self.nick    = options.nickname
  }
  
  
  // MARK: - Handler Setup
  
  open func setupInContext(_ ctx: ChannelHandlerContext) {
    assert(ircClient == nil, "IRC client already setup? \(self)")
    
    channel = ctx.channel
    
    ircClient = IRCClient(options: self.options)
    ircClient?.delegate = self
    ircClient?.connect()
  }
  open func teardown() {
    ircClient?.close()
    ircClient?.delegate = nil
    ircClient = nil
    channel = nil
  }
  
  open func handlerAdded(ctx: ChannelHandlerContext) {
    setupInContext(ctx)
  }
  open func handlerRemoved(ctx: ChannelHandlerContext) {
    teardown()
  }

  open func channelActive(ctx: ChannelHandlerContext) {
    setupInContext(ctx)
    ctx.fireChannelActive()
  }

  open func channelInactive(ctx: ChannelHandlerContext) {
    teardown()
    ctx.fireChannelInactive()
  }

  
  // MARK: - Reading
  
  func handleInput(_ bb: ByteBuffer, in ctx: ChannelHandlerContext) {
    guard let ircClient = ircClient else {
      send("ERROR: not connected to IRC?")
      return
    }

    let data = bb.getData(at: bb.readerIndex, length: bb.readableBytes)!
    do {
      let message = try JSONDecoder().decode(IRCMessage.self, from: data)
      ircClient.sendMessage(message)
    }
    catch {
      print("ERROR: Could not decode JSON!", error)
      send("ERROR: \(error)")
    }
  }
  
  /// Process WebSocket frames.
  open func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
    let frame = self.unwrapInboundIn(data)
    
    switch frame.opcode {
      case .connectionClose:
        self.receivedClose(ctx: ctx, frame: frame)
      
      case .ping:
        self.pong(ctx: ctx, frame: frame)
      
      case .unknownControl, .unknownNonControl:
        self.closeOnError(ctx: ctx)
      
      case .continuation:
        print("CONT")
      
      case .text:
        handleInput(frame.unmaskedData, in: ctx)
      
      case .binary:
        handleInput(frame.unmaskedData, in: ctx)

      case .pong:
        print("unexpected pong?")
        self.closeOnError(ctx: ctx)
    }
  }
  
  func send(_ msg: IRCMessage, to channel: Channel) {
    guard let data = try? JSONEncoder().encode(msg) else {
      print("Could not encode JSON!", msg)
      return
    }
    
    var buffer = channel.allocator.buffer(capacity: data.count)
    buffer.write(bytes: data)
    
    let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
    channel.write(frame, promise: nil)
    channel.flush()
  }
  
  func send(_ s: String, to channel: Channel) {
    send(IRCMessage(command: .NOTICE([.everything], s)), to: channel)
  }
  func send(_ s: String, to ctx: ChannelHandlerContext) {
    send(s, to: ctx.channel)
  }
  func send(_ s: String) {
    guard let channel = channel else { return }
    send(s, to: channel)
    channel.flush()
  }
  func send(_ msg: IRCMessage) {
    guard let channel = channel else { return }
    send(msg, to: channel)
    channel.flush()
  }

  open func channelReadComplete(ctx: ChannelHandlerContext) {
    ctx.flush()
  }
  
  private func receivedClose(ctx: ChannelHandlerContext, frame: WebSocketFrame) {
    if awaitingClose {
      return ctx.close(promise: nil)
    }
    
    var data          = frame.unmaskedData
    let closeDataCode = data.readSlice(length: 2)
                     ?? ctx.channel.allocator.buffer(capacity: 0)
    let closeFrame    = WebSocketFrame(fin: true, opcode: .connectionClose,
                                       data: closeDataCode)
    _ = ctx.write(wrapOutboundOut(closeFrame)).map { () in
      ctx.close(promise: nil)
    }
  }
  
  private func pong(ctx: ChannelHandlerContext, frame: WebSocketFrame) {
    var frameData  = frame.data
    let maskingKey = frame.maskKey
    
    if let maskingKey = maskingKey {
      frameData.webSocketUnmask(maskingKey)
    }
    
    let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
    ctx.write(self.wrapOutboundOut(responseFrame), promise: nil)
  }
  
  private func closeOnError(ctx: ChannelHandlerContext) {
    // We have hit an error, we want to close. We do that by sending a close
    // frame and then shutting down the write side of the connection.
    var data = ctx.channel.allocator.buffer(capacity: 2)
    data.write(webSocketErrorCode: .protocolError)
    let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
    _ = ctx.write(self.wrapOutboundOut(frame)).then {
      ctx.close(mode: .output)
    }
    awaitingClose = true
  }
}

extension IRCWebSocketBridge : IRCClientDelegate {
  
  open func client(_ client: IRCClient, registered nick: IRCNickName,
                   with userInfo: IRCUserInfo)
  {
    self.nick = nick
    send(IRCMessage(command: .NICK(nick)))
  }
  open func client(_ client: IRCClient, changedNickTo nick: IRCNickName) {
    self.nick = nick
    send(IRCMessage(command: .NICK(nick)))
  }

  open func client(_ client: IRCClient, received message: IRCMessage) {
    #if false // send along any other message
      send(message)
    #endif
  }

  open func clientFailedToRegister(_ client: IRCClient) {
    print("BRIDGE could not register:", client)
    send("failed to register")
  }

  open func client(_ client: IRCClient, messageOfTheDay message: String) {
    send(message)
  }

  open func client(_ client: IRCClient,
                   notice message: String,
                   for recipients: [IRCMessageRecipient])
  {
    send(message)
  }
  
  open func client(_ client: IRCClient,
                   message: String, from sender: IRCUserID,
                   for recipients: [IRCMessageRecipient])
  {
    send(IRCMessage(origin: sender.nick.stringValue,
                    command: .PRIVMSG(recipients, message)))
  }
  
  open func client(_ client: IRCClient, changedUserModeTo mode: IRCUserMode) {
    // TODO
  }

  open func client(_ client: IRCClient,
                   user: IRCUserID, joined channels: [ IRCChannelName ])
  {
    send(IRCMessage(origin: user.nick.stringValue,
                    command: .JOIN(channels: channels, keys: nil)))
  }
  open func client(_ client: IRCClient,
                   user: IRCUserID, left channels: [ IRCChannelName ],
                   with message: String?)
  {
    send(IRCMessage(origin: user.nick.stringValue,
                    command: .PART(channels: channels, message: message)))
  }

  open func client(_ client: IRCClient,
                   changeTopic welcome: String, of channel: IRCChannelName)
  {
    send(IRCMessage(command: .otherCommand("Z-CHANNEL-TOPIC",
                                           [ channel.stringValue, welcome ])))
  }
}
