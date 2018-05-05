// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swift-nio-irc-webclient",
    products: [
        .library(name: "IRCWebClient", targets: [ "IRCWebClient" ]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", 
                 .branch("master")),
        .package(url: "https://github.com/NozeIO/swift-nio-irc.git",
                 .branch("nio/master"))
    ],
    targets: [
        .target(name: "IRCWebClient", 
                dependencies: [ "NIOHTTP1", "NIOWebSocket", 
                                "NIOFoundationCompat", "IRC" ]),
        .target(name: "ircwebclientd", dependencies: [ "IRCWebClient" ])
    ]
)
