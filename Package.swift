import PackageDescription

let package = Package(
	name: "UniRedis",
	dependencies: [
		.Package(url: "git@gitlab.kancelar.seznam.cz:pvs/swift-regex", majorVersion: 0),
		.Package(url: "git@gitlab.kancelar.seznam.cz:pvs/swift-unisocket", majorVersion: 0, minor: 9),
	]
)
