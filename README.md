# SwiftNIO IRC Web Client

This is a very simple WebSocket based IRC WebClient/Server.

It contains a small chat-webapp as the frontend (a single-page webapp written
in plain JavaScript, not frameworks),
it contains a WebSocket/IRC bridge using the swift-nio-irc
[IRC client module](https://github.com/NozeIO/swift-nio-irc/Sources/IRC/),
and a small HTTP server which delivers the webapp and serves as a websocket
endpoint.

This WebClient is a regular Swift package and can be imported in other Swift
servers!

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

Check the [Configuration](Sources/IRCWebClient/IRCWebClientServer) object 
for the supported configuration options.

### Who

Brought to you by
[ZeeZide](http://zeezide.de).
We like
[feedback](https://twitter.com/ar_institute),
GitHub stars,
cool [contract work](http://zeezide.com/en/services/services.html),
presumably any form of praise you can think of.
