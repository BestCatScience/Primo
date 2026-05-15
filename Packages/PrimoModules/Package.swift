// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrimoModules",
    platforms: [
        .iOS("26.0"),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PrimoCoreTypes", targets: ["PrimoCoreTypes"]),
        .library(name: "PrimoSystemClients", targets: ["PrimoSystemClients"]),
        .library(name: "PrimoLocalization", targets: ["PrimoLocalization"]),
        .library(name: "PrimoDocumentDomain", targets: ["PrimoDocumentDomain"]),
        .library(name: "PrimoCanvasInputDomain", targets: ["PrimoCanvasInputDomain"]),
        .library(name: "PrimoCanvasPresentationDomain", targets: ["PrimoCanvasPresentationDomain"]),
        .library(name: "PrimoDocumentGPUContracts", targets: ["PrimoDocumentGPUContracts"]),
        .library(name: "PrimoDocumentApplication", targets: ["PrimoDocumentApplication"]),
        .library(name: "PrimoDocumentStrokeApplication", targets: ["PrimoDocumentStrokeApplication"]),
        .library(name: "PrimoDocumentRuntimeContracts", targets: ["PrimoDocumentRuntime"]),
        .library(name: "PrimoDocumentRuntime", targets: ["PrimoDocumentRuntime"]),
        .library(name: "PrimoDocumentRuntimeLive", targets: ["PrimoDocumentRuntimeLive"]),
        .library(name: "PrimoCanvasPresentationRuntime", targets: ["PrimoCanvasPresentationRuntime"]),
        .library(name: "PrimoBrushDomain", targets: ["PrimoBrushDomain"]),
        .library(name: "PrimoAIImageDomain", targets: ["PrimoAIImageDomain"]),
        .library(name: "PrimoAIImageApplication", targets: ["PrimoAIImageApplication"]),
        .library(name: "PrimoAIImageRuntime", targets: ["PrimoAIImageRuntime"]),
        .library(name: "PrimoBrushRuntimeContracts", targets: ["PrimoBrushRuntimeContracts"]),
        .library(name: "PrimoBrushRuntime", targets: ["PrimoBrushRuntime"]),
        .library(name: "PrimoDocumentMutationContracts", targets: ["PrimoDocumentMutationContracts"]),
        .library(name: "PrimoDocumentPersistenceContracts", targets: ["PrimoDocumentPersistenceContracts"]),
        .library(name: "PrimoDocumentPresentationContracts", targets: ["PrimoDocumentPresentationContracts"]),
        .library(name: "PrimoDocumentRenderingContracts", targets: ["PrimoDocumentRenderingContracts"]),
        .library(name: "PrimoDocumentContracts", targets: ["PrimoDocumentContracts"]),
        .library(name: "PrimoWorkspaceDomain", targets: ["PrimoWorkspaceDomain"]),
        .library(name: "PrimoWorkspaceApplication", targets: ["PrimoWorkspaceApplication"]),
        .library(name: "PrimoWorkspaceRuntime", targets: ["PrimoWorkspaceRuntime"]),
        .library(name: "PrimoBrushFileFormats", targets: ["PrimoBrushFileFormats"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "601.0.1"),
    ],
    targets: [
        .target(
            name: "PrimoCoreTypes"
        ),
        .target(
            name: "PrimoSystemClients",
            dependencies: ["PrimoCoreTypes"]
        ),
        .target(
            name: "PrimoLocalization"
        ),
        .target(
            name: "PrimoDocumentDomain",
            dependencies: ["PrimoCoreTypes"]
        ),
        .target(
            name: "PrimoCanvasInputDomain",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoDocumentDomain",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoCanvasPresentationDomain",
            dependencies: [
                "PrimoCanvasInputDomain",
                "PrimoDocumentDomain",
                "PrimoDocumentGPUContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentGPUContracts",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushRuntimeContracts",
                "PrimoBrushFileFormats",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentApplication",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushRuntimeContracts",
                "PrimoCanvasPresentationDomain",
                "PrimoDocumentDomain",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentStrokeApplication",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentApplication",
                "PrimoDocumentDomain",
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentInfrastructure",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoDocumentApplication",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentMetalRuntimeInfrastructure",
            dependencies: [
                "PrimoBrushRuntimeContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
            ],
            resources: [
                .process("Shaders"),
            ]
        ),
        .target(
            name: "PrimoDocumentMetalSurfaceInfrastructure",
            dependencies: [
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMetalRuntimeInfrastructure",
            ]
        ),
        .target(
            name: "PrimoDocumentMetalStrokeInfrastructure",
            dependencies: [
                "PrimoBrushRuntimeContracts",
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMetalSurfaceInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentMetalLayerInfrastructure",
            dependencies: [
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMetalRuntimeInfrastructure",
            ]
        ),
        .target(
            name: "PrimoCanvasPresentationInfrastructure",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoCanvasInputDomain",
                "PrimoCanvasPresentationDomain",
                "PrimoDocumentDomain",
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentRenderingInfrastructure",
            dependencies: [
                "PrimoBrushRuntimeContracts",
                "PrimoCanvasPresentationDomain",
                "PrimoDocumentApplication",
                "PrimoDocumentDomain",
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
            ],
            path: "Sources/PrimoDocumentRenderingInfrastructure"
        ),
        .target(
            name: "PrimoDocumentPersistenceInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoSystemClients",
                "PrimoBrushRuntimeContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
            ],
            path: "Sources/PrimoDocumentPersistenceInfrastructure"
        ),
        .target(
            name: "PrimoDocumentStrokeInfrastructure",
            dependencies: [
                "PrimoBrushRuntimeContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentPresentationContracts",
            ],
            path: "Sources/PrimoDocumentStrokeInfrastructure"
        ),
        .target(
            name: "PrimoDocumentTimelapseInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoSystemClients",
                "PrimoDocumentDomain",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPersistenceInfrastructure",
            ],
            path: "Sources/PrimoDocumentTimelapseInfrastructure"
        ),
        .target(
            name: "PrimoDocumentEngineInfrastructure",
            dependencies: [
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoSystemClients",
                "PrimoDocumentDomain",
                "PrimoDocumentApplication",
                "PrimoDocumentInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentMetalStrokeInfrastructure",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
                "PrimoDocumentRenderingInfrastructure",
                "PrimoDocumentPersistenceInfrastructure",
                "PrimoDocumentStrokeApplication",
                "PrimoDocumentStrokeInfrastructure",
                "PrimoDocumentTimelapseInfrastructure",
            ],
            path: "Sources/PrimoDocumentEngineInfrastructure"
        ),
        .target(
            name: "PrimoDocumentRuntime",
            dependencies: [
                "PrimoBrushRuntimeContracts",
                "PrimoCanvasPresentationDomain",
                "PrimoCoreTypes",
                "PrimoDocumentApplication",
                "PrimoDocumentDomain",
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
                "PrimoDocumentStrokeApplication",
            ],
            path: "Sources/PrimoDocumentRuntime"
        ),
        .target(
            name: "PrimoDocumentRuntimeLive",
            dependencies: [
                "PrimoSystemClients",
                "PrimoDocumentRuntime",
                "PrimoDocumentEngineInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentMetalStrokeInfrastructure",
                "PrimoDocumentRenderingInfrastructure",
                "PrimoDocumentStrokeInfrastructure",
            ],
            path: "Sources/PrimoDocumentRuntimeLive"
        ),
        .target(
            name: "PrimoCanvasPresentationRuntime",
            dependencies: [
                "PrimoCanvasPresentationDomain",
                "PrimoCanvasPresentationInfrastructure",
                "PrimoDocumentDomain",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentPresentationContracts",
            ],
            path: "Sources/PrimoCanvasPresentationRuntime"
        ),
        .target(
            name: "PrimoBrushDomain"
        ),
        .target(
            name: "PrimoAIImageDomain",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoAIImageApplication",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentApplication",
                "PrimoDocumentPresentationContracts",
                "PrimoAIImageDomain",
            ]
        ),
        .target(
            name: "PrimoAIImageInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoAIImageApplication",
                "PrimoAIImageDomain",
                "PrimoDocumentApplication",
            ]
        ),
        .target(
            name: "PrimoAIImageRuntime",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoAIImageApplication",
                "PrimoAIImageInfrastructure",
            ],
            path: "Sources/PrimoAIImageRuntime"
        ),
        .target(
            name: "PrimoBrushRuntimeContracts",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoCoreTypes",
            ]
        ),
        .target(
            name: "PrimoBrushRuntime",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushInfrastructure",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
            ],
            path: "Sources/PrimoBrushRuntime"
        ),
        .target(
            name: "PrimoDocumentPresentationContracts",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
            ]
        ),
        .target(
            name: "PrimoDocumentMutationContracts",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentRenderingContracts",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentPersistenceContracts",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentDomain",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .target(
            name: "PrimoDocumentContracts",
            dependencies: [
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
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
                "PrimoDocumentPresentationContracts",
                "PrimoCoreTypes",
            ]
        ),
        .target(
            name: "PrimoWorkspaceApplication",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
                "PrimoWorkspaceDomain",
            ]
        ),
        .target(
            name: "PrimoWorkspaceInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentPersistenceInfrastructure",
                "PrimoWorkspaceApplication",
                "PrimoWorkspaceDomain",
            ]
        ),
        .target(
            name: "PrimoWorkspaceRuntime",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoDocumentApplication",
                "PrimoDocumentContracts",
                "PrimoDocumentRuntime",
                "PrimoDocumentRuntimeLive",
                "PrimoWorkspaceApplication",
                "PrimoWorkspaceInfrastructure",
            ],
            path: "Sources/PrimoWorkspaceRuntime"
        ),
        .target(
            name: "PrimoBrushFileFormats",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoSystemClients",
                "PrimoDocumentDomain",
            ]
        ),
        .target(
            name: "PrimoBrushInfrastructure",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoBrushDomain",
                "PrimoBrushRuntimeContracts",
                "PrimoDocumentDomain",
                "PrimoBrushFileFormats",
            ]
        ),
        .testTarget(
            name: "PrimoWorkspaceDomainTests",
            dependencies: ["PrimoWorkspaceDomain"]
        ),
        .testTarget(
            name: "PrimoCanvasInputDomainTests",
            dependencies: ["PrimoCanvasInputDomain"]
        ),
        .testTarget(
            name: "PrimoCanvasPresentationInfrastructureTests",
            dependencies: [
                "PrimoCanvasPresentationInfrastructure",
                "PrimoDocumentGPUContracts",
            ]
        ),
        .testTarget(
            name: "PrimoDocumentStrokeApplicationTests",
            dependencies: [
                "PrimoDocumentStrokeApplication",
                "PrimoDocumentGPUContracts",
            ]
        ),
        .testTarget(
            name: "PrimoWorkspaceApplicationTests",
            dependencies: ["PrimoWorkspaceApplication", "PrimoWorkspaceInfrastructure"]
        ),
        .testTarget(
            name: "PrimoWorkspaceInfrastructureTests",
            dependencies: [
                "PrimoSystemClients",
                "PrimoWorkspaceApplication",
                "PrimoWorkspaceInfrastructure",
            ]
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
            dependencies: [
                "PrimoDocumentApplication",
                "PrimoDocumentDomain",
                "PrimoDocumentPresentationContracts",
            ]
        ),
        .testTarget(
            name: "PrimoDocumentEngineInfrastructureTests",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentEngineInfrastructure",
                "PrimoDocumentInfrastructure",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
                "PrimoDocumentRuntime",
                "PrimoDocumentRuntimeLive",
                "PrimoCanvasPresentationRuntime",
                "PrimoDocumentMetalRuntimeInfrastructure",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            exclude: [
                "__Snapshots__"
            ]
        ),
        .testTarget(
            name: "PrimoDocumentRenderingInfrastructureTests",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentMetalStrokeInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentRenderingInfrastructure",
                "PrimoDocumentRuntimeLive",
            ]
        ),
        .testTarget(
            name: "PrimoDocumentPersistenceInfrastructureTests",
            dependencies: [
                "PrimoCoreTypes",
                "PrimoSystemClients",
                "PrimoDocumentDomain",
                "PrimoDocumentPersistenceInfrastructure",
            ]
        ),
        .testTarget(
            name: "PrimoDocumentMetalSurfaceInfrastructureTests",
            dependencies: [
                "PrimoDocumentContracts",
                "PrimoDocumentGPUContracts",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentMetalSurfaceInfrastructure",
            ]
        ),
        .testTarget(
            name: "PrimoAIImageDomainTests",
            dependencies: ["PrimoAIImageDomain"]
        ),
        .testTarget(
            name: "PrimoAIImageApplicationTests",
            dependencies: [
                "PrimoAIImageApplication",
                "PrimoDocumentApplication",
                "PrimoDocumentContracts",
            ]
        ),
        .testTarget(
            name: "PrimoAIImageInfrastructureTests",
            dependencies: [
                "PrimoAIImageApplication",
                "PrimoAIImageInfrastructure",
                "PrimoDocumentApplication",
                "PrimoDocumentContracts",
            ]
        ),
        .testTarget(
            name: "PrimoBrushFileFormatsTests",
            dependencies: ["PrimoBrushFileFormats"]
        ),
    ]
)
