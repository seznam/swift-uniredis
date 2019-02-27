// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "UniRedis",
	products: [
		.library(name: "UniRedis", targets: ["UniRedis"])
	],
	dependencies: [
		.package(url: "https://github.com/seznam/swift-unisocket", from: "0.13.2"),
		.package(url: "https://github.com/seznam/swift-resolver", from: "0.2.0")
	],
	targets: [
		.target(name: "UniRedis", dependencies: ["UniSocket", "Resolver"]),
		.testTarget(name: "UniRedisTests", dependencies: ["UniRedis", "UniSocket"])
	]
)
