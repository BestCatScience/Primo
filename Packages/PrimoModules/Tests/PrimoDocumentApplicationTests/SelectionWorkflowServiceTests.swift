import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import Testing

struct SelectionWorkflowServiceTests {
    @Test
    func combineReplaceReturnsIncomingSelection() {
        let service = SelectionWorkflowService(gpuOperations: .selectionStub())
        let incoming = CanvasSelection.unsafeUnchecked(
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            maskWidth: 1,
            maskHeight: 1,
            maskData: Data([255]),
            mode: .lasso
        )

        let result = service.combinedSelection(
            existing: nil,
            incoming: incoming,
            mode: .replace,
            canvasSize: CGSize(width: 1, height: 1)
        )

        #expect(result == incoming)
    }

    @Test
    func lassoWithTooFewPointsReturnsNil() {
        let service = SelectionWorkflowService(gpuOperations: .selectionStub())

        let result = service.makeLassoSelection(
            from: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)],
            canvasSize: CGSize(width: 4, height: 4)
        )

        #expect(result == nil)
    }

    @Test
    func invertWithoutSelectionBuildsFullCanvasSelection() throws {
        let service = SelectionWorkflowService(gpuOperations: .selectionStub())

        let selection = try #require(
            service.invertedSelection(
                nil,
                canvasSize: CGSize(width: 2, height: 2),
                mode: .auto
            )
        )

        #expect(selection.bounds == CGRect(x: 0, y: 0, width: 2, height: 2))
        #expect(selection.maskData == Data([255, 255, 255, 255]))
        #expect(selection.mode == .auto)
    }

    @Test
    func autoSelectionUsesActiveLayerPixels() throws {
        let service = SelectionWorkflowService(gpuOperations: .selectionStub())
        let layer = MetalLayerSnapshot.unsafeUnchecked(
            index: 2,
            opacity: 1,
            visible: true,
            isClipped: false,
            blendMode: .normal,
            thumbnailData: nil,
            pixelData: Data([255, 0, 0, 255])
        )
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 1,
            height: 1,
            revision: 1,
            compositePixelData: Data([0, 0, 0, 255]),
            layers: [layer]
        )

        let selection = try #require(
            service.makeAutoSelection(
                at: CGPoint(x: 0, y: 0),
                snapshot: snapshot,
                layerIndex: 2,
                thresholdMode: .opacity,
                opacityTolerance: 0,
                colorTolerance: 0,
                expansion: 0
            )
        )

        #expect(selection.maskData == Data([255]))
        #expect(selection.mode == .auto)
    }
}

private extension DocumentGpuOperationGateway {
    static func selectionFailure<Value>() -> DocumentRenderingResult<Value> {
        .failure(.kernelFailed(operation: "selectionStub"))
    }

    static func selectionStub() -> DocumentGpuOperationGateway {
        DocumentGpuOperationGateway(
            compositedPaperPreviewRGBA: { _, _, _, _ in selectionFailure() },
            compositedPreviewPixelData: { _, _, _ in selectionFailure() },
            compositedPreviewIncrementalUpdate: { _, _, _, _ in selectionFailure() },
            selectionOverlayRGBA: { _, _, _ in selectionFailure() },
            eyedropperLoupeRGBA: { _, _, _, _, _, _, _, _ in selectionFailure() },
            shapePreviewSurface: { _, _, _, _ in selectionFailure() },
            textLayerSurface: { _, _ in selectionFailure() },
            textLayoutRect: { _, _ in nil },
            processedLayerPixelData: { _, _, _, _ in selectionFailure() },
            alphaMask: { _, _, _ in selectionFailure() },
            croppedSelectionMask: { mask, width, height in
                guard mask.contains(where: { $0 > 0 }) else { return nil }
                return DocumentCroppedSelectionMask(
                    bounds: CGRect(x: 0, y: 0, width: width, height: height),
                    maskData: Data(mask),
                    maskWidth: width,
                    maskHeight: height
                )
            },
            combinedSelectionMask: { base, incoming, mode, _, _ in
                .success(zip(base, incoming).map { left, right in
                    switch mode {
                    case .add:
                        return max(left, right)
                    case .subtract:
                        return right > 0 ? 0 : left
                    }
                })
            },
            expandedSelectionMask: { request in
                .success(Array(request.maskData.prefix(request.canvasWidth * request.canvasHeight)))
            },
            lassoSelection: { _, width, height in
                .success([UInt8](repeating: 255, count: width * height))
            },
            autoSelection: { _, width, height, _, _, _, _, _, _ in
                .success([UInt8](repeating: 255, count: width * height))
            },
            colorRangeSelection: { _, width, height, _ in
                .success([UInt8](repeating: 255, count: width * height))
            },
            expandedMask: { source, _, _, _ in .success(source) },
            contractedMask: { source, _, _, _ in .success(source) },
            featheredMask: { source, _, _, _ in .success(source) },
            invertMask: { source in .success(source.map { $0 > 0 ? 0 : 255 }) },
            transformedSelectionMask: { _ in selectionFailure() },
            transformedLayerPixelData: { _ in selectionFailure() },
            scaledPixelData: { _, _, _, _, _ in selectionFailure() },
            translatedPixelData: { _, _, _, _, _, _, _ in selectionFailure() },
            releaseSurfaceHandle: { _ in }
        )
    }
}
