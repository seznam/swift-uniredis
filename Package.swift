// swift-tools-version:5.2

import PackageDescription

let package = Package(
	name: "UniRedis",
	products: [
		.library(name: "UniRedis", targets: ["UniRedis"])
	],
	dependencies: [
		.package(name: "UniSocket", url: "https://github.com/seznam/swift-unisocket", from: "0.14.0"),
		.package(name: "Resolver", url: "https://github.com/seznam/swift-resolver", from: "0.3.0")
	],
	targets: [
		.target(name: "UniRedis", dependencies: ["UniSocket", "Resolver"]),
		.testTarget(name: "UniRedisTests", dependencies: ["UniRedis", "UniSocket"])
	],
	swiftLanguageVersions: [.v5]
)
