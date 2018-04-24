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

const MainVC = function(nick, host, port) {
  const self = this;
  
  self.serverTarget = "server";

  self.targets = {
    "server": Array()
  };
  self.activeTarget = self.serverTarget;

  self.loadView = function() {
    const self = this;
    self.view = document.querySelector(".chat");
  
    self.sidebar  = new SidebarVC(self.onTargetChange);
    self.messages = new MessagesVC(self.onLine);
    self.sidebar.loadView(self.view);
    self.messages.loadView(self.view);
  };

  self.systemNick = "✭";
  self.nick       = null; // nick is assigned by the server

  self.commandMap = {
    "/nick": function(name) {
      self.connection.call("NICK", name);
    },
    "/join": function(target) {
      if (!target.startsWith("#")) target = "#" + target;
      const lc = target.toLowerCase();
      self.connection.call("JOIN", target);
      if (self.targets[lc] === undefined) self.targets[lc] = new Array();
      self.sidebar.addChannelView(target, true);
    },
    "/part": function(name) {
      if (name === undefined) {
        if (!self.activeTarget.startsWith("#")) return;
        name = self.activeTarget;
      }
      self.connection.call("PART", name);
    },
    "/msg": function(target, ...message) {
      self.sendMessageToTarget(target, message.join(" "));
    },
    "/help": function() {
      self.addItem(self.activeTarget, self.systemNick, 
        `Available commands:
        /msg [nick or channel] message
        /nick [nickname] - change your nickname, e.g. /nick Grandmaster
        /join [channel]  - join a channel, e.g. /join #ZeeZide
        /part [channel]? - leave a channel, e.g. current /leave
        
        `, false, true);
    }
  };
  self.messageMap = {
    "NOTICE": function(message) {
      self.submit(this.systemNick, message.arguments[1] || "?", true);
    },
    "NICK": function(message) {
      if (message.arguments.length == 0) return;
      const name = message.arguments[0];
      self.nick = name;
      self.notice(`Changed nick to: ${name}`)
      self.sidebar.setNick(name);
    },
    "JOIN": function(message) {
      if (message.arguments.length < 1) return;
      const channel = message.arguments[0];
      if (message.origin === self.nick) {
        const lc = channel.toLowerCase();
        if (self.targets[lc] === undefined) self.targets[lc] = new Array();
        self.sidebar.addChannelView(channel, false);
      }
      else {
        self.addItem(channel, message.origin, 
                     `${message.origin} joined ${channel}.`, true);
      }
    },
    "PART": function(message) {
      if (message.arguments.length < 1) return;
      const channel = message.arguments[0];
      if (message.origin === self.nick)
        self.sidebar.removeChannelView(channel);
      else {
        self.addItem(channel, message.origin, 
                     `${message.origin} left ${channel}.`, true, true);
      }
    },
    "PRIVMSG": function(message) {
      if (message.arguments.length < 2) return;
      const target = message.arguments[0];
      const text   = message.arguments[1];
      const sender = message.origin || "???";
      
      if (target.toLowerCase() === self.nick.toLowerCase()) {
        if (self.targets[sender.toLowerCase()] === undefined)
          self.sidebar.addQueryView(sender, true);
        self.addItem(sender, sender, text);
      }
      else
        self.addItem(target, sender, text);
    },
    
    "Z-CHANNEL-TOPIC": function(message) {
      // TODO: set topic of a channel.
    }
  };
  
  // Add a chat message to the target arrays, and if the target is visible,
  // to the list of chats. If not visible, update the unread count.
  self.addItem = function(target, author, message, isSystem, isRead) {
    const lc   = target.toLowerCase();
    const item = new ChatItem(message, author, new Date(), isSystem, isRead);
    
    if (self.targets[lc] === undefined) self.targets[lc] = new Array();
    self.targets[lc].push(item);
    
    if (self.activeTarget === lc) {
      self.messages.addItem(item);
    }
    else {
      let unreadCount = 0;
      self.targets[lc].forEach(function(item) {
        if (!item.isRead) unreadCount++;
      });
      self.sidebar.updateUnreadCount(target, unreadCount);
    }
  }

  self.submit = function(author, message, isSystem ) { // DEPRECATED
    self.addItem(self.serverTarget, author, message, isSystem || false)
  };
  self.notice = function(message) { // DEPRECATED
    self.addItem(self.serverTarget, this.systemNick, message, true)
  };

  // Called by the SidebarVC when a new target is clicked.
  self.onTargetChange = function(newTarget) {
    const lc = newTarget.toLowerCase()
    if (self.activeTarget === lc) return;
  
    self.activeTarget = lc;
    self.messages.setTitle(newTarget);
    self.messages.setChatItems(self.targets[lc]);
    self.sidebar.updateUnreadCount(newTarget, 0);
  };

  // Called by the MessagesVC if the user enters a command line.
  self.onLine = function(line) {
    if (line.startsWith("/")) {
      const pair = line.split(" ");
      const cmd  = pair[0].toLowerCase();

      if (self.commandMap[cmd] !== undefined) {
        // TODO: slice&apply
        self.commandMap[cmd](pair[1], pair[2], pair[3], pair[4], pair[5]);
      }
      else {
        // TBD: we could still send this to the server!
        self.addItem(self.serverTarget, this.systemNick, 
                     `unknown command: ${cmd}`, true);
      }
      return;
    }
    
    if (self.activeTarget === self.serverTarget) {
      self.addItem(self.serverTarget, this.systemNick, 
                   "Cannot send message to server itself, /help for help!",
                   true);
    }
    else {
      self.sendMessageToTarget(self.activeTarget, line);
    }
  };
  
  self.sendMessageToTarget = function(target, message) {
    if (self.targets[target.toLowerCase()] === undefined) {
      if (target.startsWith("#"))
        return self.notice("You did not join this channel yet!");
      self.sidebar.addQueryView(target, true);
    }
    
    self.connection.call("PRIVMSG", target || self.activeTarget, message);
    self.addItem(target || self.activeTarget, self.nick, message, false, true);
  };
  
  
  // This is called when we receive a new IRC message from the bridge.
  self.onMessage = function(message) {
    if (self.messageMap[message.command] !== undefined)
      self.messageMap[message.command](message);
    else
      self.submit(self.systemNick, `unknown message: ${message.command}`, true);
  };
  
  self.connection = new Connection(
    host || "localhost",
    port || 1337,
    self.onMessage
  );
  
  self.connect = function() {
    self.notice("Connecting to IRC bridge ...");
    self.connection.connect(function() {
      self.connection.call("JOIN", "#NIO");
      self.connection.call("JOIN", "#NozeIO");
      self.connection.call("JOIN", "#ZeeQL");
      self.connection.call("JOIN", "#ApacheExpress");
      self.connection.call("JOIN", "#PLSwift");
      self.connection.call("JOIN", "#SwiftXcode");
      self.connection.call("JOIN", "#mod_swift");
    });
  };

  self.viewDidAppear = function() {
    const self = this;
    self.messages.viewDidAppear();
    
    window.setTimeout(function() {
      self.sidebar.addQueryView("Eliza")
    }, 3000);

    self.connect();
  };
}
