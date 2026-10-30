// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickyToDo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "StickyToDo", path: "Sources/StickyToDo"),
        .testTarget(name: "StickyToDoTests", dependencies: ["StickyToDo"], path: "Tests/StickyToDoTests"),
    ]
)
