// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
        .executable(name: "sudokugen", targets: ["sudokugen"]),
    ],
    targets: [
        // The engine is hot code (generation/rating); keep it optimized even in Debug app builds.
        .target(name: "SudokuCore", swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]),
        .executableTarget(name: "sudokugen", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
    ]
)
