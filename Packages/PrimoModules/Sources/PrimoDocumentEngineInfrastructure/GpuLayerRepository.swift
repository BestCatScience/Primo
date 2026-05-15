import Foundation
import PrimoDocumentApplication
import PrimoDocumentPresentationContracts

struct GpuLayerRepository: Sendable {
    private var handles: [Int: MetalBufferHandle] = [:]

    func handle(for index: Int) -> MetalBufferHandle? {
        handles[index]
    }

    func materializedSnapshot(
        from snapshot: SwiftDocumentStoreSnapshot,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> SwiftDocumentStoreSnapshot {
        var snapshot = snapshot
        guard let geometry = snapshot.pixelGeometry else {
            return snapshot
        }
        for index in handles.keys where snapshot.layers.indices.contains(index) {
            snapshot.layers[index].replacePixelData(currentPixelData(
                for: index,
                in: snapshot,
                rgbaByteCount: rgbaByteCount,
                services: services
            ), geometry: geometry)
        }
        return snapshot
    }

    func currentPixelData(
        for index: Int,
        in snapshot: SwiftDocumentStoreSnapshot,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> Data {
        guard snapshot.layers.indices.contains(index) else { return Data() }
        if let handle = handles[index],
           let pixelData = services.materializedPixelData(for: handle),
           pixelData.count == rgbaByteCount {
            return pixelData
        }
        return snapshot.layers[index].pixelData
    }

    mutating func materializeGpuBackedLayerPixels(
        in store: SwiftDocumentStore,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) {
        store.update { snapshot in
            guard let geometry = snapshot.pixelGeometry else {
                return false
            }
            for index in handles.keys where snapshot.layers.indices.contains(index) {
                guard snapshot.layers[index].replacePixelData(currentPixelData(
                    for: index,
                    in: snapshot,
                    rgbaByteCount: rgbaByteCount,
                    services: services
                ), geometry: geometry) else {
                    return false
                }
            }
            return true
        }
    }

    mutating func setLayerPixelState(
        index: Int,
        pixelData: Data,
        gpuBufferHandle: MetalBufferHandle?,
        in store: SwiftDocumentStore,
        services: DocumentRuntimeGpuServices
    ) {
        guard store.update({ snapshot in
            guard snapshot.layers.indices.contains(index),
                  let geometry = snapshot.pixelGeometry else {
                return false
            }
            return snapshot.layers[index].replacePixelData(pixelData, geometry: geometry)
        }) else {
            services.release(gpuBufferHandle)
            return
        }
        let previousHandle = handles[index]
        if let gpuBufferHandle {
            handles[index] = gpuBufferHandle
        } else {
            handles.removeValue(forKey: index)
        }
        if previousHandle != gpuBufferHandle {
            services.release(previousHandle)
        }
    }

    mutating func releaseLayerBufferHandles(services: DocumentRuntimeGpuServices) {
        for handle in handles.values {
            services.release(handle)
        }
        handles.removeAll(keepingCapacity: true)
    }

    func layerSourceForGpuPlan(
        index: Int,
        snapshot: SwiftDocumentStoreSnapshot,
        services: DocumentRuntimeGpuServices
    ) -> (
        pixelData: Data,
        bufferHandle: MetalBufferHandle?,
        retainedResource: GpuResourceLease?
    ) {
        guard snapshot.layers.indices.contains(index) else {
            return (Data(), nil, nil)
        }
        guard let handle = handles[index] else {
            return (snapshot.layers[index].pixelData, nil, nil)
        }
        guard let lease = GpuResourceLease(handle: handle, services: services) else {
            return (snapshot.layers[index].pixelData, nil, nil)
        }
        return (snapshot.layers[index].pixelData, handle, lease)
    }
}
