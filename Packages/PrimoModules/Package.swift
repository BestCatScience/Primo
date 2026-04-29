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
        .library(name: "PrimoCanvasInputDomain", targets: ["PrimoCanvasInputDomain"]),
        .library(name: "PrimoCanvasPresentationDomain", targets: ["PrimoCanvasPresentationDomain"]),
        .library(name: "PrimoDocumentGPUContracts", targets: ["PrimoDocumentGPUContracts"]),
        .library(name: "PrimoDocumentApplication", targets: ["PrimoDocumentApplication"]),
        .library(name: "PrimoDocumentStrokeApplication", targets: ["PrimoDocumentStrokeApplication"]),
        .library(name: "PrimoDocumentInfrastructure", targets: ["PrimoDocumentInfrastructure"]),
        .library(name: "PrimoDocumentMetalRuntimeInfrastructure", targets: ["PrimoDocumentMetalRuntimeInfrastructure"]),
        .library(name: "PrimoDocumentMetalSurfaceInfrastructure", targets: ["PrimoDocumentMetalSurfaceInfrastructure"]),
        .library(name: "PrimoDocumentMetalStrokeInfrastructure", targets: ["PrimoDocumentMetalStrokeInfrastructure"]),
        .library(name: "PrimoDocumentMetalLayerInfrastructure", targets: ["PrimoDocumentMetalLayerInfrastructure"]),
        .library(name: "PrimoCanvasPresentationInfrastructure", targets: ["PrimoCanvasPresentationInfrastructure"]),
        .library(name: "PrimoDocumentEngineInfrastructure", targets: ["PrimoDocumentEngineInfrastructure"]),
        .library(name: "PrimoDocumentRenderingInfrastructure", targets: ["PrimoDocumentRenderingInfrastructure"]),
        .library(name: "PrimoDocumentPersistenceInfrastructure", targets: ["PrimoDocumentPersistenceInfrastructure"]),
        .library(name: "PrimoDocumentStrokeInfrastructure", targets: ["PrimoDocumentStrokeInfrastructure"]),
        .library(name: "PrimoDocumentTimelapseInfrastructure", targets: ["PrimoDocumentTimelapseInfrastructure"]),
        .library(name: "PrimoBrushDomain", targets: ["PrimoBrushDomain"]),
        .library(name: "PrimoAIImageDomain", targets: ["PrimoAIImageDomain"]),
        .library(name: "PrimoAIImageApplication", targets: ["PrimoAIImageApplication"]),
        .library(name: "PrimoAIImageInfrastructure", targets: ["PrimoAIImageInfrastructure"]),
        .library(name: "PrimoBrushRuntimeContracts", targets: ["PrimoBrushRuntimeContracts"]),
        .library(name: "PrimoDocumentMutationContracts", targets: ["PrimoDocumentMutationContracts"]),
        .library(name: "PrimoDocumentPersistenceContracts", targets: ["PrimoDocumentPersistenceContracts"]),
        .library(name: "PrimoDocumentPresentationContracts", targets: ["PrimoDocumentPresentationContracts"]),
        .library(name: "PrimoDocumentRenderingContracts", targets: ["PrimoDocumentRenderingContracts"]),
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
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoCoreTypes",
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
            name: "PrimoBrushRuntimeContracts",
            dependencies: [
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoCoreTypes",
            ]
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
                "PrimoBrushDomain",
                "PrimoBrushFileFormats",
                "PrimoBrushRuntimeContracts",
                "PrimoDocumentContracts",
                "PrimoDocumentDomain",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentPersistenceContracts",
                "PrimoDocumentPresentationContracts",
                "PrimoDocumentRenderingContracts",
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
            name: "PrimoBrushFileFormats",
            dependencies: ["PrimoCoreTypes"]
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
                "PrimoDocumentMetalStrokeInfrastructure",
                "PrimoDocumentMetalRuntimeInfrastructure",
                "PrimoDocumentRenderingInfrastructure",
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
