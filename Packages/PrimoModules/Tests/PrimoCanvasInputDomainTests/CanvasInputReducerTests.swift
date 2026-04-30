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
    func selectionAndTransformEmitCommands() {
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

        var transformState = CanvasInputReducer.State()
        _ = reducer.reduce(
            phase: .began,
            sample: sample(x: 10, y: 10, pressure: 1, time: 0),
            coalescedSamples: [sample(x: 10, y: 10, pressure: 1, time: 0)],
            state: &transformState,
            configuration: CanvasInputConfiguration(tool: .move)
        )
        let moveCommands = reducer.reduce(
            phase: .moved,
            sample: sample(x: 14, y: 16, pressure: 1, time: 0.1),
            coalescedSamples: [sample(x: 14, y: 16, pressure: 1, time: 0.1)],
            state: &transformState,
            configuration: CanvasInputConfiguration(tool: .move)
        )
        #expect(moveCommands == [CanvasInputCommand.updateTransform(CGSize(width: 4, height: 6))])
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
}
