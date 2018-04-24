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
