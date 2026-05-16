import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentContracts
import PrimoDocumentGPUContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct SwiftDocumentRuntimeUndoTests {
    @Test
    func pixelDataForLayerReturnsFailureForInvalidLayerIndexes() {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        guard case .failure(.invalidLayerIndex(-1)) = runtime.pixelDataForLayer(index: -1) else {
            Issue.record("Expected negative layer index read to fail")
            return
        }
        guard case .failure(.invalidLayerIndex(1)) = runtime.pixelDataForLayer(index: 1) else {
            Issue.record("Expected out-of-range layer index read to fail")
            return
        }
    }

    @Test
    func redundantLayerVisibilityChangeDoesNotCreateUndoStep() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [Data(repeating: 0x33, count: 16)])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.setLayerVisibility(index: 0, isVisible: true).get()
        _ = try runtime.applyGpuStrokeSurface(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()
        _ = try runtime.undo().get()

        #expect(try runtime.pixelDataForLayer(index: 0).get() == Data(count: 16))
        guard case .failure(.noUndoState) = runtime.undo() else {
            Issue.record("Expected redundant visibility request not to leave an undo step")
            return
        }
    }

    @Test
    func undoSkipsLegacyRevisionOnlyHistoryEntries() throws {
        let firstStrokePixels = Data(repeating: 0x44, count: 16)
        let secondStrokePixels = Data(repeating: 0x55, count: 16)
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [firstStrokePixels, secondStrokePixels])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.applyGpuStrokeSurface(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()
        _ = try runtime.setLayerName(index: 0, name: "Layer 1").get()
        _ = try runtime.applyGpuStrokeSurface(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()

        _ = try runtime.undo().get()
        #expect(try runtime.pixelDataForLayer(index: 0).get() == firstStrokePixels)

        _ = try runtime.undo().get()
        #expect(try runtime.pixelDataForLayer(index: 0).get() == Data(count: 16))
    }

    @Test
    func undoAfterTwoGpuStrokesRestoresFirstStrokePixels() throws {
        let firstStrokePixels = Data(repeating: 0x11, count: 16)
        let secondStrokePixels = Data(repeating: 0x22, count: 16)
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [firstStrokePixels, secondStrokePixels])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.applyGpuStrokeSurface(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()
        _ = try runtime.applyGpuStrokeSurface(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()

        _ = try runtime.undo().get()

        #expect(try runtime.pixelDataForLayer(index: 0).get() == firstStrokePixels)
    }

    @Test
    func dirtyRectReplacementUndoRedoRestoresOnlyChangedPixels() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(width: 3, height: 2, gpuServices: gpu.services())
        let rect = LayerPixelRect.unsafeUnchecked(originX: 1, originY: 0, width: 1, height: 1)
        let patch = Data([0x10, 0x20, 0x30, 0x40])

        _ = try runtime.replaceLayerPixels(index: 0, in: rect, data: patch).get()

        var expected = Data(count: 24)
        expected.replaceSubrange(4..<8, with: patch)
        #expect(try runtime.pixelDataForLayer(index: 0).get() == expected)

        _ = try runtime.undo().get()
        #expect(try runtime.pixelDataForLayer(index: 0).get() == Data(count: 24))

        _ = try runtime.redo().get()
        #expect(try runtime.pixelDataForLayer(index: 0).get() == expected)
    }

    @Test
    func strokeThenRenameUndoRedoKeepsPixelAndMetadataEntriesSeparate() throws {
        let strokePixels = Data(repeating: 0x44, count: 16)
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [strokePixels])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.applyGpuStrokeSurface(samples: [sample()], brush: brush(), layerIndex: 0).get()
        _ = try runtime.setLayerName(index: 0, name: "Renamed").get()

        _ = try runtime.undo().get()
        #expect(runtime.lightweightPresentation().layerRows[0].name == "Layer 1")
        #expect(try runtime.pixelDataForLayer(index: 0).get() == strokePixels)

        _ = try runtime.redo().get()
        #expect(runtime.lightweightPresentation().layerRows[0].name == "Renamed")
        #expect(try runtime.pixelDataForLayer(index: 0).get() == strokePixels)

        _ = try runtime.undo().get()
        _ = try runtime.undo().get()
        #expect(runtime.lightweightPresentation().layerRows[0].name == "Layer 1")
        #expect(try runtime.pixelDataForLayer(index: 0).get() == Data(count: 16))
    }

    @Test
    func strokeThenVisibilityUndoRedoKeepsPixelAndMetadataEntriesSeparate() throws {
        let strokePixels = Data(repeating: 0x55, count: 16)
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [strokePixels])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.applyGpuStrokeSurface(samples: [sample()], brush: brush(), layerIndex: 0).get()
        _ = try runtime.setLayerVisibility(index: 0, isVisible: false).get()

        _ = try runtime.undo().get()
        #expect(runtime.lightweightPresentation().layerRows[0].visible)
        #expect(try runtime.pixelDataForLayer(index: 0).get() == strokePixels)

        _ = try runtime.redo().get()
        #expect(!runtime.lightweightPresentation().layerRows[0].visible)
        #expect(try runtime.pixelDataForLayer(index: 0).get() == strokePixels)

        _ = try runtime.undo().get()
        _ = try runtime.undo().get()
        #expect(runtime.lightweightPresentation().layerRows[0].visible)
        #expect(try runtime.pixelDataForLayer(index: 0).get() == Data(count: 16))
    }

    @Test
    func strokeUndoRestoresTextLayerMetadataClearedByStrokeDelta() throws {
        let textLayer = try #require(TextLayerData(
            validatingText: "Undo text",
            positionX: 1,
            positionY: 1,
            fontPostScriptName: "Helvetica",
            fontDisplayName: "Helvetica",
            fontSize: 12,
            red: 1,
            green: 1,
            blue: 1,
            alpha: 1
        ))
        let strokePixels = Data(repeating: 0x66, count: 16)
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [strokePixels])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.setTextLayer(index: 0, textLayer: textLayer).get()
        #expect(runtime.textLayerData(index: 0) == textLayer)

        _ = try runtime.applyGpuStrokeSurface(samples: [sample()], brush: brush(), layerIndex: 0).get()
        #expect(runtime.textLayerData(index: 0) == nil)
        #expect(try runtime.pixelDataForLayer(index: 0).get() == strokePixels)

        _ = try runtime.undo().get()
        #expect(runtime.textLayerData(index: 0) == textLayer)

        _ = try runtime.redo().get()
        #expect(runtime.textLayerData(index: 0) == nil)
        #expect(try runtime.pixelDataForLayer(index: 0).get() == strokePixels)
    }

    @Test
    func undoHistoryEvictsOldEntriesWhenByteBudgetIsExceeded() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(
            width: 4,
            height: 4,
            gpuServices: gpu.services(),
            maxUndoEntryCount: 50,
            maxUndoRetainedBytes: 200
        )
        let rect = LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4)

        _ = try runtime.replaceLayerPixels(index: 0, in: rect, data: Data(repeating: 0x11, count: 64)).get()
        _ = try runtime.replaceLayerPixels(index: 0, in: rect, data: Data(repeating: 0x22, count: 64)).get()
        _ = try runtime.replaceLayerPixels(index: 0, in: rect, data: Data(repeating: 0x33, count: 64)).get()

        _ = try runtime.undo().get()
        #expect(try runtime.pixelDataForLayer(index: 0).get() == Data(repeating: 0x22, count: 64))
        guard case .failure(.noUndoState) = runtime.undo() else {
            Issue.record("Expected older undo entries to be evicted by byte budget")
            return
        }
    }

    @Test
    func memoryPressureTrimDropsRedoAndShrinksUndoHistory() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(
            width: 2,
            height: 2,
            gpuServices: gpu.services(),
            maxUndoEntryCount: 50,
            maxUndoRetainedBytes: 1_024
        )
        let rect = LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 1, height: 1)

        for value in UInt8(1)...UInt8(10) {
            _ = try runtime.replaceLayerPixels(
                index: 0,
                in: rect,
                data: Data([value, value, value, value])
            ).get()
        }
        _ = try runtime.undo().get()
        #expect(runtime.canRedo())

        runtime.trimUndoHistoryForMemoryPressure()

        #expect(!runtime.canRedo())
        var undoCount = 0
        while runtime.canUndo() {
            _ = try runtime.undo().get()
            undoCount += 1
        }
        #expect(undoCount <= 8)
    }

    @Test
    func structuralMutationsUseSnapshotFallbackForUndoRedo() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.addLayer(name: "Snapshot fallback").get()
        #expect(runtime.lightweightPresentation().layerRows.count == 2)

        _ = try runtime.undo().get()
        #expect(runtime.lightweightPresentation().layerRows.count == 1)

        _ = try runtime.redo().get()
        #expect(runtime.lightweightPresentation().layerRows.count == 2)
    }

    @Test
    func alphaLockedGpuStrokeTimelapseDoesNotRecordEmptyReplaceLayerPixels() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let sourcePixels = Data(repeating: 0x44, count: 16)
        let handle = gpu.makeHandle(width: 2, height: 2, pixelData: sourcePixels)

        _ = try runtime.setLayerAlphaLocked(index: 0, isAlphaLocked: true).get()
        _ = try runtime.applyLayerSurfaceMutation(
            index: 0,
            payload: GpuLayerMutationPayload.unsafeUnchecked(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                gpuBufferHandle: handle,
                fallbackPixelData: nil
            )
        ).get()

        guard case let .operations(operations) = runtime.timelapseCapture()?.source,
              case let .replaceLayerPixels(_, data)? = operations.last
        else {
            Issue.record("Expected alpha-locked GPU mutation to record replaceLayerPixels")
            return
        }

        #expect(!data.isEmpty)
        #expect(data != Data(count: 16))
        #expect(data == (try runtime.pixelDataForLayer(index: 0).get()))
    }

    @Test
    func alphaLockedGpuStrokeAdoptsSameAlphaPreservedHandle() throws {
        let strokePixels = Data(repeating: 0x55, count: 16)
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [strokePixels])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.setLayerAlphaLocked(index: 0, isAlphaLocked: true).get()
        _ = try runtime.applyGpuStrokeSurface(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()

        #expect(try runtime.pixelDataForLayer(index: 0).get() == strokePixels)
    }

    @Test
    func cancelBlurStrokeRestoresBaselineWithoutUndoOrTimelapse() throws {
        let blurredPixels = Data(repeating: 0x77, count: 16)
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [], blurOutputs: [blurredPixels])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let baselinePixels = Data(count: 16)

        _ = try runtime.blur(samples: [sample()], brush: brush(), layerIndex: 0, captureTimelapse: false).get()
        #expect(try runtime.pixelDataForLayer(index: 0).get() == blurredPixels)

        runtime.cancelBlurStroke()

        #expect(try runtime.pixelDataForLayer(index: 0).get() == baselinePixels)
        #expect(!runtime.canUndo())
        if case let .operations(operations) = runtime.timelapseCapture()?.source {
            #expect(!operations.contains { operation in
                if case .blurStroke = operation { return true }
                return false
            })
        }
    }

    @Test
    func makeBlurPlanDoesNotReserveBlurSession() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        _ = try runtime.makeBlurPlan(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0,
            captureTimelapse: false
        ).get()

        guard case .failure(.inconsistentComposition(operation: "endBlurStroke", reason: "missing baseline")) = runtime.endBlurStroke() else {
            Issue.record("Expected pure blur planning to leave no blur session reserved")
            return
        }
    }

    @Test
    func failedBlurPayloadRollsBackReservedBlurSession() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [], blurReturnsNil: true)
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())

        guard case .failure(.rawAPIUnavailable(operation: "blurStroke")) =
            runtime.blur(samples: [sample()], brush: brush(), layerIndex: 0, captureTimelapse: false)
        else {
            Issue.record("Expected nil blur payload to fail")
            return
        }
        guard case .failure(.inconsistentComposition(operation: "endBlurStroke", reason: "missing baseline")) = runtime.endBlurStroke() else {
            Issue.record("Expected failed blur payload to roll back the blur session reservation")
            return
        }
    }

    @Test
    func liveBlurKernelFailureRollsBackReservedBlurSession() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [], blurReturnsNil: true)
        let runtime = DocumentEngineFactory.live(gpuServices: gpu.services())

        guard case .failure(.gpu(.kernelFailed(operation: "blurStroke"))) =
            runtime.strokeGateway.blurStroke([sample()], brush(), 0, false)
        else {
            Issue.record("Expected live nil blur payload to map to a blur kernel failure")
            return
        }
        guard case .failure(.inconsistentComposition(operation: "endBlurStroke", reason: "missing baseline")) =
            runtime.strokeGateway.endBlurStroke()
        else {
            Issue.record("Expected live blur failure to roll back the blur session reservation")
            return
        }
    }

    @Test
    func gpuBackedStrokeFillAndBlurPlansPassRetainedSourceHandles() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [Data(repeating: 0x55, count: 16)])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let handle = gpu.makeHandle(width: 2, height: 2, pixelData: Data(repeating: 0x33, count: 16))

        _ = try runtime.applyLayerSurfaceMutation(
            index: 0,
            payload: GpuLayerMutationPayload.unsafeUnchecked(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                gpuBufferHandle: handle,
                fallbackPixelData: nil
            )
        ).get()

        let strokePlan = try runtime.makeStrokeCommitPlan(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()
        _ = runtime.strokeCommitResult(for: strokePlan)

        let fillPlan = try runtime.makeFillPlan(sample: sample(), brush: brush()).get()
        _ = runtime.fillPayload(for: fillPlan)

        let blurPlan = try runtime.makeBlurPlan(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0,
            captureTimelapse: false
        ).get()
        _ = runtime.blurPayload(for: blurPlan)

        #expect(gpu.retainedHandleValues == [handle, handle, handle])
        #expect(gpu.strokeBaseBufferHandleValues == [handle])
        #expect(gpu.fillSourceBufferHandleValues == [handle])
        #expect(gpu.blurSourceBufferHandleValues == [handle])
    }

    @Test
    func gpuPlanFallsBackToPixelDataWhenRetainFails() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [Data(repeating: 0x55, count: 16)])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let handle = gpu.makeHandle(width: 2, height: 2, pixelData: Data(repeating: 0x33, count: 16))

        _ = try runtime.applyLayerSurfaceMutation(
            index: 0,
            payload: GpuLayerMutationPayload.unsafeUnchecked(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                gpuBufferHandle: handle,
                fallbackPixelData: nil
            )
        ).get()

        gpu.setRetainSucceeds(false)

        let strokePlan = try runtime.makeStrokeCommitPlan(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0
        ).get()
        _ = runtime.strokeCommitResult(for: strokePlan)

        let fillPlan = try runtime.makeFillPlan(sample: sample(), brush: brush()).get()
        _ = runtime.fillPayload(for: fillPlan)

        let blurPlan = try runtime.makeBlurPlan(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0,
            captureTimelapse: false
        ).get()
        _ = runtime.blurPayload(for: blurPlan)

        #expect(gpu.retainedHandleValues.isEmpty)
        #expect(gpu.strokeBaseBufferHandleValues == [nil])
        #expect(gpu.fillSourceBufferHandleValues == [nil])
        #expect(gpu.blurSourceBufferHandleValues == [nil])
    }

    @Test
    func metadataUndoSnapshotMaterializesGpuBackedLayers() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let gpuPixels = Data(repeating: 0x66, count: 16)
        let handle = gpu.makeHandle(width: 2, height: 2, pixelData: gpuPixels)

        _ = try runtime.addLayer(name: "CPU").get()
        _ = try runtime.applyLayerSurfaceMutation(
            index: 0,
            payload: GpuLayerMutationPayload.unsafeUnchecked(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                gpuBufferHandle: handle,
                fallbackPixelData: nil
            )
        ).get()
        gpu.clearMaterializedHandles()

        _ = try runtime.setLayerName(index: 1, name: "Renamed").get()

        #expect(gpu.materializedHandleValues == [handle])

        gpu.clearMaterializedHandles()
        _ = try runtime.undo().get()

        #expect(gpu.materializedHandleValues == [handle])
        #expect(try runtime.pixelDataForLayer(index: 0).get() == gpuPixels)
    }

    @Test
    func planLeaseKeepsSourceBufferAliveDuringGpuMutation() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let handle = gpu.makeHandle(width: 2, height: 2, pixelData: Data(repeating: 0x77, count: 16))

        _ = try runtime.applyLayerSurfaceMutation(
            index: 0,
            payload: GpuLayerMutationPayload.unsafeUnchecked(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                gpuBufferHandle: handle,
                fallbackPixelData: nil
            )
        ).get()

        var plan: RuntimeFillPlan? = try runtime.makeFillPlan(sample: sample(), brush: brush()).get()
        runtime.release(handle)

        #expect(gpu.hasCachedPixelData(for: handle))
        _ = runtime.fillPayload(for: try #require(plan))
        #expect(gpu.fillSourceBufferHandleValues == [handle])

        plan = nil

        #expect(!gpu.hasCachedPixelData(for: handle))
    }

    @Test
    func staleStrokeGpuResultAfterUndoDoesNotApply() throws {
        let staleStrokePixels = Data(repeating: 0xEE, count: 16)
        let gpu = BlockingRuntimeGpuServiceSpy(operation: .stroke, stalePixelData: staleStrokePixels)
        let runtime = DocumentEngineFactory.live(gpuServices: gpu.services())
        let sample = sample()
        let brush = brush()

        _ = runtime.persistenceGateway.newCanvas(2, 2)
        _ = try runtime.mutationGateway.replaceLayerPixels(0, Data(repeating: 0x11, count: 16)).get()
        gpu.setBlockingEnabled(true)

        let staleResult = AsyncMutationResult {
            runtime.strokeGateway.applyGpuStrokeSurface([sample], brush, 0)
        }
        defer { gpu.releaseGpu() }
        try gpu.waitForGpuStart()
        _ = try runtime.historyGateway.undo().get()
        gpu.releaseGpu()

        guard case .failure(.gpu(.staleSnapshot(operation: "applyCommittedStroke"))) = try staleResult.wait() else {
            Issue.record("Expected stale stroke GPU result to be rejected")
            return
        }
        #expect(try runtime.renderGateway.pixelDataForLayer(0).get() == Data(count: 16))
        #expect(gpu.releasedHandleCount == 1)
    }

    @Test
    func staleFillGpuResultAfterNewCanvasDoesNotApplyAcrossGenerationReset() throws {
        let stalePixels = Data(repeating: 0xCC, count: 16)
        let gpu = BlockingRuntimeGpuServiceSpy(operation: .fill, stalePixelData: stalePixels)
        let runtime = DocumentEngineFactory.live(gpuServices: gpu.services())
        let sample = sample()
        let brush = brush()
        gpu.setBlockingEnabled(true)

        let staleResult = AsyncMutationResult {
            runtime.strokeGateway.fill(sample, brush)
        }
        defer { gpu.releaseGpu() }
        try gpu.waitForGpuStart()
        runtime.persistenceGateway.newCanvas(2, 2)
        gpu.releaseGpu()

        guard case .failure(.gpu(.staleSnapshot(operation: "fill"))) = try staleResult.wait() else {
            Issue.record("Expected stale fill GPU result to be rejected")
            return
        }
        #expect(try runtime.renderGateway.pixelDataForLayer(0).get() == Data(count: 16))
    }

    @Test
    func staleBlurGpuResultAfterNewCanvasDoesNotApplyAcrossGenerationReset() throws {
        let stalePixels = Data(repeating: 0xDD, count: 16)
        let gpu = BlockingRuntimeGpuServiceSpy(operation: .blur, stalePixelData: stalePixels)
        let runtime = DocumentEngineFactory.live(gpuServices: gpu.services())
        let sample = sample()
        let brush = brush()
        gpu.setBlockingEnabled(true)

        let staleResult = AsyncMutationResult {
            runtime.strokeGateway.blurStroke([sample], brush, 0, false)
        }
        defer { gpu.releaseGpu() }
        try gpu.waitForGpuStart()
        runtime.persistenceGateway.newCanvas(2, 2)
        gpu.releaseGpu()

        guard case .failure(.gpu(.staleSnapshot(operation: "blurStroke"))) = try staleResult.wait() else {
            Issue.record("Expected stale blur GPU result to be rejected")
            return
        }
        #expect(try runtime.renderGateway.pixelDataForLayer(0).get() == Data(count: 16))
    }

    @Test
    func strokeCoordinatorDoesNotClearNewStrokeWithOldSessionID() {
        var coordinator = StrokeCommitCoordinator()
        let firstSample = sample()
        let secondSample = StylusSample(
            point: CGPoint(x: 1.5, y: 1.5),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 1
        )

        coordinator.beginStroke(layerIndex: 0, sample: firstSample, brush: brush())
        let oldSessionID = coordinator.currentStrokePlanInput()?.id
        coordinator.beginStroke(layerIndex: 0, sample: secondSample, brush: brush())
        coordinator.clearCurrentStroke(id: oldSessionID)

        #expect(coordinator.currentStrokePlanInput()?.samples == [secondSample])
    }

    @Test
    func blurReservationRollbackDoesNotRestoreOverNewSession() throws {
        var coordinator = StrokeCommitCoordinator()
        let baseline = SwiftDocumentStore(width: 2, height: 2).snapshot
        let firstReservation = coordinator.beginOrAppendBlur(
            baseline: baseline,
            layerIndex: 0,
            brush: brush(),
            samples: [sample()]
        )
        coordinator.clearBlurStroke()
        let secondSample = StylusSample(
            point: CGPoint(x: 1.5, y: 1.5),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 1
        )
        _ = coordinator.beginOrAppendBlur(
            baseline: baseline,
            layerIndex: 0,
            brush: brush(),
            samples: [secondSample]
        )

        coordinator.rollbackBlurReservation(firstReservation)

        #expect(coordinator.blurStrokeState?.samples == [secondSample])
    }

    @Test
    func staleLayerProcessingGpuResultAfterNewCanvasDoesNotApplyAcrossGenerationReset() throws {
        let stalePixels = Data(repeating: 0xBB, count: 16)
        let gpu = BlockingRuntimeGpuServiceSpy(operation: .layerProcessing, stalePixelData: stalePixels)
        let runtime = DocumentEngineFactory.live(gpuServices: gpu.services())
        gpu.setBlockingEnabled(true)

        let staleResult = AsyncMutationResult {
            runtime.mutationGateway.applyLayerProcessing(0, .luminanceToAlpha)
        }
        defer { gpu.releaseGpu() }
        try gpu.waitForGpuStart()
        runtime.persistenceGateway.newCanvas(2, 2)
        gpu.releaseGpu()

        guard case .failure(.gpu(.staleSnapshot(operation: "applyLayerProcessing"))) = try staleResult.wait() else {
            Issue.record("Expected stale layer processing GPU result to be rejected")
            return
        }
        #expect(try runtime.renderGateway.pixelDataForLayer(0).get() == Data(count: 16))
    }

    @Test
    func staleDirectGpuPlansAfterLayerMutationDoNotApply() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [Data(repeating: 0xEE, count: 16)])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let layerPayload = DocumentLayerMutationPayload.unsafeUnchecked(
            canvasWidth: 2,
            canvasHeight: 2,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
            gpuBufferHandle: nil,
            rectPixelData: Data(repeating: 0xBB, count: 16),
            fullPixelData: Data(repeating: 0xBB, count: 16)
        )

        let processingPlan = try runtime.makeLayerProcessingPlan(index: 0, request: .luminanceToAlpha).get()
        _ = try runtime.setLayerName(index: 0, name: "Layer mutation").get()
        guard case .failure(.gpu(.staleSnapshot(operation: "applyLayerProcessing"))) =
            runtime.applyLayerProcessingPlan(processingPlan, payload: layerPayload)
        else {
            Issue.record("Expected stale layer processing plan to be rejected after layer mutation")
            return
        }

        let blurPlan = try runtime.makeBlurPlan(
            samples: [sample()],
            brush: brush(),
            layerIndex: 0,
            captureTimelapse: false
        ).get()
        _ = try runtime.setLayerVisibility(index: 0, isVisible: false).get()
        guard case .failure(.gpu(.staleSnapshot(operation: "blurStroke"))) =
            runtime.applyBlurPlan(blurPlan, payload: layerPayload)
        else {
            Issue.record("Expected stale blur plan to be rejected after layer mutation")
            return
        }

        #expect(try runtime.pixelDataForLayer(index: 0).get() == Data(count: 16))
    }

    @Test
    func staleResizeGpuResultAfterNewCanvasDoesNotApplyAcrossGenerationReset() throws {
        let gpu = BlockingRuntimeGpuServiceSpy(operation: .resize, stalePixelData: Data(repeating: 0xAA, count: 36))
        let runtime = DocumentEngineFactory.live(gpuServices: gpu.services())
        gpu.setBlockingEnabled(true)

        let staleResult = AsyncMutationResult {
            runtime.mutationGateway.resizeCanvas(3, 3)
        }
        defer { gpu.releaseGpu() }
        try gpu.waitForGpuStart()
        runtime.persistenceGateway.newCanvas(2, 2)
        gpu.releaseGpu()

        guard case .failure(.gpu(.staleSnapshot(operation: "resizeCanvas"))) = try staleResult.wait() else {
            Issue.record("Expected stale resize GPU result to be rejected")
            return
        }
        let presentation = try runtime.queryGateway.lightweightPresentation().get()
        #expect(presentation.canvasSize.width == 2)
        #expect(presentation.canvasSize.height == 2)
        #expect(try runtime.renderGateway.pixelDataForLayer(0).get() == Data(count: 16))
    }

    private func sample() -> StylusSample {
        StylusSample(
            point: CGPoint(x: 1, y: 1),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 0
        )
    }

    private func brush() -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .ink,
            radius: 1,
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
    }
}

