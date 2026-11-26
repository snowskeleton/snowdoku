// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Snowdoku",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
        .executable(name: "sudokugen", targets: ["sudokugen"]),
    ],
    targets: [
        .target(name: "SudokuCore"),
        .executableTarget(name: "sudokugen", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
    ]
)
