import Foundation
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain

struct LayerPixelBuffer: Equatable, Sendable {
    let surface: RgbaSurface

    init?(geometry: PixelGeometry, data: Data) {
        guard let surface = RgbaSurface(geometry: geometry, data: data) else {
            return nil
        }
        self.surface = surface
    }

    var data: Data { surface.data }
}

struct LayerMaskBuffer: Equatable, Sendable {
    let surface: MaskSurface

    init?(geometry: PixelGeometry, data: Data) {
        guard let surface = MaskSurface(geometry: geometry, data: data) else {
            return nil
        }
        self.surface = surface
    }

    var data: Data { surface.data }
}

struct DocumentLayerOpacity: Equatable, Sendable {
    let value: UnitInterval

    init?(_ rawValue: Double) {
        guard let value = UnitInterval(rawValue) else {
            return nil
        }
        self.value = value
    }

    var rawValue: Double { value.rawValue }
}

struct ActiveLayerRef: Equatable, Sendable {
    let index: DocumentLayerIndex

    init?(rawValue: Int, layerCount: Int) {
        guard layerCount > 0,
              rawValue >= 0,
              rawValue < layerCount,
              let index = try? DocumentLayerIndex(validating: rawValue) else {
            return nil
        }
        self.index = index
    }

    var rawValue: Int { index.rawValue }
}

struct NonEmptyLayerStack: Equatable, Sendable {
    let layers: [SwiftDocumentLayerRecord]
    let activeLayer: ActiveLayerRef

    init?(layers: [SwiftDocumentLayerRecord], activeLayerIndex: Int) {
        guard !layers.isEmpty,
              let activeLayer = ActiveLayerRef(rawValue: activeLayerIndex, layerCount: layers.count) else {
            return nil
        }
        self.layers = layers
        self.activeLayer = activeLayer
    }

    init?(clampingActiveLayer layers: [SwiftDocumentLayerRecord], activeLayerIndex: Int) {
        guard !layers.isEmpty else { return nil }
        let clampedIndex = min(max(activeLayerIndex, 0), layers.count - 1)
        self.init(layers: layers, activeLayerIndex: clampedIndex)
    }
}

struct SwiftDocumentLayerRecord: Equatable, Sendable {
    enum PixelDataAuthority: Equatable, Sendable {
        case authoritative
        case staleGpuBacked
    }

    var name: String
    var visible: Bool
    var locked: Bool
    var alphaLocked: Bool
    var clipped: Bool
    private var opacityStorage: DocumentLayerOpacity
    var blendMode: LayerBlendMode
    var folderID: Int?
    var textLayer: TextLayerData?
    private(set) var pixelData: Data
    private(set) var pixelDataAuthority: PixelDataAuthority
    private(set) var maskData: Data?

    var opacity: Double {
        opacityStorage.rawValue
    }

    init?(
        name: String,
        visible: Bool,
        locked: Bool,
        alphaLocked: Bool,
        clipped: Bool,
        opacity: Double,
        blendMode: LayerBlendMode,
        folderID: Int?,
        textLayer: TextLayerData?,
        geometry: PixelGeometry,
        pixelData: Data,
        maskData: Data?
    ) {
        guard let opacity = DocumentLayerOpacity(opacity),
              let pixels = LayerPixelBuffer(geometry: geometry, data: pixelData) else {
            return nil
        }
        let mask: LayerMaskBuffer?
        if let maskData {
            guard let validatedMask = LayerMaskBuffer(geometry: geometry, data: maskData) else {
                return nil
            }
            mask = validatedMask
        } else {
            mask = nil
        }
        self.init(
            uncheckedName: name,
            visible: visible,
            locked: locked,
            alphaLocked: alphaLocked,
            clipped: clipped,
            opacity: opacity,
            blendMode: blendMode,
            folderID: folderID,
            textLayer: textLayer,
            pixelBuffer: pixels,
            maskBuffer: mask
        )
    }

    private init(
        uncheckedName name: String,
        visible: Bool,
        locked: Bool,
        alphaLocked: Bool,
        clipped: Bool,
        opacity: DocumentLayerOpacity,
        blendMode: LayerBlendMode,
        folderID: Int?,
        textLayer: TextLayerData?,
        pixelBuffer: LayerPixelBuffer,
        maskBuffer: LayerMaskBuffer?
    ) {
        self.name = name
        self.visible = visible
        self.locked = locked
        self.alphaLocked = alphaLocked
        self.clipped = clipped
        self.opacityStorage = opacity
        self.blendMode = blendMode
        self.folderID = folderID
        self.textLayer = textLayer
        self.pixelData = pixelBuffer.data
        self.pixelDataAuthority = .authoritative
        self.maskData = maskBuffer?.data
    }

    @discardableResult
    mutating func setOpacity(_ rawValue: Double) -> Bool {
        guard let opacity = DocumentLayerOpacity(rawValue) else {
            return false
        }
        opacityStorage = opacity
        return true
    }