private final class BlockingRuntimeGpuServiceSpy: @unchecked Sendable {
    enum Operation {
        case stroke
        case fill
        case blur
        case layerProcessing
        case resize
    }

    private let lock = NSLock()
    private let operation: Operation
    private let stalePixelData: Data
    private let started = DispatchSemaphore(value: 0)
    private let release = DispatchSemaphore(value: 0)
    private var shouldBlock = false
    private var releasedHandles = 0

    init(operation: Operation, stalePixelData: Data) {
        self.operation = operation
        self.stalePixelData = stalePixelData
    }

    var releasedHandleCount: Int {
        lock.withLock { releasedHandles }
    }

    func setBlockingEnabled(_ value: Bool) {
        lock.withLock {
            shouldBlock = value
        }
    }

    func waitForGpuStart() throws {
        guard started.wait(timeout: .now() + 10) == .success else {
            throw BlockingGpuTimeout()
        }
    }

    func releaseGpu() {
        release.signal()
    }

    func services() -> DocumentRuntimeGpuServices {
        DocumentRuntimeGpuServices(
            release: { handle in
                guard handle != nil else { return }
                self.lock.withLock {
                    self.releasedHandles += 1
                }
            },
            retain: { _ in false },
            _materializedPixelData: { _ in nil },
            _scaledPixelData: { data, sourceWidth, sourceHeight, targetWidth, targetHeight in
                self.blockIfNeeded(.resize)
                guard sourceWidth > 0, sourceHeight > 0, targetWidth > 0, targetHeight > 0 else { return nil }
                return self.stalePixelData.count == targetWidth * targetHeight * 4
                    ? self.stalePixelData
                    : data
            },
            _scaledMaskData: { data, _, _, _, _ in data },
            _translatedPixelData: { data, _, _, _, _, _, _ in data },
            _translatedMaskData: { data, _, _, _, _, _, _ in data },
            _applyLayerMask: { pixelData, _, _, _ in pixelData },
            _processLayer: { _, width, height, _ in
                self.blockIfNeeded(.layerProcessing)
                return self.payload(width: width, height: height)
            },
            _mergeLayers: { lower, _, _, _, _, _, _ in lower },
            _rasterizeTextLayer: { _, size in
                let width = Int(size.width)
                let height = Int(size.height)
                return self.payload(width: width, height: height)
            },
            _blurPixels: { _, _, width, height, _, _ in
                self.blockIfNeeded(.blur)
                return self.payload(width: width, height: height)
            },
            _fillPixels: { _, _, width, height, _, _ in
                self.blockIfNeeded(.fill)
                return self.payload(width: width, height: height)
            },
            _commitStrokeMutation: { _, _, width, height, _, _, _, _ in
                self.blockIfNeeded(.stroke)
                let handle = MetalBufferHandle.unsafeUnchecked(width: width, height: height, bytesPerRow: width * 4)
                return PrimoMetalStrokeMutationResult(
                    dirtyRect: (originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: handle,
                    rectPixelData: nil
                )
            },
            _preservingExistingAlphaBufferHandle: { sourceHandle, _, _, _, _ in sourceHandle },
            _compositedPaperPreviewRGBA: { pixelData, _, _, _ in pixelData },
            _compositedIncrementalUpdate: { _, dirtyRect in
                IncrementalLayerUpdate.unsafeUnchecked(
                    layerIndex: -1,
                    originX: dirtyRect.originX,
                    originY: dirtyRect.originY,
                    width: dirtyRect.width,
                    height: dirtyRect.height,
                    pixelData: Data(count: dirtyRect.width * dirtyRect.height * 4)
                )
            },
            _compositeDocumentSurface: { snapshot in
                DocumentCompositeSurface(
                    unsafeUncheckedWidth: snapshot.width,
                    height: snapshot.height,
                    pixelData: snapshot.layers.first?.pixelData ?? Data()
                )
            },
            _compositeDocumentBufferHandle: { _ in nil }
        )
    }

    private func blockIfNeeded(_ currentOperation: Operation) {
        guard currentOperation == operation else { return }
        let shouldWait = lock.withLock { shouldBlock }
        guard shouldWait else { return }
        started.signal()
        release.wait()
    }

    private func payload(width: Int, height: Int) -> DocumentLayerMutationPayload {
        DocumentLayerMutationPayload.unsafeUnchecked(
            canvasWidth: width,
            canvasHeight: height,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
            gpuBufferHandle: nil,
            rectPixelData: stalePixelData,
            fullPixelData: stalePixelData
        )
    }
}

private struct BlockingGpuTimeout: Error {}

private final class AsyncMutationResult: @unchecked Sendable {
    private let lock = NSLock()
    private let finished = DispatchSemaphore(value: 0)
    private var result: DocumentMutationResult?

