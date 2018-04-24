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

// Our model object for something we display in a chat list
const ChatItem = function(message, sender, time, isSystem, isRead) {
  this.message  = message  || "";
  this.sender   = sender   || "✭";
  this.time     = time     || new Date();
  this.isSystem = isSystem || false;
  this.isRead   = isRead   || false;
};
