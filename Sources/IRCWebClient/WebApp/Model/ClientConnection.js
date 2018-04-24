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

/// This corresponds to the NIOIRC.IRCMessage, though we don't split out the
/// IRCCommand value.
/// Also: We use some non-standard commands ...
const IRCMessage = function(origin, target, command, args) {
  this.time      = new Date();
  this.origin    = origin  || null;
  this.target    = target  || null;
  this.command   = command || "X-MISSING-COMMAND";
  this.arguments = args    || new Array();
};

/// Wraps the WebSocket connection to the IRC bridge.
const Connection = function(host, port, onMessage) {
  const self     = this;
  self.onMessage = onMessage;
  
  self.connect = function(onConnect) {
    self.onConnect      = onConnect;
    self.isFirstReceive = true;
    self.socket         = new WebSocket(`ws://${host}:${port}/websocket`);

    self.socket.onmessage = function(msg) {
      let ircMessage = null;
      try {
        const json = JSON.parse(msg.data);
        ircMessage = new IRCMessage(json["origin"],  json["target"],
                                    json["command"], json["arguments"])
      }
      catch(error) {
        console.error("failed to parse incoming message:", error);
      }
      
      self.onMessage(ircMessage);
      
      if (self.isFirstReceive) {
        if (self.onConnect !== undefined && ircMessage["command"] === "NICK") {
          // wait for 1st NICK
          self.isFirstReceive = false;
          self.onConnect();
        }
      }
    }
  };
  
  self.json = function(object) {
    self.socket.send(JSON.stringify(object));
  };
                                
  self.call = function(command, ...args) {
    self.json({ "command": command, "arguments": args });
  };
  
  self.send = function(stringMessage) { // TODO: remove me
    self.call("NOTICE", "*", stringMessage);
  };
}
