// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swift-nio-irc-webclient",
    products: [
        .library(name: "IRCWebClient", targets: [ "IRCWebClient" ]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", 
                 from: "1.8.0"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc.git",
                 from: "0.5.1")
    ],
    targets: [
        .target(name: "IRCWebClient", 
                dependencies: [ "NIOHTTP1", "NIOWebSocket", 
                                "NIOFoundationCompat", "IRC" ]),
        .target(name: "ircwebclientd", dependencies: [ "IRCWebClient" ])
    ]
)
