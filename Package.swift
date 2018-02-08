// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "UniRedis",
	products: [
		.library(name: "UniRedis", targets: ["UniRedis"])
	],
	dependencies: [
		.package(url: "git@gitlab.kancelar.seznam.cz:pvs/swift-unisocket", from: "0.12.0"),
		.package(url: "git@gitlab.kancelar.seznam.cz:pvs/swift-resolver", from: "0.1.0")
	],
	targets: [
		.target(name: "UniRedis", dependencies: ["UniSocket", "Resolver"])
	]
)