    @discardableResult
    mutating func replacePixelData(_ data: Data, geometry: PixelGeometry) -> Bool {
        guard let pixelBuffer = LayerPixelBuffer(geometry: geometry, data: data) else {
            return false
        }
        pixelData = pixelBuffer.data
        pixelDataAuthority = .authoritative
        return true
    }

    mutating func markPixelDataStaleGpuBacked() {
        pixelDataAuthority = .staleGpuBacked
    }

    @discardableResult
    mutating func replaceMaskData(_ data: Data?, geometry: PixelGeometry) -> Bool {
        guard let data else {
            maskData = nil
            return true
        }
        guard let maskBuffer = LayerMaskBuffer(geometry: geometry, data: data) else {
            return false
        }
        maskData = maskBuffer.data
        return true
    }
}

struct SwiftDocumentFolderRecord: Equatable, Sendable {
    var id: Int
    var name: String
    var visible: Bool
    var expanded: Bool
    var anchorLayerIndex: Int?

    init(
        id: Int,
        name: String,
        visible: Bool,
        expanded: Bool,
        anchorLayerIndex: Int?
    ) {
        self.id = id
        self.name = name
        self.visible = visible
        self.expanded = expanded
        self.anchorLayerIndex = anchorLayerIndex
    }
}

struct SwiftDocumentStoreSnapshot: Equatable, Sendable {
    private var geometryStorage: PixelGeometry
    private var layerStackStorage: NonEmptyLayerStack
    private var revisionStorage: Int
    private var nextFolderIDStorage: Int
    var paperStyle: CanvasPaperStyle
    var folders: [SwiftDocumentFolderRecord]
    var thumbnailCache: [Int: Data]
    var timelapseFrames: [TimelapseFrame]
    var timelapseEvents: [TimelapseOperation]
    var timelapseUsesOperationPersistence: Bool

    var canvasWidth: Int {
        geometryStorage.width
    }

    var canvasHeight: Int {
        geometryStorage.height
    }

    var activeLayerIndex: Int {
        get { layerStackStorage.activeLayer.rawValue }
        set {
            _ = setActiveLayerIndex(newValue)
        }
    }

    var revision: Int {
        get { revisionStorage }
        set {
            _ = setRevision(newValue)
        }
    }

    var nextFolderID: Int {
        get { nextFolderIDStorage }
        set {
            _ = setNextFolderID(newValue)
        }
    }

    var layers: [SwiftDocumentLayerRecord] {
        get { layerStackStorage.layers }
        set {
            _ = replaceLayers(newValue)
        }
    }

    mutating func setActiveLayerIndex(_ newValue: Int) -> Bool {
        guard let stack = NonEmptyLayerStack(
            layers: layerStackStorage.layers,
            activeLayerIndex: newValue
        ) else {
            return false
        }
        layerStackStorage = stack
        return true
    }

    mutating func setRevision(_ newValue: Int) -> Bool {
        guard newValue >= 0 else { return false }
        revisionStorage = newValue
        return true
    }

    mutating func setNextFolderID(_ newValue: Int) -> Bool {
        guard newValue >= 0 else { return false }
        nextFolderIDStorage = newValue
        return true
    }

    mutating func replaceLayers(_ newValue: [SwiftDocumentLayerRecord]) -> Bool {
        guard newValue.allSatisfy({ $0.isValid(for: geometryStorage) }),
              let stack = NonEmptyLayerStack(
                clampingActiveLayer: newValue,
                activeLayerIndex: layerStackStorage.activeLayer.rawValue
              ) else {
            return false
        }
        layerStackStorage = stack
        return true
    }

    init?(
        canvasWidth: Int,
        canvasHeight: Int,
        activeLayerIndex: Int,
        paperStyle: CanvasPaperStyle,
        revision: Int,
        nextFolderID: Int,
        layers: [SwiftDocumentLayerRecord],
        folders: [SwiftDocumentFolderRecord],
        thumbnailCache: [Int: Data],
        timelapseFrames: [TimelapseFrame],
        timelapseEvents: [TimelapseOperation],
        timelapseUsesOperationPersistence: Bool
    ) {
        guard let geometry = PixelGeometry(width: canvasWidth, height: canvasHeight),
              revision >= 0,
              nextFolderID >= 0,
              let layerStack = NonEmptyLayerStack(layers: layers, activeLayerIndex: activeLayerIndex),
              layers.allSatisfy({ $0.isValid(for: geometry) }) else {
            return nil
        }
        self.geometryStorage = geometry
        self.layerStackStorage = layerStack
        self.revisionStorage = revision
        self.nextFolderIDStorage = nextFolderID
        self.paperStyle = paperStyle
        self.folders = folders
        self.thumbnailCache = thumbnailCache
        self.timelapseFrames = timelapseFrames
        self.timelapseEvents = timelapseEvents
        self.timelapseUsesOperationPersistence = timelapseUsesOperationPersistence
    }

