// Generated from Model/ChatItem.js
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_ChatItem_js =
"""
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
"""
// Generated from Model/ClientConnection.js
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_ClientConnection_js =
"""
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
const Connection = function(webSockEndPointURL, onMessage) {
  const self     = this;
  self.onMessage = onMessage;
  
  self.connect = function(onConnect) {
    self.onConnect      = onConnect;
    self.isFirstReceive = true;
    self.socket         = new WebSocket(webSockEndPointURL);
    
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
"""
// Generated from Model/ClientUtils.js
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_ClientUtils_js =
"""
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

function formatDate(date) {
  const now = new Date();
  if (now.getYear()  != date.getYear()  ||
      now.getMonth() != date.getMonth() ||
      now.getDate()  != date.getDate())
    return date.toString();
  
  const m = date.getMinutes();
  return `${date.getHours()}:${m < 10 ? "0" + m : m}`
}

function htmlEscape(str) {
  const div = document.createElement("div");
  div.innerText = str;
  return div.innerHTML;
}
"""
// Generated from ViewControllers/MainVC.js
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_MainVC_js =
"""
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

const MainVC = function(nick, webSockEndPointURL) {
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
    webSockEndPointURL || "ws://localhost:1337/websocket",
    self.onMessage
  );
  
  self.connect = function() {
    self.notice("Connecting to IRC bridge ...");
    self.connection.connect(function() {
      self.connection.call("JOIN", "#NIO");
      self.connection.call("JOIN", "#SwiftDE");
    });
  };

  self.viewDidAppear = function() {
    const self = this;
    self.messages.viewDidAppear();
    
    window.setTimeout(function() {
      self.sendMessageToTarget("Eliza", "Moin")
    }, 3000);

    self.connect();
  };
}
"""
// Generated from ViewControllers/MessagesVC.js
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_MessagesVC_js =
"""
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

const MessagesVC = function(onLine) {
  const self = this;

  self.onLine = onLine;

  self.loadView = function(parent) {
    self.view            = parent.querySelector("main");
    self.form            = self.view.querySelector("footer form");
    self.messageListView = self.view.querySelector("section");
  };

  self.viewDidAppear = function() {
    const self = this;
    self.form.querySelector("input").focus();
    self.form.addEventListener("submit",
      function(e) {
        e.preventDefault()
        self.onFormSubmit();
      }
    );
  };

  self.setTitle = function(newTitle) {
    self.view.querySelector("#chatTitle").innerText = newTitle;
  };

  self.clear = function() {
    while (self.messageListView.firstChild) {
      self.messageListView.removeChild(self.messageListView.firstChild);
    }
  };

  /// Clear the whole history and set the new items.
  self.setChatItems = function(newItems) {
    self.clear();
    if (newItems === undefined) return;
    newItems.forEach(function(item) { self.addItem(item); });
  };

  self.onFormSubmit = function() {
    const field = self.form.querySelector("input");
    const line  = field.value;
    field.value = "";
    if (self.onLine !== undefined) { self.onLine(line) }
  };

  self.addItem = function(item) {
    const self = this;
    const escapedAuthor  = htmlEscape(item.sender);
    const escapedMessage = htmlEscape(item.message);
    const formattedDate  = formatDate(item.time);
    const timestamp      = item.time.toString();

    const newArticle = document.createElement("article")
    newArticle.innerHTML = `
      <svg data-jdenticon-value="${escapedAuthor}" class="avatar"></svg>

      <div class="content">
        <div class="info">
          <span class="author">${escapedAuthor}</span>
          <span class="date" value="${timestamp}">${formattedDate}</span>
        </div>
        <p>${escapedMessage}</p>
      </div>
    `;
    if (item.isSystem) { newArticle.classList.add('system'); }

    self.messageListView.appendChild(newArticle);

    jdenticon.update(newArticle.querySelector("svg"));
    if (newArticle.scrollIntoView) newArticle.scrollIntoView();
    item.isRead = true;
  };

};
"""
// Generated from ViewControllers/SidebarVC.js
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_SidebarVC_js =
"""
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

const SidebarVC = function(onTargetChange) {
  const self = this;

  self.onTargetChange = onTargetChange;
  self.activeTarget   = "server";
  self.idPrefix       = "";

  self.loadView = function(parent) {
    self.view       = parent.querySelector("aside");
    self.channeList = self.view.querySelector("#channelList");
    self.queryList  = self.view.querySelector("#queryList");
  
    document.getElementById("server").addEventListener("click", function(e) {
      e.preventDefault()
      self.selectTarget("Server");
    });
  }
  
  self.setNick = function(newNick) {
    const nickView = self.view.querySelector("aside .info .username");
    nickView.innerText = newNick;
  };
  
  self.selectTarget = function(newTarget) {
    if (self.activeTarget === newTarget) { return }
    
    self.view.querySelectorAll("section li").forEach(function(item) {
      item.classList.remove('selected');
    });
    const lc        = newTarget.toLowerCase();
    const selection = document.getElementById(self.idPrefix + lc);
    if (selection !== null) selection.classList.add('selected');
    
    self.activeTarget = lc;
    if (self.onTargetChange !== undefined)
      self.onTargetChange(newTarget);
  };
  
  self.updateUnreadCount = function(target, count) {
    const lc = target.toLowerCase();
    const targetView = document.getElementById(self.idPrefix + lc);
    if (targetView === null) return;
    const countView  = targetView.querySelector(".unreadcount");
    if (countView  === null) return;
    
    if (count > 0) countView.innerText = "(" + count + ")"
    else countView.innerText = "";
  };

  self.addTargetView = function(list, newTarget) {
    const elementID = self.idPrefix + newTarget.toLowerCase();
    if (document.getElementById(elementID))
      return;
    
    const childView = document.createElement("li")
    childView.innerHTML = `
      <span class="name"></span>
      <span class="unreadcount"></span>
    `;
    childView.setAttribute("id", elementID);
    
    const nameView = childView.querySelector(".name");
    nameView.innerText = newTarget;
    
    list.appendChild(childView);
    
    childView.addEventListener("click", function(e) {
      e.preventDefault()
      self.selectTarget(newTarget);
    });
  };
  
  self.removeTargetView = function(target) {
    const lc         = target.toLowerCase();
    const targetView = document.getElementById(self.idPrefix + lc);
    if (targetView === null) return;
    targetView.parentNode.removeChild(targetView);
    if (self.activeTarget === lc)
      self.selectTarget("server");
  };
  self.removeChannelView = self.removeTargetView;
  
  self.addChannelView = function(channel, select) {
    self.addTargetView(self.channeList, channel);
    self.view.querySelector("section.channels.list")
             .classList.remove("hidden");
    if (select) self.selectTarget(channel);
  };
  
  self.addQueryView = function(user, select) {
    self.addTargetView(self.queryList, user);
    self.view.querySelector("section.queries.list")
             .classList.remove("hidden");
    if (select) self.selectTarget(user);
  };
};
"""
// Generated from Styles/Client.css
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_Client_css =
"""
/*
  Thanks go to [@slashmo](https://github.com/slashmo) for the original
  flexbox layout and CSS setup!
*/

* {
  margin:        0;
  padding:       0;
  box-sizing:    border-box;
  font-family:   'Helvetica Neue', sans-serif;
}

.chat {
  height:  100vh;
  width:   100%;
  display: flex;
}

/* sidebar */

.chat aside {
  width:         240px;
  background:    #13202D;
  flex-shrink:   0;
  color:         white;
  padding:       1em 0;
}

.chat aside section.info {
  padding:       0 10px;
}
.chat aside section.info h1 {
  font-size:     1.2em;
  text-align:    center;
  color:         #EEE;
}
.chat aside section h2 {
  font-size:     0.9em;
  padding-left:  1em;
  color:         #999;
  text-align:    center;
}
.chat aside section.info .username {
  margin-top:    2px;
  font-size:     0.8em;
  text-align:    center;
}

.chat aside section.list {
  margin-top:    10px;
}

.chat aside section ul li {
  list-style:    none;
  font-size:     0.9em;
  padding:       6px 1.5em;
  color:         rgba(255, 255, 255, 0.6);
}
.chat aside section ul li.selected {
  background:    #52AC65;
  color:         white;
}
.chat aside section ul li:hover {
  background:    #666;
  color:         white;
}
.chat aside section ul li:hover.selected {
  background:    #428C45;
}

/* main */

.chat main {
  width:          100%;
  height:         100%;
  display:        flex;
  flex-direction: column;
}

.chat main header {
  padding:       0.7em 1em;
  border-bottom: 1px solid #DDD;
}
.chat main header h1 {
  font-size:     1.2em;
}

.chat main footer {
  width:         100%;
  padding:       10px;
  border-top:    1px solid #DDD;
}
.chat footer input {
  width:         100%;
  border:        2px solid #EEE;
  border-radius: 4px;
  padding:       10px;
  outline:       none;
  font-size:     14px;
}


/* body */

.chat main section {
  padding:       10px 0;
  flex-grow:     1;
  overflow-y:    scroll;
}
.chat main section article {
  padding:       10px 20px;
  display:       flex;
}
.chat main section article .avatar {
  width:         38px;
  height:        38px;
  background:    #EEE;
  border-radius: 4px;
  border:        1px solid #DDD;
  flex-shrink:   0;
}

.chat main section article.system {
  color: #AAA;
}

.chat main section article .content {
  margin-left:   10px;
}
.chat main section article .content .info {
  font-size:     0.8em;
}
.chat main section article .content .info .author {
  font-weight:   700;
}
.chat main section article .content p {
  font-size:     0.9em;
  margin-top:    4px;
}
.chat main section article .content p .mention {
  background:    #ECF5FB;
  color:         #3275B4;
  padding:       2px;
  border-radius: 4px;
}
.hidden {
  visibility:    hidden;
}
"""
// Generated from ClientInline.html
//   on Wed Apr 25 15:21:09 CEST 2018
//
let rsrc_ClientInline_html =
"""
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <title>{{title}}</title>
    
    <script src="https://cdn.jsdelivr.net/npm/jdenticon@2.1.0"></script>
    
    <style>{{style}}</style>
  </head>
  <body>
    <div class="chat">
      <aside>
        <section class="info">
          <h1>{{title}}</h1>
          <div class="username"></div>
        </section>
        
        <section class="server list">
          <ul id='serverList'>
            <li id="server" class="selected">Server</li>
          </ul>
        </section>

        <section class="channels list hidden">
          <h2>Channels</h2>
          <ul id='channelList'>
          </ul>
        </section>
        
        <section class="queries list hidden">
          <h2>Direct Messages</h2>
          <ul id='queryList'>
          </ul>
        </section>
      </aside>

      <main>
        <header>
          <h1 id='chatTitle'>Server</h1>
        </header>

        <section>
        </section>

        <footer>
          <form>
            <input type="text" placeholder="Enter IRC commands (or /help)" />
          </form>
        </footer>
      </main>
    </div>
    <script>
      (function() {
        {{script.model.ClientUtils}}
        {{script.model.ClientConnection}}
        {{script.model.ChatItem}}
        {{script.vc.SidebarVC}}
        {{script.vc.MessagesVC}}
        {{script.vc.MainVC}}
        
        var controller = new MainVC("{{defaultNick}}", "{{endpoint}}");
        controller.loadView();
        controller.viewDidAppear();
      }())
    </script>
  </body>
</html>
"""
