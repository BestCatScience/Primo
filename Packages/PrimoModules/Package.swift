// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrimoModules",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PrimoCoreTypes", targets: ["PrimoCoreTypes"]),
        .library(name: "PrimoLocalization", targets: ["PrimoLocalization"]),
        .library(name: "PrimoDocumentDomain", targets: ["PrimoDocumentDomain"]),
        .library(name: "PrimoDocumentApplication", targets: ["PrimoDocumentApplication"]),
        .library(name: "PrimoDocumentInfrastructure", targets: ["PrimoDocumentInfrastructure"]),
        .library(name: "PrimoDocumentMetalRuntimeInfrastructure", targets: ["PrimoDocumentMetalRuntimeInfrastructure"]),
        .library(name: "PrimoDocumentRuntimeInfrastructure", targets: ["PrimoDocumentRuntimeInfrastructure"]),
        .library(name: "PrimoBrushDomain", targets: ["PrimoBrushDomain"]),
        .library(name: "PrimoNanoBananaDomain", targets: ["PrimoNanoBananaDomain"]),
        .library(name: "PrimoNanoBananaApplication", targets: ["PrimoNanoBananaApplication"]),
        .library(name: "PrimoNanoBananaInfrastructure", targets: ["PrimoNanoBananaInfrastructure"]),
        .library(name: "PrimoDocumentContracts", targets: ["PrimoDocumentContracts"]),
        .library(name: "PrimoWorkspaceDomain", targets: ["PrimoWorkspaceDomain"]),
        .library(name: "PrimoWorkspaceApplication", targets: ["PrimoWorkspaceApplication"]),
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
            name: "PrimoDocumentApplication",
            dependencies: ["PrimoDocumentDomain", "PrimoDocumentContracts"]
        ),
        .target(
            name: "PrimoDocumentInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentApplication",
            ],
            exclude: ["LegacyRuntime"]
        ),
        .target(
            name: "PrimoDocumentMetalRuntimeInfrastructure",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
            ]
        ),
        .target(
            name: "PrimoDocumentRuntimeInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentApplication",
                "PrimoDocumentInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
            ],
            path: "Sources/PrimoDocumentInfrastructure/LegacyRuntime"
        ),
        .target(
            name: "PrimoBrushDomain"
        ),
        .target(
            name: "PrimoNanoBananaDomain"
        ),
        .target(
            name: "PrimoNanoBananaApplication",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentApplication",
                "PrimoNanoBananaDomain",
            ]
        ),
        .target(
            name: "PrimoNanoBananaInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoNanoBananaApplication",
                "PrimoNanoBananaDomain",
            ]
        ),
        .target(
            name: "PrimoDocumentContracts",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
            ]
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
            name: "PrimoWorkspaceApplication",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoWorkspaceDomain",
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
            name: "PrimoWorkspaceApplicationTests",
            dependencies: ["PrimoWorkspaceApplication"]
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
            name: "PrimoDocumentApplicationTests",
            dependencies: ["PrimoDocumentApplication"]
        ),
        .testTarget(
            name: "PrimoDocumentRuntimeInfrastructureTests",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentRuntimeInfrastructure",
            ]
        ),
        .testTarget(
            name: "PrimoNanoBananaDomainTests",
            dependencies: ["PrimoNanoBananaDomain"]
        ),
        .testTarget(
            name: "PrimoNanoBananaApplicationTests",
            dependencies: ["PrimoNanoBananaApplication"]
        ),
        .testTarget(
            name: "PrimoNanoBananaInfrastructureTests",
            dependencies: ["PrimoNanoBananaInfrastructure"]
        ),
        .testTarget(
            name: "PrimoBrushFileFormatsTests",
            dependencies: ["PrimoBrushFileFormats"]
        ),
    ],
    cxxLanguageStandard: .gnucxx20
)
