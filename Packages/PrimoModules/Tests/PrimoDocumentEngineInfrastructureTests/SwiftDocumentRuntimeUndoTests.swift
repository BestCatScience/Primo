import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct SwiftDocumentRuntimeUndoTests {
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

        #expect(runtime.pixelDataForLayer(index: 0) == firstStrokePixels)
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
            payload: GpuLayerMutationPayload(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
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
        #expect(data == runtime.pixelDataForLayer(index: 0))
    }

    @Test
    func gpuBackedStrokeFillAndBlurPlansPassRetainedSourceHandles() throws {
        let gpu = RuntimeGpuServiceSpy(strokeOutputs: [Data(repeating: 0x55, count: 16)])
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: gpu.services())
        let handle = gpu.makeHandle(width: 2, height: 2, pixelData: Data(repeating: 0x33, count: 16))

        _ = try runtime.applyLayerSurfaceMutation(
            index: 0,
            payload: GpuLayerMutationPayload(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
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
            payload: GpuLayerMutationPayload(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
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
            payload: GpuLayerMutationPayload(
                canvasWidth: 2,
                canvasHeight: 2,
                dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
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
        #expect(runtime.pixelDataForLayer(index: 0) == gpuPixels)
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

private final class RuntimeGpuServiceSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var strokeOutputs: [Data]
    private var pixelDataByHandle: [MetalBufferHandle: Data] = [:]
    private var retainedHandles: [MetalBufferHandle] = []
    private var strokeBaseBufferHandles: [MetalBufferHandle?] = []
    private var fillSourceBufferHandles: [MetalBufferHandle?] = []
    private var blurSourceBufferHandles: [MetalBufferHandle?] = []
    private var materializedHandles: [MetalBufferHandle] = []
    private var retainSucceeds = true

    init(strokeOutputs: [Data]) {
        self.strokeOutputs = strokeOutputs
    }

    func makeHandle(width: Int, height: Int, pixelData: Data) -> MetalBufferHandle {
        lock.withLock {
            let handle = MetalBufferHandle(width: width, height: height, bytesPerRow: width * 4)
            pixelDataByHandle[handle] = pixelData
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

    func services() -> DocumentRuntimeGpuServices {
        DocumentRuntimeGpuServices(
            release: { handle in
                guard let handle else { return }
                self.lock.withLock {
                    _ = self.pixelDataByHandle.removeValue(forKey: handle)
                }
            },
            retain: { handle in
                guard let handle else { return false }
                return self.lock.withLock {
                    guard self.retainSucceeds else { return false }
                    self.retainedHandles.append(handle)
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
                DocumentLayerMutationPayload(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: width, height: height),
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
                return DocumentLayerMutationPayload(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _blurPixels: { pixelData, sourceBufferHandle, width, height, _, _ in
                self.lock.withLock {
                    self.blurSourceBufferHandles.append(sourceBufferHandle)
                }
                return DocumentLayerMutationPayload(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _fillPixels: { pixelData, sourceBufferHandle, width, height, _, _ in
                self.lock.withLock {
                    self.fillSourceBufferHandles.append(sourceBufferHandle)
                }
                return DocumentLayerMutationPayload(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: width, height: height),
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
                IncrementalLayerUpdate(
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
                    width: snapshot.width,
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
            let handle = MetalBufferHandle(width: width, height: height, bytesPerRow: width * 4)
            pixelDataByHandle[handle] = pixelData
            return PrimoMetalStrokeMutationResult(
                dirtyRect: (originX: 0, originY: 0, width: width, height: height),
                gpuBufferHandle: handle,
                rectPixelData: nil
            )
        }
    }
}