    init(_ operation: @escaping @Sendable () -> DocumentMutationResult) {
        DispatchQueue.global().async {
            let result = operation()
            self.lock.withLock {
                self.result = result
            }
            self.finished.signal()
        }
    }

    func wait() throws -> DocumentMutationResult {
        guard finished.wait(timeout: .now() + 10) == .success else {
            throw BlockingGpuTimeout()
        }
        return try #require(lock.withLock { result })
    }
}

private final class RuntimeGpuServiceSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var strokeOutputs: [Data]
    private var blurOutputs: [Data]
    private let blurReturnsNil: Bool
    private var pixelDataByHandle: [MetalBufferHandle: Data] = [:]
    private var referenceCountByHandle: [MetalBufferHandle: Int] = [:]
    private var retainedHandles: [MetalBufferHandle] = []
    private var strokeBaseBufferHandles: [MetalBufferHandle?] = []
    private var fillSourceBufferHandles: [MetalBufferHandle?] = []
    private var blurSourceBufferHandles: [MetalBufferHandle?] = []
    private var materializedHandles: [MetalBufferHandle] = []
    private var retainSucceeds = true

    init(strokeOutputs: [Data], blurOutputs: [Data] = [], blurReturnsNil: Bool = false) {
        self.strokeOutputs = strokeOutputs
        self.blurOutputs = blurOutputs
        self.blurReturnsNil = blurReturnsNil
    }

