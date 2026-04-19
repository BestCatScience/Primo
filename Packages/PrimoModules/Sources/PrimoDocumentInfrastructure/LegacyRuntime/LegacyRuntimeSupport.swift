import Foundation
import os
import PrimoBrushDomain
import PrimoBrushFileFormats
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentNativeBridge

public typealias DateClient = PrimoCoreTypes.DateClient
public typealias UUIDClient = PrimoCoreTypes.UUIDClient
public typealias FileClient = PrimoCoreTypes.FileClient

public typealias DocumentMutationResult = PrimoDocumentContracts.DocumentMutationResult
public typealias DocumentIndexedMutationResult = PrimoDocumentContracts.DocumentIndexedMutationResult
public typealias DocumentMutationFailure = PrimoDocumentContracts.DocumentMutationFailure
public typealias BrushRuntimeSettings = PrimoDocumentContracts.BrushRuntimeSettings
public typealias FillThresholdMode = PrimoDocumentContracts.FillThresholdMode
public typealias LayerProcessingRequest = PrimoDocumentContracts.LayerProcessingRequest
public typealias StylusSample = PrimoDocumentContracts.StylusSample
public typealias IncrementalLayerUpdate = PrimoDocumentContracts.IncrementalLayerUpdate
public typealias PaintDocumentPresentation = PrimoDocumentContracts.PaintDocumentPresentation
public typealias LoadedPaintProject = PrimoDocumentContracts.LoadedPaintProject
public typealias LayerRowModel = PrimoDocumentContracts.LayerRowModel
public typealias LayerFolderModel = PrimoDocumentContracts.LayerFolderModel
public typealias LayerSidebarRowModel = PrimoDocumentContracts.LayerSidebarRowModel
public typealias MetalLayerSnapshot = PrimoDocumentContracts.MetalLayerSnapshot
public typealias MetalDocumentSnapshot = PrimoDocumentContracts.MetalDocumentSnapshot
public typealias TimelapseFrame = PrimoDocumentContracts.TimelapseFrame
public typealias TimelapseOperation = PrimoDocumentContracts.TimelapseOperation
public typealias TimelapseCapture = PrimoDocumentContracts.TimelapseCapture

public typealias CanvasPaperStyle = PrimoDocumentDomain.CanvasPaperStyle
public typealias LayerBlendMode = PrimoDocumentDomain.LayerBlendMode
public typealias TextLayerData = PrimoDocumentDomain.TextLayerData
public typealias DocumentLayerIndex = PrimoDocumentDomain.DocumentLayerIndex
public typealias DocumentFolderID = PrimoDocumentDomain.DocumentFolderID
public typealias BrushTipKind = PrimoBrushDomain.BrushTipKind
public typealias BrushAngleMode = PrimoBrushDomain.BrushAngleMode
public typealias BrushTextureMode = PrimoBrushDomain.BrushTextureMode
public typealias BrushDualBlendMode = PrimoBrushDomain.BrushDualBlendMode
public typealias BrushScatterMode = PrimoBrushDomain.BrushScatterMode
public typealias BrushColorMixingMode = PrimoBrushDomain.BrushColorMixingMode
public typealias BrushTipRaster = PrimoBrushFileFormats.BrushTipRaster
typealias APPaintDocumentBridge = PrimoDocumentNativeBridge.APPaintDocumentBridge
typealias APBrushDescriptor = PrimoDocumentNativeBridge.APBrushDescriptor
typealias APStrokePoint = PrimoDocumentNativeBridge.APStrokePoint
typealias APPaintLayerInfo = PrimoDocumentNativeBridge.APPaintLayerInfo
typealias APPaintFolderInfo = PrimoDocumentNativeBridge.APPaintFolderInfo
typealias APPaintLayerProcessingDescriptor = PrimoDocumentNativeBridge.APPaintLayerProcessingDescriptor
typealias APPaintLayerProcessingKind = PrimoDocumentNativeBridge.APPaintLayerProcessingKind
typealias APPaintGradientMapPreset = PrimoDocumentNativeBridge.APPaintGradientMapPreset
typealias APDirtyRect = PrimoDocumentNativeBridge.APDirtyRect

extension APPaintDocumentBridge: @retroactive @unchecked Sendable {}

enum DocumentInfrastructureDiagnostics {
    static let isVerboseLoggingEnabled: Bool = {
        let environment = ProcessInfo.processInfo.environment
        guard let rawValue = environment["PRIMO_VERBOSE_LOGGING"] else {
            return false
        }
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on"
    }()

    static func debug(_ logger: Logger, _ message: String) {
        guard isVerboseLoggingEnabled else { return }
        logger.debug("\(message)")
    }
}
