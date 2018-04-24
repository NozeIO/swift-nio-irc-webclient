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

import Dispatch
import IRCWebClient

let webServer = IRCWebClientServer()

signal(SIGINT) { // Safe? Unsafe. No idea :-)
  s in webServer.stopOnSignal(s)
}

webServer.listen()

#if false // produces Zombies in Xcode?
  dispatchMain()
#else
  try? webServer.serverChannel?.closeFuture.wait()
#endif
