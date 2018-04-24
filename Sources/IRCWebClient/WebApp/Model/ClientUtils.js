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
