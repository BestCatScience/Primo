import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoDocumentApplication
import PrimoDocumentContracts
import XCTest

final class DocumentInteractionPerformanceTests: XCTestCase {
    func testApplySoftwareStrokeRequestDispatchPerformance() {
        let samples = (0..<512).map { index in
            StylusSample(
                point: CGPoint(x: index, y: index),
                pressure: 1.0,
                altitude: 0.0,
                azimuth: 0.0,
                timestamp: Double(index) * 0.01
            )
        }
        let service = DocumentInteractionService(
            queryGateway: DocumentQueryGateway(
                lightweightPresentation: { PaintDocumentPresentation(canvasSize: .zero, activeLayerIndex: 0, layerRows: [], layerSidebarRows: [], renderSnapshot: nil) },
                presentation: { PaintDocumentPresentation(canvasSize: .zero, activeLayerIndex: 0, layerRows: [], layerSidebarRows: [], renderSnapshot: nil) },
                compositePixelData: { Data() },
                compositeSurface: { DocumentCompositeSurface(width: 0, height: 0, pixelData: Data()) },
                pixelDataForLayer: { _ in Data() },
                consumeDirtyUpdate: { nil }
            ),
            mutationGateway: DocumentMutationGateway(
                resizeCanvas: { _, _ in .success(()) },
                resizeCanvasExtent: { _, _ in .success(()) },
                addLayer: { _ in .success(0) },
                deleteLayer: { _ in .success(()) },
                setActiveLayer: { _ in .success(()) },
                setLayerName: { _, _ in .success(()) },
                setLayerVisibility: { _, _ in .success(()) },
                revealLayerForEditing: { _ in .success(()) },
                replaceLayerPixels: { _, _ in .success(()) },
                replaceLayerPixelsInRect: { _, _, _ in .success(()) },
                applyLayerMutation: { _, _ in .success(()) },
                applyTextLayerMutation: { _, _, _ in .success(()) },
                replaceLayerMask: { _, _ in .success(()) },
                clearLayerMask: { _ in .success(()) },
                applyLayerMask: { _ in .success(()) },
                clearLayer: { _ in .success(()) },
                applyLayerProcessing: { _, _ in .success(()) }
            ),
            strokeGateway: StrokeInputGateway(
                beginStroke: { _, _ in },
                appendStroke: { _ in },
                endStroke: {},
                cancelStroke: {},
                blurStroke: { _, _, _, _ in .success(()) },
                endBlurStroke: {},
                fill: { _, _ in .success(()) },
                applySoftwareStroke: { _, _, _ in .success(()) }
            ),
            historyGateway: DocumentHistoryGateway(
                canUndo: { true },
                canRedo: { true },
                undo: { .success(()) },
                redo: { .success(()) }
            ),
            persistenceGateway: DocumentPersistenceGateway(
                saveProject: { _, _ in },
                loadProject: { _ in
                    LoadedPaintProject(
                        presentation: PaintDocumentPresentation(canvasSize: .zero, activeLayerIndex: 0, layerRows: [], layerSidebarRows: [], renderSnapshot: nil),
                        paperStyle: .default
                    )
                },
                setPaperStyle: { _ in },
                newCanvas: { _, _ in },
                prewarmDrawingResources: {}
            )
        )
        let brush = BrushRuntimeSettings(
            tipKind: .ink,
            radius: 8,
            opacity: 1,
            hardness: 1,
            roundness: 1,
            angle: 0,
            angleMode: .fixed,
            stampSpacing: 0.1,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .off,
            textureStrength: 0,
            pressureSensitivity: 1,
            red: 255,
            green: 255,
            blue: 255
        )

        measure {
            XCTAssertEqual(
                service.execute(.applySoftwareStroke(samples: samples, brush: brush, layerIndex: 0)),
                .success(.none)
            )
        }
    }
}
