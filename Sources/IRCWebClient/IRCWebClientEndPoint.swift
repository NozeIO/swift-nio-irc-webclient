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

/**
 * A small HTTP handler which just delivers the single-page webapp included in
 * the module.
 */
open class IRCWebClientEndPoint: ChannelInboundHandler {
  
  public typealias InboundIn   = HTTPServerRequestPart
  public typealias OutboundOut = HTTPServerResponsePart
  
  let content : ByteBuffer
  
  public init(_ content: ByteBuffer) {
    self.content = content
  }

  open func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
    let reqPart = self.unwrapInboundIn(data)

    guard case .head(let head) = reqPart else { return }
    
    switch head.method {
      case .GET, .HEAD:
        send(html: content, includeBody: head.method != .HEAD, to: ctx)
      
      default:
        send(html: "Not supported", status: .methodNotAllowed, to: ctx)
    }
  }
}

fileprivate extension IRCWebClientEndPoint {
  
  func send(html: String, status: HTTPResponseStatus = .ok,
            to ctx: ChannelHandlerContext)
  {
    var bb = ByteBufferAllocator().buffer(capacity: html.utf8.count)
    bb.write(string: html)
    send(html: bb, status: status, to: ctx)
  }

  func send(html content: ByteBuffer, status: HTTPResponseStatus = .ok,
            includeBody   : Bool = true,
            closeWhenDone : Bool = true,
            to ctx: ChannelHandlerContext)
  {
    var headers = HTTPHeaders()
    headers.add(name: "Content-Type",   value: "text/html")
    headers.add(name: "Content-Length", value: String(content.readableBytes))
    if closeWhenDone {
      headers.add(name: "Connection",   value: "close")
    }
    
    let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1),
                                        status: .ok,
                                        headers: headers)
    
    ctx.write(wrapOutboundOut(.head(responseHead)), promise: nil)
    if includeBody {
      ctx.write(wrapOutboundOut(.body(.byteBuffer(content))), promise: nil)
    }
    ctx.write(wrapOutboundOut(.end(nil))).whenComplete {
      if closeWhenDone { ctx.close(promise: nil) }
    }
    ctx.flush()
  }

}
