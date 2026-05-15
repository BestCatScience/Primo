import Foundation
import PrimoDocumentApplication
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

final class DirtyUpdatePublisher: @unchecked Sendable {
    private var pendingDirtyUpdate: IncrementalLayerUpdate?

    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
        defer { pendingDirtyUpdate = nil }
        return pendingDirtyUpdate
    }

    func captureDirtyUpdate(
        snapshot: SwiftDocumentStoreSnapshot,
        rect: LayerPixelRect?,
        gpuServices: DocumentRuntimeGpuServices,
        makeMetalSnapshot: (SwiftDocumentStoreSnapshot, Bool) -> MetalDocumentSnapshot,
        compositePixelData: (SwiftDocumentStoreSnapshot) -> Data
    ) {
        let rect = rect ?? LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: snapshot.canvasWidth, height: snapshot.canvasHeight)
        let metalSnapshot = makeMetalSnapshot(snapshot, false)
        if let dirtyUpdate = gpuServices.compositedIncrementalUpdate(
            snapshot: metalSnapshot,
            dirtyRect: (rect.originX, rect.originY, rect.width, rect.height)
        ) {
            setPendingDirtyUpdate(dirtyUpdate, gpuServices: gpuServices)
            return
        }
        let composite = compositePixelData(snapshot)
        let pixelData = crop(pixelData: composite, width: snapshot.canvasWidth, rect: rect)
        setPendingDirtyUpdate(IncrementalLayerUpdate.unsafeUnchecked(
            layerIndex: -1,
            originX: rect.originX,
            originY: rect.originY,
            width: rect.width,
            height: rect.height,
            pixelData: pixelData
        ), gpuServices: gpuServices)
    }

    private func setPendingDirtyUpdate(_ update: IncrementalLayerUpdate, gpuServices: DocumentRuntimeGpuServices) {
        if let previous = pendingDirtyUpdate?.gpuBufferHandle,
           previous != update.gpuBufferHandle {
            gpuServices.release(previous)
        }
        pendingDirtyUpdate = update
    }

    private func crop(pixelData: Data, width: Int, rect: LayerPixelRect) -> Data {
        guard rect.width > 0, rect.height > 0 else { return Data() }
        var output = Data(count: rect.width * rect.height * 4)
        output.withUnsafeMutableBytes { destinationBytes in
            pixelData.withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<rect.height {
                    let srcOffset = ((rect.originY + row) * width + rect.originX) * 4
                    let dstOffset = row * rect.width * 4
                    memcpy(destination + dstOffset, source + srcOffset, rect.width * 4)
                }
            }
        }
        return output
    }
}
