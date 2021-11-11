// swift-tools-version:5.1
import PackageDescription


let package = Package(
	name: "swift-email",
	products: [
		.library(name: "Email", targets: ["Email"]),
	],
	dependencies: [
	],
	targets: [
		.target(name: "Email", dependencies: []),
		.testTarget(name: "EmailTests", dependencies: ["Email"])
	]
)
