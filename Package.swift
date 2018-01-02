// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "UniRedis",
	products: [
		.library(name: "UniRedis", targets: ["UniRedis"])
	],
	dependencies: [
		.package(url: "git@gitlab.kancelar.seznam.cz:pvs/swift-unisocket", from: "0.10.0")
	],
	targets: [
		.target(name: "UniRedis", dependencies: ["UniSocket"])
	]
)
