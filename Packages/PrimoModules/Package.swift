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
        .library(name: "PrimoDocumentEngineInfrastructure", targets: ["PrimoDocumentEngineInfrastructure"]),
        .library(name: "PrimoDocumentRenderingInfrastructure", targets: ["PrimoDocumentRenderingInfrastructure"]),
        .library(name: "PrimoDocumentPersistenceInfrastructure", targets: ["PrimoDocumentPersistenceInfrastructure"]),
        .library(name: "PrimoDocumentStrokeInfrastructure", targets: ["PrimoDocumentStrokeInfrastructure"]),
        .library(name: "PrimoDocumentTimelapseInfrastructure", targets: ["PrimoDocumentTimelapseInfrastructure"]),
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
            ]
        ),
        .target(
            name: "PrimoDocumentMetalRuntimeInfrastructure",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentStrokeInfrastructure",
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
            ]
        ),
        .target(
            name: "PrimoDocumentRenderingInfrastructure",
            dependencies: [
                "PrimoDocumentApplication",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentStrokeInfrastructure",
            ],
            path: "Sources/PrimoDocumentRenderingInfrastructure"
        ),
        .target(
            name: "PrimoDocumentPersistenceInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
            ],
            path: "Sources/PrimoDocumentPersistenceInfrastructure"
        ),
        .target(
            name: "PrimoDocumentStrokeInfrastructure",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
            ],
            path: "Sources/PrimoDocumentStrokeInfrastructure"
        ),
        .target(
            name: "PrimoDocumentTimelapseInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentPersistenceInfrastructure",
            ],
            path: "Sources/PrimoDocumentTimelapseInfrastructure"
        ),
        .target(
            name: "PrimoDocumentEngineInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentApplication",
                "PrimoDocumentInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentRenderingInfrastructure",
                "PrimoDocumentPersistenceInfrastructure",
                "PrimoDocumentStrokeInfrastructure",
                "PrimoDocumentTimelapseInfrastructure",
            ],
            path: "Sources/PrimoDocumentEngineInfrastructure"
        ),
        .target(
            name: "PrimoBrushDomain"
        ),
        .target(
            name: "PrimoNanoBananaDomain",
            dependencies: ["PrimoDocumentContracts"]
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
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoWorkspaceDomain",
            ]
        ),
        .target(
            name: "PrimoWorkspaceInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoWorkspaceApplication",
                "PrimoWorkspaceDomain",
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
                "PrimoBrushDomain",
                "PrimoDocumentContracts",
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
            dependencies: ["PrimoWorkspaceApplication", "PrimoWorkspaceInfrastructure"]
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
            name: "PrimoBrushInfrastructureTests",
            dependencies: [
                "PrimoBrushInfrastructure",
                "PrimoDocumentContracts",
            ]
        ),
        .testTarget(
            name: "PrimoDocumentApplicationTests",
            dependencies: ["PrimoDocumentApplication"]
        ),
        .testTarget(
            name: "PrimoDocumentEngineInfrastructureTests",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentEngineInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
            ]
        ),
        .testTarget(
            name: "PrimoDocumentRenderingInfrastructureTests",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentStrokeInfrastructure",
                "PrimoDocumentRenderingInfrastructure",
            ]
        ),
        .testTarget(
            name: "PrimoNanoBananaDomainTests",
            dependencies: ["PrimoNanoBananaDomain"]
        ),
        .testTarget(
            name: "PrimoNanoBananaApplicationTests",
            dependencies: ["PrimoNanoBananaApplication", "PrimoDocumentContracts"]
        ),
        .testTarget(
            name: "PrimoNanoBananaInfrastructureTests",
            dependencies: ["PrimoNanoBananaInfrastructure"]
        ),
        .testTarget(
            name: "PrimoBrushFileFormatsTests",
            dependencies: ["PrimoBrushFileFormats"]
        ),
    ]
)
