import Foundation
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentMetalStrokeInfrastructure
import Testing

struct DocumentStrokeProcessingServiceTests {
    @Test
    func committedStrokeRenderingUsesCommitExecutionMode() throws {
        let repoRoot = try Self.repoRoot()
        let serviceSource = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentMetalStrokeInfrastructure/DocumentStrokeProcessingService.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: serviceSource, encoding: .utf8)
        let committedSurface = try #require(
            body[function: "makeCommittedSurface", before: "makeCommittedPixels"]
        )
        let committedPixels = try #require(
            body[function: "makeCommittedPixels", before: "stageCommittedSnapshot"]
        )

        #expect(committedSurface.contains("mode: .commit"))
        #expect(!committedSurface.contains("mode: .interactive"))
        #expect(committedPixels.contains("mode: .commit"))
        #expect(!committedPixels.contains("mode: .interactive"))
    }

    @Test
    func interactiveSmudgePreviewUsesGpuOnlyResponsiveMutation() throws {
        let repoRoot = try Self.repoRoot()
        let serviceSource = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentMetalStrokeInfrastructure/DocumentStrokeProcessingService.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: serviceSource, encoding: .utf8)
        let preview = try #require(
            body[function: "makeInteractiveStrokePreview", before: "materializedIncrementalUpdateIfNeeded"]
        )

        #expect(preview.contains("shouldUseGpuOnlyResponsivePreview"))
        #expect(preview.contains("executeStrokeMutation"))
        #expect(preview.contains("isApproximatePreview"))
    }

    @Test
    func interactivePreviewDoesNotMaterializeGpuIncrementalUpdatesOnCpu() throws {
        let repoRoot = try Self.repoRoot()
        let serviceSource = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentMetalStrokeInfrastructure/DocumentStrokeProcessingService.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: serviceSource, encoding: .utf8)
        let preview = try #require(
            body[function: "makeInteractiveStrokePreview", before: "materializedIncrementalUpdateIfNeeded"]
        )

        #expect(!preview.contains("materializedIncrementalUpdateIfNeeded"))
        #expect(!preview.contains("materializedPixelData(for: bufferHandle)"))
    }

    @Test
    func responsiveOilPreviewBrushBypassesSmudgeCpuOrchestration() throws {
        let repoRoot = try Self.repoRoot()
        let gpuSupportSource = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentMetalStrokeInfrastructure/MetalStrokeGpuServices.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: gpuSupportSource, encoding: .utf8)
        let responsiveBrush = try #require(
            body[function: "responsivePreviewBrush", before: "strokePreviewDirtyRect"]
        )

        #expect(responsiveBrush.contains("preview.smudgeEngineEnabled = false"))
        #expect(responsiveBrush.contains("preview.wetness = 0"))
        #expect(responsiveBrush.contains("preview.colorMixStrength = 0"))
        #expect(responsiveBrush.contains("preview.smudgeRadius = 0"))
        #expect(responsiveBrush.contains("preview.smudgeLength = 0"))
    }

    @Test
    func stageCommittedSnapshotUsesProvidedCompositePixels() {
        let baseSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 2,
            height: 2,
            revision: 3,
            compositePixelData: Data(repeating: 0x00, count: 16),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1.0,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: Data(repeating: 0x11, count: 16)
                )
            ]
        )
        let committedPixels = Data(repeating: 0x22, count: 16)
        let stagedComposite = Data(repeating: 0x33, count: 16)
        let service = DocumentStrokeProcessingService()

        let staged = service.stageCommittedSnapshot(
            baseSnapshot: baseSnapshot,
            committedPixels: committedPixels,
            lastCommittedRenderRevision: 7,
            activeLayerIndex: 0,
            stagedCompositePixelData: stagedComposite
        )

        #expect(staged?.revision == 8)
        #expect(staged?.compositePixelData == stagedComposite)
        #expect(staged?.layers.first?.pixelData == committedPixels)
    }

    private static func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "PrimoModules" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                throw CocoaError(.fileReadNoSuchFile)
            }
            url = parent
        }
        return url.deletingLastPathComponent().deletingLastPathComponent()
    }
}

private extension String {
    subscript(function name: String, before nextName: String) -> Substring? {
        guard
            let start = range(of: "func \(name)"),
            let end = self[start.upperBound...].range(of: "func \(nextName)")
        else {
            return nil
        }
        return self[start.lowerBound..<end.lowerBound]
    }
}
