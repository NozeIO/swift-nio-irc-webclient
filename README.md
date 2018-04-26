# SwiftNIO IRC Web Client

![Swift4](https://img.shields.io/badge/swift-4-blue.svg)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![tuxOS](https://img.shields.io/badge/os-tuxOS-green.svg?style=flat)
![Travis](https://travis-ci.org/NozeIO/swift-nio-irc-webclient.svg?branch=master)

This is a very simple WebSocket based IRC WebClient/Server.

It contains a small chat-webapp as the frontend (a single-page webapp written
in plain JavaScript, not frameworks),
it contains a WebSocket/IRC bridge using the 
[SwiftNIO IRC](https://github.com/NozeIO/swift-nio-irc)
[client module](https://github.com/NozeIO/swift-nio-irc/Sources/IRC/),
and a small HTTP server which delivers the webapp and serves as a websocket
endpoint.

This WebClient is a regular Swift package and can be imported in other Swift
servers!

## What it looks like

On the surface it is a very simple chat webapp, with basic support for
channels and direct messages:

<img src="http://zeezide.de/img/irc-eliza.png" width="640" />

**Sometimes** a live demo installation is running on
[http://irc.noze.io/](http://irc.noze.io/).
We probably have to shut it down once abuse starts to take place :-)
If it doesn't run and you want to play with it, just install it locally,
it is a matter of minutes using
MiniIRCd.

## Overview

### Swift NIO Parts

This module contains the middlepart, the webserver. It serves two purposes:

1. Deliver the client side (JavaScript) webapp to the browser
   (single page, HTML + CSS + JS).
2. Server as an HTTP endpoint for the WebSocket connection.
   If the JS webapp creates a WebSocket connection, it'll contact the
   HTTP server, which will then upgrade the HTTP connection to the
   WebSocket protocol.

```
                            ┌───────────────────────┐
               HTML         │  ┌─────────────────┐  │
        ┌───────JS──────────┼──│ NIO HTTP Server │  │
        │                   │  └─────────────────┘  │
        │                   │           │           │
        ▼                   │       Upgrades        │
┌──────────────┐            │      Connection       │
│              │            │           │           │
│  WebBrowser  │            │           ▼           │       ┌──────────────┐
│              │  WebSocket │  ┌─────────────────┐  │       │              │
│  JavaScript  │◀────JSON───┼─▶│  NIO WebSocket  │◀─┼─IRC──▶│  IRC Server  │
│    WebApp    │            │  └─────────────────┘  │       │              │
│              │            │       WebServer       │       └──────────────┘
└──────────────┘            └───────────────────────┘
```

### JavaScript Client

The JavaScript web app is *embedded* into the compiled Swift module
(using a Makefile all the resources are bundled together into a 
 [single Swift source file](Sources/IRCWebClient/WebApp/ClientResources.swift)).
Yet it also works as a standalone web application (you can drag the
[Client.html](Sources/IRCWebClient/WebApp/Client.html)
into your browser.

The client app is located in
[Sources/IRCWebClient/WebApp](Sources/IRCWebClient/WebApp/README.md).


## Importing the module using Swift Package Manager

An example `Package.swift `importing the necessary modules:

```swift
// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "MyOwnIRCServer",
    dependencies: [
        .package(url: "https://github.com/NozeIO/swift-nio-irc-webclient.git",
                 from: "0.5.0")
    ],
    targets: [
        .target(name: "MyIRCServer",
                dependencies: [ "IRCServer", "IRCWebClient" ])
    ]
)
```

## Using the Server

```swift
let webServer = IRCWebClientServer()
webServer.listen()
```

Check the
[Configuration](Sources/IRCWebClient/IRCWebClientServer.swift)
object for the supported configuration options.

One can configure three connection parameters:
1. host/port - this is the address the HTTP server is running on
2. ircHost/port - this is the address of the IRC server
3. externalHost/port - the address the browser is using to connect to the
   HTTP server. Often but not necessarily the same like 1.

### Who

Brought to you by
[ZeeZide](http://zeezide.de).
We like
[feedback](https://twitter.com/ar_institute),
GitHub stars,
cool [contract work](http://zeezide.com/en/services/services.html),
presumably any form of praise you can think of.
