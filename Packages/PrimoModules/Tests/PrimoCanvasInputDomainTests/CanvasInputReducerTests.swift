import CoreGraphics
import Foundation
import PrimoCanvasInputDomain
import PrimoDocumentDomain
import Testing
import simd

@Suite
struct CanvasInputReducerTests {
    @Test
    func brushStrokeInterpolatesCoalescedSamplesAndEnds() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            brushSize: 4,
            strokeStabilization: 0
        )

        var commands = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 0.5, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 0.5, time: 0)],
            state: &state,
            configuration: configuration
        )

        guard case let .updateStroke(initialStroke) = commands.first else {
            Issue.record("Expected initial stroke command")
            return
        }
        #expect(initialStroke.points.count == 1)

        commands = reducer.reduce(
            phase: .moved,
            sample: sample(x: 20, y: 0, pressure: 0.7, time: 0.1),
            coalescedSamples: [sample(x: 20, y: 0, pressure: 0.7, time: 0.1)],
            state: &state,
            configuration: configuration
        )

        guard case let .updateStroke(movedStroke) = commands.first else {
            Issue.record("Expected moved stroke command")
            return
        }
        #expect(movedStroke.points.count > 2)
        #expect(movedStroke.points.last?.position.x == 20)

        commands = reducer.reduce(
            phase: .ended,
            sample: sample(x: 24, y: 0, pressure: 0.6, time: 0.2),
            coalescedSamples: [sample(x: 24, y: 0, pressure: 0.6, time: 0.2)],
            state: &state,
            configuration: configuration
        )

        guard case let .endStroke(finalStroke) = commands.first else {
            Issue.record("Expected end stroke command")
            return
        }
        #expect(finalStroke.predictedPoints.isEmpty)
        #expect(state.currentStroke == nil)
    }

    @Test
    func brushStrokeStabilizationSmoothsInputPoints() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            brushSize: 8,
            strokeStabilization: 1.0
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 0.6, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 0.6, time: 0)],
            state: &state,
            configuration: configuration
        )

        let commands = reducer.reduce(
            phase: .moved,
            sample: sample(x: 30, y: 12, pressure: 0.6, time: 0.3),
            coalescedSamples: [
                sample(x: 10, y: 12, pressure: 0.6, time: 0.1),
                sample(x: 20, y: -12, pressure: 0.6, time: 0.2),
                sample(x: 30, y: 12, pressure: 0.6, time: 0.3)
            ],
            state: &state,
            configuration: configuration
        )

        guard case let .updateStroke(stroke) = commands.first,
              let lastPoint = stroke.points.last
        else {
            Issue.record("Expected stabilized stroke update")
            return
        }
        #expect(lastPoint.position.x < 30)
        #expect(abs(lastPoint.position.y) < 12)
    }

    @Test
    func maximumBrushStrokeStabilizationCreatesVisibleLazyFollow() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            brushSize: 8,
            strokeStabilization: 1.0
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 0.6, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 0.6, time: 0)],
            state: &state,
            configuration: configuration
        )

        let commands = reducer.reduce(
            phase: .moved,
            sample: sample(x: 80, y: 0, pressure: 0.6, time: 0.1),
            coalescedSamples: [sample(x: 80, y: 0, pressure: 0.6, time: 0.1)],
            state: &state,
            configuration: configuration
        )

        guard case let .updateStroke(stroke) = commands.first,
              let lastPoint = stroke.points.last
        else {
            Issue.record("Expected stabilized stroke update")
            return
        }
        #expect(lastPoint.position.x < 50)
    }

    @Test
    func ropeStabilizationHoldsAnchorDuringSmallJitter() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            brushSize: 8,
            strokeStabilization: 1.0
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 0.6, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 0.6, time: 0)],
            state: &state,
            configuration: configuration
        )

        let commands = reducer.reduce(
            phase: .moved,
            sample: sample(x: 6, y: -5, pressure: 0.6, time: 0.3),
            coalescedSamples: [
                sample(x: 4, y: 5, pressure: 0.6, time: 0.1),
                sample(x: -5, y: -4, pressure: 0.6, time: 0.2),
                sample(x: 6, y: -5, pressure: 0.6, time: 0.3)
            ],
            state: &state,
            configuration: configuration
        )

        guard case let .updateStroke(stroke) = commands.first,
              let lastPoint = stroke.points.last
        else {
            Issue.record("Expected stabilized stroke update")
            return
        }
        #expect(lastPoint.position == SIMD2<Float>(0, 0))
        #expect(state.stabilizerAnchor?.position == SIMD2<Float>(0, 0))
        #expect(state.rawStrokePoints.count == 4)
    }

    @Test
    func predictedSamplesUpdatePredictedPointsOnly() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            brushSize: 8,
            strokeStabilization: 1.0
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 0.6, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 0.6, time: 0)],
            state: &state,
            configuration: configuration
        )

        let commands = reducer.reduce(
            phase: .moved,
            sample: sample(x: 80, y: 0, pressure: 0.6, time: 0.1),
            coalescedSamples: [sample(x: 80, y: 0, pressure: 0.6, time: 0.1)],
            predictedSamples: [
                sample(x: 92, y: 3, pressure: 0.6, time: 0.12),
                sample(x: 104, y: 4, pressure: 0.6, time: 0.14)
            ],
            state: &state,
            configuration: configuration
        )

        guard case let .updateStroke(stroke) = commands.first else {
            Issue.record("Expected stabilized stroke update")
            return
        }
        #expect(!stroke.predictedPoints.isEmpty)
        #expect(stroke.predictedPoints.allSatisfy { $0.isPredicted })
        #expect(stroke.points.allSatisfy { !$0.isPredicted })
        #expect(state.rawStrokePoints.count == 2)
    }

    @Test
    func brushStrokeContinuesPastPreviousInteractiveSampleLimit() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            brushSize: 4,
            strokeStabilization: 0
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 0.6, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 0.6, time: 0)],
            state: &state,
            configuration: configuration
        )

        var latestStroke: CanvasInputStroke?
        for index in 1...17_000 {
            let position = CGFloat(index) * 0.3
            let commands = reducer.reduce(
                phase: .moved,
                sample: sample(x: position, y: 0, pressure: 0.6, time: TimeInterval(index) * 0.01),
                coalescedSamples: [sample(x: position, y: 0, pressure: 0.6, time: TimeInterval(index) * 0.01)],
                state: &state,
                configuration: configuration
            )
            if case let .updateStroke(stroke) = commands.first {
                latestStroke = stroke
            }
        }

        #expect((latestStroke?.points.count ?? 0) > 16_384)
        #expect(latestStroke?.points.last?.position.x == Float(17_000) * 0.3)
    }

    @Test
    func shapeStrokeBuildsRectangleWithoutUIKit() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .shape,
            shapeMode: .rectangle,
            brushSize: 4
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        let commands = reducer.reduce(
            phase: .moved,
            sample: sample(x: 10, y: 8, pressure: 1, time: 0.1),
            coalescedSamples: [sample(x: 10, y: 8, pressure: 1, time: 0.1)],
            state: &state,
            configuration: configuration
        )

        guard case let .updateStroke(stroke) = commands.first else {
            Issue.record("Expected rectangle preview")
            return
        }
        #expect(stroke.points.contains { $0.position == SIMD2<Float>(10, 8) })
        #expect(stroke.points.count > 8)
    }

    @Test
    func selectionEmitsCommands() {
        let reducer = CanvasInputReducer()
        var selectionState = CanvasInputReducer.State()
        let selectionCommands = reducer.reduce(
            phase: .began,
            sample: sample(x: 3, y: 4, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 3, y: 4, pressure: 1, time: 0)],
            state: &selectionState,
            configuration: CanvasInputConfiguration(tool: .select)
        )
        #expect(selectionCommands == [CanvasInputCommand.updateSelectionPath([CGPoint(x: 3, y: 4)])])
    }

    @Test
    func lassoSelectionEndsWithCollectedPointsAndClearsState() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(tool: .select, selectionMode: .lasso)

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        _ = reducer.reduce(
            phase: .moved,
            sample: sample(x: 10, y: 10, pressure: 1, time: 0.1),
            coalescedSamples: [
                sample(x: 0, y: 0, pressure: 1, time: 0.02),
                sample(x: 10, y: 0, pressure: 1, time: 0.06),
                sample(x: 10, y: 10, pressure: 1, time: 0.1)
            ],
            state: &state,
            configuration: configuration
        )
        let ended = reducer.reduce(
            phase: .ended,
            sample: sample(x: 0, y: 10, pressure: 1, time: 0.2),
            coalescedSamples: [sample(x: 0, y: 10, pressure: 1, time: 0.2)],
            state: &state,
            configuration: configuration
        )

        #expect(ended == [.endSelectionPath([
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 0, y: 10)
        ])])
        #expect(state.currentSelectionPoints.isEmpty)
    }

    @Test
    func lassoSelectionDoesNotEndWhenMovingNearStartPoint() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(tool: .select, selectionMode: .lasso)

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        let update = reducer.reduce(
            phase: .moved,
            sample: sample(x: 1, y: 1, pressure: 1, time: 0.2),
            coalescedSamples: [
                sample(x: 20, y: 0, pressure: 1, time: 0.05),
                sample(x: 20, y: 20, pressure: 1, time: 0.1),
                sample(x: 1, y: 1, pressure: 1, time: 0.2)
            ],
            state: &state,
            configuration: configuration
        )

        #expect(update == [.updateSelectionPath([
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 20, y: 20),
            CGPoint(x: 1, y: 1)
        ])])
    }

    @Test
    func rectangleSelectionEmitsStartCurrentPoints() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(tool: .select, selectionMode: .rectangle)

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 3, y: 4, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 3, y: 4, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        let update = reducer.reduce(
            phase: .moved,
            sample: sample(x: 9, y: 11, pressure: 1, time: 0.1),
            coalescedSamples: [sample(x: 9, y: 11, pressure: 1, time: 0.1)],
            state: &state,
            configuration: configuration
        )
        let ended = reducer.reduce(
            phase: .ended,
            sample: sample(x: 12, y: 14, pressure: 1, time: 0.2),
            coalescedSamples: [sample(x: 12, y: 14, pressure: 1, time: 0.2)],
            state: &state,
            configuration: configuration
        )

        #expect(update == [.updateSelectionPath([CGPoint(x: 3, y: 4), CGPoint(x: 9, y: 11)])])
        #expect(ended == [.endSelectionPath([CGPoint(x: 3, y: 4), CGPoint(x: 12, y: 14)])])
    }

    @Test
    func selectionInsideExistingMaskBeginsMoveInsteadOfLasso() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .select,
            selectionContext: CanvasInputSelectionContext(
                bounds: CGRect(x: 2, y: 2, width: 4, height: 4),
                maskWidth: 4,
                maskHeight: 4,
                maskData: Data(repeating: 255, count: 16)
            )
        )

        let commands = reducer.reduce(
            phase: .began,
            sample: sample(x: 3, y: 4, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 3, y: 4, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )

        #expect(commands == [.beginSelectionMove(CGPoint(x: 3, y: 4))])
    }

    @Test
    func selectionMoveUpdatesAndEndsWithOffset() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .select,
            selectionContext: CanvasInputSelectionContext(
                bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                maskWidth: 10,
                maskHeight: 10,
                maskData: Data(repeating: 255, count: 100)
            )
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 2, y: 3, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 2, y: 3, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        let update = reducer.reduce(
            phase: .moved,
            sample: sample(x: 7, y: 1, pressure: 1, time: 0.1),
            coalescedSamples: [sample(x: 7, y: 1, pressure: 1, time: 0.1)],
            state: &state,
            configuration: configuration
        )
        let ended = reducer.reduce(
            phase: .ended,
            sample: sample(x: 8, y: 2, pressure: 1, time: 0.2),
            coalescedSamples: [sample(x: 8, y: 2, pressure: 1, time: 0.2)],
            state: &state,
            configuration: configuration
        )

        #expect(update == [.updateSelectionMove(CGSize(width: 5, height: -2))])
        #expect(ended == [.endSelectionMove(CGSize(width: 6, height: -1))])
    }

    @Test
    func selectionOutsideExistingMaskStartsNewLasso() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .select,
            selectionContext: CanvasInputSelectionContext(
                bounds: CGRect(x: 2, y: 2, width: 4, height: 4),
                maskWidth: 4,
                maskHeight: 4,
                maskData: Data(repeating: 255, count: 16)
            )
        )

        let commands = reducer.reduce(
            phase: .began,
            sample: sample(x: 8, y: 8, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 8, y: 8, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )

        #expect(commands == [.updateSelectionPath([CGPoint(x: 8, y: 8)])])
    }

    @Test
    func opaqueActiveLayerPointBeginsWholeLayerMoveWhenNoSelectionExists() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .select,
            layerMoveContext: CanvasInputLayerMoveContext(
                bounds: CGRect(x: 0, y: 0, width: 4, height: 4),
                width: 4,
                height: 4,
                pixelData: rgbaPixelData(width: 4, height: 4, opaquePixels: [CGPoint(x: 2, y: 1)])
            )
        )

        let began = reducer.reduce(
            phase: .began,
            sample: sample(x: 2, y: 1, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 2, y: 1, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        let moved = reducer.reduce(
            phase: .moved,
            sample: sample(x: 5, y: 4, pressure: 1, time: 0.1),
            coalescedSamples: [sample(x: 5, y: 4, pressure: 1, time: 0.1)],
            state: &state,
            configuration: configuration
        )
        let ended = reducer.reduce(
            phase: .ended,
            sample: sample(x: 6, y: 5, pressure: 1, time: 0.2),
            coalescedSamples: [sample(x: 6, y: 5, pressure: 1, time: 0.2)],
            state: &state,
            configuration: configuration
        )

        #expect(began == [.beginSelectionMove(CGPoint(x: 2, y: 1))])
        #expect(moved == [.updateSelectionMove(CGSize(width: 3, height: 3))])
        #expect(ended == [.endSelectionMove(CGSize(width: 4, height: 4))])
    }

    @Test
    func transparentActiveLayerPointStartsLassoWhenNoSelectionExists() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .select,
            layerMoveContext: CanvasInputLayerMoveContext(
                bounds: CGRect(x: 0, y: 0, width: 4, height: 4),
                width: 4,
                height: 4,
                pixelData: rgbaPixelData(width: 4, height: 4, opaquePixels: [CGPoint(x: 2, y: 1)])
            )
        )

        let commands = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )

        #expect(commands == [.updateSelectionPath([CGPoint(x: 0, y: 0)])])
    }

    @Test
    func moveToolBeginsLayerMoveOnOpaquePoint() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .move,
            layerMoveContext: CanvasInputLayerMoveContext(
                bounds: CGRect(x: 0, y: 0, width: 4, height: 4),
                width: 4,
                height: 4,
                pixelData: rgbaPixelData(width: 4, height: 4, opaquePixels: [CGPoint(x: 1, y: 1)])
            )
        )

        let began = reducer.reduce(
            phase: .began,
            sample: sample(x: 1, y: 1, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 1, y: 1, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        let ended = reducer.reduce(
            phase: .ended,
            sample: sample(x: 3, y: 4, pressure: 1, time: 0.1),
            coalescedSamples: [sample(x: 3, y: 4, pressure: 1, time: 0.1)],
            state: &state,
            configuration: configuration
        )

        #expect(began == [.beginSelectionMove(CGPoint(x: 1, y: 1))])
        #expect(ended == [.endSelectionMove(CGSize(width: 2, height: 3))])
    }

    @Test
    func moveToolDoesNotStartLassoOnTransparentPoint() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .move,
            layerMoveContext: CanvasInputLayerMoveContext(
                bounds: CGRect(x: 0, y: 0, width: 4, height: 4),
                width: 4,
                height: 4,
                pixelData: rgbaPixelData(width: 4, height: 4, opaquePixels: [CGPoint(x: 1, y: 1)])
            )
        )

        let commands = reducer.reduce(
            phase: .began,
            sample: sample(x: 0, y: 0, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 0, y: 0, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )

        #expect(commands.isEmpty)
    }

    @Test
    func selectionMoveCancelClearsMoveState() {
        let reducer = CanvasInputReducer()
        var state = CanvasInputReducer.State()
        let configuration = CanvasInputConfiguration(
            tool: .select,
            selectionContext: CanvasInputSelectionContext(
                bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                maskWidth: 10,
                maskHeight: 10,
                maskData: Data(repeating: 255, count: 100)
            )
        )

        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 2, y: 2, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 2, y: 2, pressure: 1, time: 0)],
            state: &state,
            configuration: configuration
        )
        let cancelled = reducer.reduce(
            phase: .cancelled,
            sample: sample(x: 4, y: 4, pressure: 1, time: 0.1),
            coalescedSamples: [sample(x: 4, y: 4, pressure: 1, time: 0.1)],
            state: &state,
            configuration: configuration
        )
        let restarted = reducer.reduce(
            phase: .began,
            sample: sample(x: 14, y: 14, pressure: 1, time: 0.2),
            coalescedSamples: [sample(x: 14, y: 14, pressure: 1, time: 0.2)],
            state: &state,
            configuration: configuration
        )

        #expect(cancelled == [.cancelSelectionMove])
        #expect(restarted == [.updateSelectionPath([CGPoint(x: 14, y: 14)])])
    }

    private func sample(x: CGFloat, y: CGFloat, pressure: Float, time: TimeInterval) -> CanvasInputSample {
        CanvasInputSample(
            point: CGPoint(x: x, y: y),
            pressure: pressure,
            altitude: 0.7,
            azimuth: 0.2,
            timestamp: time
        )
    }

    private func rgbaPixelData(width: Int, height: Int, opaquePixels: [CGPoint]) -> Data {
        var data = Data(repeating: 0, count: width * height * 4)
        for point in opaquePixels {
            let x = Int(point.x)
            let y = Int(point.y)
            guard (0..<width).contains(x), (0..<height).contains(y) else { continue }
            let index = ((y * width) + x) * 4
            data[index] = 255
            data[index + 1] = 255
            data[index + 2] = 255
            data[index + 3] = 255
        }
        return data
    }
}