    var pixelGeometry: PixelGeometry? {
        geometryStorage
    }

    var activeLayerRef: ActiveLayerRef? {
        ActiveLayerRef(rawValue: activeLayerIndex, layerCount: layers.count)
    }

    func validated() -> SwiftDocumentStoreSnapshot? {
        SwiftDocumentStoreSnapshot(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            activeLayerIndex: activeLayerIndex,
            paperStyle: paperStyle,
            revision: revision,
            nextFolderID: nextFolderID,
            layers: layers,
            folders: folders,
            thumbnailCache: thumbnailCache,
            timelapseFrames: timelapseFrames,
            timelapseEvents: timelapseEvents,
            timelapseUsesOperationPersistence: timelapseUsesOperationPersistence
        )
    }
}

extension SwiftDocumentLayerRecord {
    func validatedOpacity() -> DocumentLayerOpacity? {
        DocumentLayerOpacity(opacity)
    }

    func pixelBuffer(for geometry: PixelGeometry) -> LayerPixelBuffer? {
        LayerPixelBuffer(geometry: geometry, data: pixelData)
    }

    func maskBuffer(for geometry: PixelGeometry) -> LayerMaskBuffer? {
        guard let maskData else { return nil }
        return LayerMaskBuffer(geometry: geometry, data: maskData)
    }

    func isValid(for geometry: PixelGeometry) -> Bool {
        validatedOpacity() != nil &&
            pixelBuffer(for: geometry) != nil &&
            (maskData == nil || maskBuffer(for: geometry) != nil)
    }
}

struct DocumentRectSnapshot: Equatable, Sendable {
    var layerIndex: Int
    var rect: LayerPixelRect
    var pixelData: Data

    init(layerIndex: Int, rect: LayerPixelRect, pixelData: Data) {
        self.layerIndex = layerIndex
        self.rect = rect
        self.pixelData = pixelData
    }
}

struct DocumentCommandRecord: Equatable, Sendable {
    var before: SwiftDocumentStoreSnapshot
    var after: SwiftDocumentStoreSnapshot
    var timelapseEvent: TimelapseOperation?

    init(
        before: SwiftDocumentStoreSnapshot,
        after: SwiftDocumentStoreSnapshot,
        timelapseEvent: TimelapseOperation? = nil
    ) {
        self.before = before
        self.after = after
        self.timelapseEvent = timelapseEvent
    }
}

/// @unchecked Sendable: the store is mutable runtime state and is only reached through `SwiftDocumentRuntime` behind `LockedDocumentRuntimeExecutor`.
/// Concurrency test: uncheckedSendableRuntimeCollaboratorsStayExecutorConfined
final class SwiftDocumentStore: @unchecked Sendable {
    var snapshot: SwiftDocumentStoreSnapshot

    init(
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle = .default
    ) {
        let clampedWidth = max(width, 1)
        let clampedHeight = max(height, 1)
        guard let geometry = PixelGeometry(width: clampedWidth, height: clampedHeight),
              let initialLayer = SwiftDocumentLayerRecord(
                name: "Layer 1",
                visible: true,
                locked: false,
                alphaLocked: false,
                clipped: false,
                opacity: 1.0,
                blendMode: .normal,
                folderID: nil,
                textLayer: nil,
                geometry: geometry,
                pixelData: Data(count: geometry.rgbaByteCount),
                maskData: nil
              ),
              let snapshot = SwiftDocumentStoreSnapshot(
            canvasWidth: clampedWidth,
            canvasHeight: clampedHeight,
            activeLayerIndex: 0,
            paperStyle: paperStyle,
            revision: 0,
            nextFolderID: 1,
            layers: [
                initialLayer
            ],
            folders: [],
            thumbnailCache: [:],
            timelapseFrames: [],
            timelapseEvents: [],
            timelapseUsesOperationPersistence: true
              ) else {
            preconditionFailure("SwiftDocumentStore failed to create a valid initial snapshot")
        }
        self.snapshot = snapshot
    }

    @discardableResult
    func restore(_ snapshot: SwiftDocumentStoreSnapshot) -> Bool {
        guard let validatedSnapshot = snapshot.validated() else {
            return false
        }
        self.snapshot = validatedSnapshot
        return true
    }

    @discardableResult
    func update(_ mutation: (inout SwiftDocumentStoreSnapshot) -> Bool) -> Bool {
        var nextSnapshot = snapshot
        guard mutation(&nextSnapshot),
              let validatedSnapshot = nextSnapshot.validated() else {
            return false
        }
        snapshot = validatedSnapshot
        return true
    }

    func validatedSnapshot() -> SwiftDocumentStoreSnapshot {
        guard let validatedSnapshot = snapshot.validated() else {
            preconditionFailure("SwiftDocumentStore snapshot invariant was violated")
        }
        return validatedSnapshot
    }
}
