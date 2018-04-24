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


import Foundation

fileprivate let content : ByteBuffer = {
  var bb = ByteBufferAllocator().buffer(capacity: 4096)
  
  let patterns = [
    "title":                         "MiniIRC ✭ ZeeZide",
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
      s = s.replacingOccurrences(of: "{{\(variable)}}", with: text.htmlEscaped)
    }
  }
  
  bb.changeCapacity(to: s.utf8.count)
  bb.write(string: s)
  
  return bb
}()

fileprivate extension String {
  var htmlEscaped : String {
    let escapeMap : [ Character : String ] = [
      "<" : "&lt;", ">": "&gt;", "&": "&amp;", "\"": "&quot;"
    ]
    return map { escapeMap[$0] ?? String($0) }.reduce("", +)
  }
}
