// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrimoModules",
    products: [
        .library(name: "PrimoCoreTypes", targets: ["PrimoCoreTypes"]),
        .library(name: "PrimoLocalization", targets: ["PrimoLocalization"]),
        .library(name: "PrimoDocumentDomain", targets: ["PrimoDocumentDomain"]),
        .library(name: "PrimoBrushDomain", targets: ["PrimoBrushDomain"]),
        .library(name: "PrimoDocumentContracts", targets: ["PrimoDocumentContracts"]),
        .library(name: "PrimoWorkspaceDomain", targets: ["PrimoWorkspaceDomain"]),
        .library(name: "PrimoWorkspaceInfrastructure", targets: ["PrimoWorkspaceInfrastructure"]),
        .library(name: "PrimoBrushFileFormats", targets: ["PrimoBrushFileFormats"]),
        .library(name: "PrimoBrushInfrastructure", targets: ["PrimoBrushInfrastructure"]),
    ],
    targets: [
        .target(
            name: "PrimoCoreTypes"
        ),
        .target(
            name: "PrimoLocalization"
        ),
        .target(
            name: "PrimoDocumentDomain",
            dependencies: ["PrimoCoreTypes"]
        ),
        .target(
            name: "PrimoBrushDomain"
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
        .target(
            name: "PrimoWorkspaceInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
            ]
        ),
        .target(
            name: "PrimoBrushFileFormats",
            dependencies: ["PrimoCoreTypes"]
        ),
        .target(
            name: "PrimoBrushInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoBrushFileFormats",
            ]
        ),
        .testTarget(
            name: "PrimoWorkspaceDomainTests",
            dependencies: ["PrimoWorkspaceDomain"]
        ),
        .testTarget(
            name: "PrimoWorkspaceInfrastructureTests",
            dependencies: ["PrimoWorkspaceInfrastructure"]
        ),
        .testTarget(
            name: "PrimoBrushDomainTests",
            dependencies: ["PrimoBrushDomain"]
        ),
        .testTarget(
            name: "PrimoBrushFileFormatsTests",
            dependencies: ["PrimoBrushFileFormats"]
        ),
    ]
)
