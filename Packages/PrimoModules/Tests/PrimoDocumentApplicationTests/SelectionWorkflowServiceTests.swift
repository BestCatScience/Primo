import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoBrushRuntimeContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import Testing

struct SelectionWorkflowServiceTests {
    @Test
    func combineReplaceReturnsIncomingSelection() {
        let service = SelectionWorkflowService(operations: .selectionStub())
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
            canvasGeometry: PixelGeometry(width: 1, height: 1)!
        )

        #expect(result == incoming)
    }

    @Test
    func lassoWithTooFewPointsReturnsNil() {
        let service = SelectionWorkflowService(operations: .selectionStub())

        let result = service.makeLassoSelection(
            from: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)],
            canvasGeometry: PixelGeometry(width: 4, height: 4)!
        )

        #expect(result == nil)
    }

    @Test
    func openLassoPointsBuildSelection() throws {
        let service = SelectionWorkflowService(operations: .selectionStub())

        let selection = try #require(
            service.makeLassoSelection(
                from: [
                    CGPoint(x: 1, y: 1),
                    CGPoint(x: 4, y: 1),
                    CGPoint(x: 4, y: 4),
                    CGPoint(x: 1, y: 4)
                ],
                canvasGeometry: PixelGeometry(width: 6, height: 6)!
            )
        )

        #expect(selection.mode == .lasso)
        #expect(selection.bounds == CGRect(x: 0, y: 0, width: 6, height: 6))
        #expect(selection.maskData == Data(repeating: 255, count: 36))
    }

    @Test
    func rectangleSelectionBuildsClampedMask() throws {
        let service = SelectionWorkflowService(operations: .selectionStub())

        let selection = try #require(
            service.makeRectangleSelection(
                from: CGPoint(x: -2, y: 1),
                to: CGPoint(x: 3, y: 4),
                canvasGeometry: PixelGeometry(width: 5, height: 5)!
            )
        )

        #expect(selection.bounds == CGRect(x: 0, y: 1, width: 3, height: 3))
        #expect(selection.maskWidth == 3)
        #expect(selection.maskHeight == 3)
        #expect(selection.maskData == Data(repeating: 255, count: 9))
        #expect(selection.mode == .rectangle)
    }

    @Test
    func zeroSizedRectangleSelectionReturnsNil() {
        let service = SelectionWorkflowService(operations: .selectionStub())

        let selection = service.makeRectangleSelection(
            from: CGPoint(x: 2, y: 2),
            to: CGPoint(x: 2, y: 5),
            canvasGeometry: PixelGeometry(width: 6, height: 6)!
        )

        #expect(selection == nil)
    }

    @Test
    func invertWithoutSelectionBuildsFullCanvasSelection() throws {
        let service = SelectionWorkflowService(operations: .selectionStub())

        let selection = try #require(
            service.invertedSelection(
                nil,
                canvasGeometry: PixelGeometry(width: 2, height: 2)!,
                mode: .auto
            )
        )

        #expect(selection.bounds == CGRect(x: 0, y: 0, width: 2, height: 2))
        #expect(selection.maskData == Data([255, 255, 255, 255]))
        #expect(selection.mode == .auto)
    }

    @Test
    func autoSelectionUsesActiveLayerPixels() throws {
        let service = SelectionWorkflowService(operations: .selectionStub())
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

        let layerIndex = try #require(
            DocumentLayerMutationContext(
                layerCount: 3,
                folderIDs: [],
                isLayerLocked: { _ in false }
            ).existingLayerIndex(2)
        )
        let selection = try #require(
            service.makeAutoSelection(
                at: CGPoint(x: 0, y: 0),
                snapshot: snapshot,
                layerIndex: layerIndex,
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

private extension DocumentSelectionMaskOperations {
    static func selectionFailure<Value>() -> DocumentRenderingResult<Value> {
        .failure(.kernelFailed(operation: "selectionStub"))
    }

    static func selectionStub() -> DocumentSelectionMaskOperations {
        DocumentSelectionMaskOperations(
            alphaMask: { _, _, _ in selectionFailure() },
            croppedSelectionMask: { mask, width, height in
                guard mask.contains(where: { $0 > 0 }) else { return nil }
                var minX = width
                var minY = height
                var maxX = -1
                var maxY = -1
                for y in 0..<height {
                    for x in 0..<width where mask[(y * width) + x] > 0 {
                        minX = min(minX, x)
                        minY = min(minY, y)
                        maxX = max(maxX, x)
                        maxY = max(maxY, y)
                    }
                }
                guard maxX >= minX, maxY >= minY else { return nil }
                let croppedWidth = maxX - minX + 1
                let croppedHeight = maxY - minY + 1
                var cropped = [UInt8](repeating: 0, count: croppedWidth * croppedHeight)
                for y in 0..<croppedHeight {
                    for x in 0..<croppedWidth {
                        cropped[(y * croppedWidth) + x] = mask[((minY + y) * width) + minX + x]
                    }
                }
                return DocumentCroppedSelectionMask(
                    bounds: CGRect(x: minX, y: minY, width: croppedWidth, height: croppedHeight),
                    maskData: Data(cropped),
                    maskWidth: croppedWidth,
                    maskHeight: croppedHeight
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
            transformedSelectionMask: { _ in selectionFailure() }
        )
    }
}
