import Foundation
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure

public struct MetalSurfaceResourceGateway: Sendable {
    private let resourceStore: MetalResourceStore
    private let processingClient: PrimoMetalDocumentProcessingClient

    public init(
        resourceStore: MetalResourceStore = MetalResourceStore(),
        processingClient: PrimoMetalDocumentProcessingClient = .shared
    ) {
        self.resourceStore = resourceStore
        self.processingClient = processingClient
    }

    public func release(_ handle: GpuSurfaceHandle?) {
        guard let handle else { return }
        resourceStore.release(handle.buffer)
    }

    public func materializedSurface(_ request: MaterializedSurfaceRequest) -> MaterializedSurfaceResult? {
        guard let fullPixelData = processingClient.materializedPixelData(for: request.handle.buffer) else {
            return nil
        }
        if let region = request.region {
            guard let regionPixelData = Self.pixelData(
                in: region,
                from: fullPixelData,
                surfaceWidth: request.handle.buffer.width,
                surfaceHeight: request.handle.buffer.height
            ) else {
                return nil
            }
            return MaterializedSurfaceResult(
                width: region.width,
                height: region.height,
                pixelData: regionPixelData
            )
        }
        return MaterializedSurfaceResult(
            width: request.handle.buffer.width,
            height: request.handle.buffer.height,
            pixelData: fullPixelData
        )
    }

    private static func pixelData(
        in region: GpuSurfaceRegion,
        from pixelData: Data,
        surfaceWidth: Int,
        surfaceHeight: Int
    ) -> Data? {
        guard !region.isEmpty else { return Data() }
        guard region.originX >= 0, region.originY >= 0 else { return nil }
        guard region.originX + region.width <= surfaceWidth else { return nil }
        guard region.originY + region.height <= surfaceHeight else { return nil }
        guard pixelData.count == surfaceWidth * surfaceHeight * 4 else { return nil }

        var regionData = Data(count: region.width * region.height * 4)
        regionData.withUnsafeMutableBytes { destinationBytes in
            pixelData.withUnsafeBytes { sourceBytes in
                guard
                    let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else {
                    return
                }
                for row in 0..<region.height {
                    let sourceOffset = ((region.originY + row) * surfaceWidth + region.originX) * 4
                    let destinationOffset = row * region.width * 4
                    memcpy(destination + destinationOffset, source + sourceOffset, region.width * 4)
                }
            }
        }
        return regionData
    }
}