    func makeHandle(width: Int, height: Int, pixelData: Data) -> MetalBufferHandle {
        lock.withLock {
            let handle = MetalBufferHandle.unsafeUnchecked(width: width, height: height, bytesPerRow: width * 4)
            pixelDataByHandle[handle] = pixelData
            referenceCountByHandle[handle] = 1
            return handle
        }
    }

    var retainedHandleValues: [MetalBufferHandle] {
        lock.withLock { retainedHandles }
    }

    var strokeBaseBufferHandleValues: [MetalBufferHandle?] {
        lock.withLock { strokeBaseBufferHandles }
    }

    var fillSourceBufferHandleValues: [MetalBufferHandle?] {
        lock.withLock { fillSourceBufferHandles }
    }

    var blurSourceBufferHandleValues: [MetalBufferHandle?] {
        lock.withLock { blurSourceBufferHandles }
    }

    var materializedHandleValues: [MetalBufferHandle] {
        lock.withLock { materializedHandles }
    }

    func setRetainSucceeds(_ value: Bool) {
        lock.withLock {
            retainSucceeds = value
        }
    }

    func clearMaterializedHandles() {
        lock.withLock {
            materializedHandles.removeAll(keepingCapacity: true)
        }
    }

    func hasCachedPixelData(for handle: MetalBufferHandle) -> Bool {
        lock.withLock {
            pixelDataByHandle[handle] != nil
        }
    }

