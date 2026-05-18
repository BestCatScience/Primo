import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

struct GpuLayerRepository: Sendable {
    enum TextLayerUpdate: Sendable {
        case unchanged
        case set(TextLayerData?)
    }

    private var handles: [Int: MetalBufferHandle] = [:]

    func handle(for index: Int) -> MetalBufferHandle? {
        handles[index]
    }

    func materializedSnapshot(
        from snapshot: SwiftDocumentStoreSnapshot,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> Result<SwiftDocumentStoreSnapshot, DocumentMutationFailure> {
        var snapshot = snapshot
        guard let geometry = snapshot.pixelGeometry else {
            return .success(snapshot)
        }
        for index in handles.keys where snapshot.layers.indices.contains(index) {
            let pixelData: Data
            switch strictCurrentPixelData(
                for: index,
                in: snapshot,
                rgbaByteCount: rgbaByteCount,
                services: services
            ) {
            case let .success(data):
                pixelData = data
            case let .failure(failure):
                return .failure(failure)
            }
            guard snapshot.layers[index].replacePixelData(pixelData, geometry: geometry) else {
                return .failure(.gpu(.resourceHandleInvalid))
            }
        }
        return .success(snapshot)
    }

    func strictCurrentPixelData(
        for index: Int,
        in snapshot: SwiftDocumentStoreSnapshot,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> Result<Data, DocumentMutationFailure> {
        guard snapshot.layers.indices.contains(index) else { return .failure(.invalidLayerIndex(index)) }
        guard snapshot.layers[index].pixelDataAuthority == .staleGpuBacked else {
            return .success(snapshot.layers[index].pixelData)
        }
        guard let handle = handles[index],
              let pixelData = services.materializedPixelData(for: handle),
              pixelData.count == rgbaByteCount else {
            return .failure(.gpu(.resourceHandleInvalid))
        }
        return .success(pixelData)
    }

    func bestEffortCurrentPixelData(
        for index: Int,
        in snapshot: SwiftDocumentStoreSnapshot,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> Data {
        switch strictCurrentPixelData(
            for: index,
            in: snapshot,
            rgbaByteCount: rgbaByteCount,
            services: services
        ) {
        case let .success(pixelData):
            return pixelData
        case .failure:
            guard snapshot.layers.indices.contains(index) else { return Data() }
            return snapshot.layers[index].pixelData
        }
    }

    mutating func materializeGpuBackedLayerPixels(
        in store: SwiftDocumentStore,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> DocumentMutationResult {
        guard store.update({ snapshot in
            guard let geometry = snapshot.pixelGeometry else {
                return false
            }
            for index in handles.keys where snapshot.layers.indices.contains(index) {
                let pixelData: Data
                switch strictCurrentPixelData(
                    for: index,
                    in: snapshot,
                    rgbaByteCount: rgbaByteCount,
                    services: services
                ) {
                case let .success(data):
                    pixelData = data
                case .failure:
                    return false
                }
                guard snapshot.layers[index].replacePixelData(pixelData, geometry: geometry) else {
                    return false
                }
            }
            return true
        }) else {
            return .failure(.gpu(.resourceHandleInvalid))
        }
        return .success(())
    }

    @discardableResult
    mutating func setLayerPixelState(
        index: Int,
        pixelData: Data,
        gpuBufferHandle: MetalBufferHandle?,
        textLayerUpdate: TextLayerUpdate = .unchanged,
        in store: SwiftDocumentStore,
        services: DocumentRuntimeGpuServices
    ) -> Bool {
        guard store.update({ snapshot in
            guard snapshot.layers.indices.contains(index),
                  let geometry = snapshot.pixelGeometry else {
                return false
            }
            guard snapshot.layers[index].replacePixelData(pixelData, geometry: geometry) else {
                return false
            }
            if gpuBufferHandle != nil {
                snapshot.layers[index].markPixelDataStaleGpuBacked()
            }
            switch textLayerUpdate {
            case .unchanged:
                break
            case let .set(textLayer):
                snapshot.layers[index].textLayer = textLayer
            }
            return true
        }) else {
            services.release(gpuBufferHandle)
            return false
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
        return true
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
