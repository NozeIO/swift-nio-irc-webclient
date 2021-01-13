// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "swift-nio-irc-webclient",
    products: [
        .library(name: "IRCWebClient", targets: [ "IRCWebClient" ]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", 
                 from: "2.25.1"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc-client.git",
                 from: "0.8.0")
    ],
    targets: [
        .target(name: "IRCWebClient", 
                dependencies: [ "NIOHTTP1", "NIOWebSocket", 
                                "NIOFoundationCompat", "IRC" ]),
        .target(name: "ircwebclientd", dependencies: [ "IRCWebClient" ])
    ]
)