    func services() -> DocumentRuntimeGpuServices {
        DocumentRuntimeGpuServices(
            release: { handle in
                guard let handle else { return }
                self.lock.withLock {
                    let nextCount = (self.referenceCountByHandle[handle] ?? 0) - 1
                    if nextCount <= 0 {
                        self.referenceCountByHandle.removeValue(forKey: handle)
                        self.pixelDataByHandle.removeValue(forKey: handle)
                    } else {
                        self.referenceCountByHandle[handle] = nextCount
                    }
                }
            },
            retain: { handle in
                guard let handle else { return false }
                return self.lock.withLock {
                    guard self.retainSucceeds,
                          let count = self.referenceCountByHandle[handle]
                    else {
                        return false
                    }
                    self.retainedHandles.append(handle)
                    self.referenceCountByHandle[handle] = count + 1
                    return true
                }
            },
            _materializedPixelData: { handle in
                self.lock.withLock {
                    self.materializedHandles.append(handle)
                    return self.pixelDataByHandle[handle]
                }
            },
            _scaledPixelData: { data, _, _, _, _ in data },
            _scaledMaskData: { data, _, _, _, _ in data },
            _translatedPixelData: { data, _, _, _, _, _, _ in data },
            _translatedMaskData: { data, _, _, _, _, _, _ in data },
            _applyLayerMask: { pixelData, _, _, _ in pixelData },
            _processLayer: { pixelData, width, height, _ in
                DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _mergeLayers: { lower, _, _, _, _, _, _ in lower },
            _rasterizeTextLayer: { _, size in
                let width = Int(size.width)
                let height = Int(size.height)
                let pixelData = Data(count: width * height * 4)
                return DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _blurPixels: { pixelData, sourceBufferHandle, width, height, _, _ in
                self.lock.withLock {
                    self.blurSourceBufferHandles.append(sourceBufferHandle)
                }
                guard !self.blurReturnsNil else { return nil }
                let output = self.nextBlurPixelData() ?? pixelData
                return DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: output,
                    fullPixelData: output
                )
            },
            _fillPixels: { pixelData, sourceBufferHandle, width, height, _, _ in
                self.lock.withLock {
                    self.fillSourceBufferHandles.append(sourceBufferHandle)
                }
                return DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _commitStrokeMutation: { _, baseBufferHandle, width, height, _, _, _, _ in
                self.lock.withLock {
                    self.strokeBaseBufferHandles.append(baseBufferHandle)
                }
                return self.nextStrokeResult(width: width, height: height)
            },
            _preservingExistingAlphaBufferHandle: { sourceHandle, _, _, _, _ in sourceHandle },
            _compositedPaperPreviewRGBA: { pixelData, _, _, _ in pixelData },
            _compositedIncrementalUpdate: { _, dirtyRect in
                IncrementalLayerUpdate.unsafeUnchecked(
                    layerIndex: -1,
                    originX: dirtyRect.originX,
                    originY: dirtyRect.originY,
                    width: dirtyRect.width,
                    height: dirtyRect.height,
                    pixelData: Data(count: dirtyRect.width * dirtyRect.height * 4)
                )
            },
            _compositeDocumentSurface: { snapshot in
                DocumentCompositeSurface(
                    unsafeUncheckedWidth: snapshot.width,
                    height: snapshot.height,
                    pixelData: snapshot.layers.first?.pixelData ?? Data()
                )
            },
            _compositeDocumentBufferHandle: { _ in nil }
        )
    }

    private func nextStrokeResult(width: Int, height: Int) -> PrimoMetalStrokeMutationResult? {
        lock.withLock {
            guard !strokeOutputs.isEmpty else { return nil }
            let pixelData = strokeOutputs.removeFirst()
            let handle = MetalBufferHandle.unsafeUnchecked(width: width, height: height, bytesPerRow: width * 4)
            pixelDataByHandle[handle] = pixelData
            referenceCountByHandle[handle] = 1
            return PrimoMetalStrokeMutationResult(
                dirtyRect: (originX: 0, originY: 0, width: width, height: height),
                gpuBufferHandle: handle,
                rectPixelData: nil
            )
        }
    }

    private func nextBlurPixelData() -> Data? {
        lock.withLock {
            guard !blurOutputs.isEmpty else { return nil }
            return blurOutputs.removeFirst()
        }
    }
}
