// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrimoModules",
    products: [
        .library(name: "PrimoCoreTypes", targets: ["PrimoCoreTypes"]),
        .library(name: "PrimoDocumentDomain", targets: ["PrimoDocumentDomain"]),
        .library(name: "PrimoDocumentContracts", targets: ["PrimoDocumentContracts"]),
        .library(name: "PrimoWorkspaceDomain", targets: ["PrimoWorkspaceDomain"]),
    ],
    targets: [
        .target(
            name: "PrimoCoreTypes"
        ),
        .target(
            name: "PrimoDocumentDomain",
            dependencies: ["PrimoCoreTypes"]
        ),
        .target(
            name: "PrimoDocumentContracts",
            dependencies: ["PrimoDocumentDomain"]
        ),
        .target(
            name: "PrimoWorkspaceDomain",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoCoreTypes",
            ]
        ),
        .testTarget(
            name: "PrimoWorkspaceDomainTests",
            dependencies: ["PrimoWorkspaceDomain"]
        ),
    ]
)
