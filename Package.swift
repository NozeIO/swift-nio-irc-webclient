// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swift-nio-irc-webclient",
    products: [
        .library(name: "IRCWebClient", targets: [ "IRCWebClient" ]),
    ],
    dependencies: [
        .package(url: "https://github.com/NozeIO/swift-nio-irc",
                 from: "0.5.0")
    ],
    targets: [
        .target(name: "IRCWebClient", dependencies: [ "IRC" ])
    ]
)
