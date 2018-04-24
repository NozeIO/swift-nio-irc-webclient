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
