import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentPersistenceContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct PaintDocumentMutationContractTests {
    @Test
    func adjustmentValueObjectsValidateBounds() throws {
        #expect(ThresholdValue(0)?.rawValue == 0)
        #expect(ThresholdValue(1)?.rawValue == 1)
        #expect(ThresholdValue(-0.01) == nil)
        #expect(ThresholdValue(.nan) == nil)
        #expect(ThresholdSettings(threshold: .infinity).threshold == 0.5)
        #expect(ThresholdSettings(threshold: -4).threshold == 0)
        #expect(ThresholdSettings(threshold: 4).threshold == 1)

        #expect(GradientStopPosition(0)?.rawValue == 0)
        #expect(GradientStopPosition(1)?.rawValue == 1)
        #expect(GradientStopPosition(1.01) == nil)
        #expect(GradientStopPosition(.infinity) == nil)
        #expect(GradientMapStopSettings(position: .nan, red: 1, green: 2, blue: 3).position == 0)
        #expect(GradientMapStopSettings(position: 2, red: 1, green: 2, blue: 3).position == 1)
        #expect(GradientMapStopSettings(position: 0.25, red: 1, green: 2, blue: 3).red == 1)
        #expect(GradientMapStopSettings(position: 0.25, red: 1, green: 2, blue: 3).green == 2)
        #expect(GradientMapStopSettings(position: 0.25, red: 1, green: 2, blue: 3).blue == 3)
        let typedStop = GradientMapStopSettings(
            position: 0.25,
            color: CanvasColor(
                red: UnitInterval(0.25)!,
                green: UnitInterval(0.5)!,
                blue: UnitInterval(0.75)!,
                alpha: UnitInterval(0.25)!
            )
        )
        #expect(typedStop.colorValue.red.rawValue == 0.25)
        #expect(typedStop.colorValue.green.rawValue == 0.5)
        #expect(typedStop.colorValue.blue.rawValue == 0.75)
        #expect(typedStop.colorValue.alpha.rawValue == 1)

        #expect(ToneCurveSettings(shadows: -2, midtones: .nan, highlights: 2).shadows == -1)
        #expect(ToneCurveSettings(shadows: -2, midtones: .nan, highlights: 2).midtones == 0)
        #expect(ToneCurveSettings(shadows: -2, midtones: .nan, highlights: 2).highlights == 1)
        #expect(ColorBalanceSettings(redCyan: -2, greenMagenta: .nan, blueYellow: 2).redCyan == -1)
        #expect(ColorBalanceSettings(redCyan: -2, greenMagenta: .nan, blueYellow: 2).greenMagenta == 0)
        #expect(ColorBalanceSettings(redCyan: -2, greenMagenta: .nan, blueYellow: 2).blueYellow == 1)
    }

    @Test
    func posterizeSettingsStoreValidatedLevelCount() throws {
        #expect(PosterizeLevels(1) == nil)
        #expect(PosterizeLevels(2)?.rawValue == 2)
        #expect(PosterizeLevels(256)?.rawValue == 256)
        #expect(PosterizeLevels(257) == nil)
        #expect(PosterizeLevels(rounding: .infinity) == nil)
        #expect(PosterizeLevelCount(2)?.rawValue == 2)
        #expect(PosterizeSettings(levels: -8).levelsValue.rawValue == 2)
        #expect(PosterizeSettings(levels: 6.4).levelsValue.rawValue == 6)
        #expect(PosterizeSettings(levels: .nan).levelsValue.rawValue == 6)
        #expect(PosterizeSettings(levels: 999).levelsValue.rawValue == 256)
    }

    @Test
    func redoRejectsMissingHistory() throws {
        let runtime = DocumentEngineFactory.live()
        #expect(try runtime.historyGateway.canRedo().get() == false)
        expectFailure(runtime.historyGateway.redo(), .noRedoState)
    }

    @Test
    func layerRenameIsUndoable() throws {
        let runtime = DocumentEngineFactory.live()

        expectSuccess(runtime.mutationGateway.setLayerName(0, "Ink"))
        #expect(try runtime.queryGateway.lightweightPresentation().get().layerRows.first?.name == "Ink")

        expectSuccess(runtime.historyGateway.undo())
        #expect(try runtime.queryGateway.lightweightPresentation().get().layerRows.first?.name == "Layer 1")

        expectSuccess(runtime.historyGateway.redo())
        #expect(try runtime.queryGateway.lightweightPresentation().get().layerRows.first?.name == "Ink")
    }

    @Test
    func folderRenameAndExpandedStateAreUndoable() throws {
        let runtime = DocumentEngineFactory.live()
        let folderID = try #require(createdFolderID(in: runtime, name: "Group"))

        expectSuccess(runtime.setFolderName(folderID, "References"))
        #expect(folder(in: runtime, id: folderID)?.name == "References")

        expectSuccess(runtime.historyGateway.undo())
        #expect(folder(in: runtime, id: folderID)?.name == "Group")

        expectSuccess(runtime.historyGateway.redo())
        #expect(folder(in: runtime, id: folderID)?.name == "References")

        expectSuccess(runtime.setFolderExpanded(folderID, false))
        #expect(folder(in: runtime, id: folderID)?.isExpanded == false)

        expectSuccess(runtime.historyGateway.undo())
        #expect(folder(in: runtime, id: folderID)?.isExpanded == true)
    }

    @Test
    func renameStatePersistsAcrossSaveAndLoad() throws {
        let runtime = DocumentEngineFactory.live()
        let folderID = try #require(createdFolderID(in: runtime, name: "Group"))
        let projectURL = temporaryProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        expectSuccess(runtime.mutationGateway.setLayerName(0, "Ink"))
        expectSuccess(runtime.setFolderName(folderID, "References"))
        try runtime.persistenceGateway.saveProject(projectURL, .default)

        let loaded = DocumentEngineFactory.live()
        _ = try loaded.persistenceGateway.loadProject(projectURL)

        #expect(try loaded.queryGateway.lightweightPresentation().get().layerRows.first?.name == "Ink")
        #expect(folder(in: loaded, id: folderID)?.name == "References")
    }

    @Test
    func renameAndFolderExpandedAreCapturedAsTimelapseOperations() throws {
        let runtime = DocumentEngineFactory.live()
        let folderID = try #require(createdFolderID(in: runtime, name: "Group"))

        expectSuccess(runtime.mutationGateway.setLayerName(0, "Ink"))
        expectSuccess(runtime.setFolderName(folderID, "References"))
        expectSuccess(runtime.setFolderExpanded(folderID, false))

        guard case let .operations(operations) = try runtime.exportGateway.timelapseCapture().get()?.source else {
            Issue.record("Expected operation-backed timelapse capture")
            return
        }

        #expect(operations.contains(.setLayerName(index: .unchecked(0), name: "Ink")))
        #expect(operations.contains(.setFolderName(folderID: .unchecked(folderID), name: "References")))
        #expect(operations.contains(.setFolderExpanded(folderID: .unchecked(folderID), isExpanded: false)))
    }

    @Test
    func renameTimelapseOperationsRoundTripThroughStoredRepresentation() throws {
        let operations: [TimelapseOperation] = [
            .setLayerName(index: .unchecked(0), name: "Ink"),
            .setFolderName(folderID: .unchecked(2), name: "References"),
            .setFolderExpanded(folderID: .unchecked(2), isExpanded: false),
            .mergeLayerDown(index: .unchecked(1)),
        ]

        let decoded = try operations.enumerated().map { index, operation in
            try TimelapseOperation(
                stored: operation.storedRepresentation(
                    index: index,
                    dataDirectory: temporaryProjectURL()
                ),
                baseURL: URL(fileURLWithPath: "/tmp")
            )
        }

        #expect(decoded == operations)
    }

    @Test
    func setActiveLayerRejectsInvalidLayerIndex() {
        let runtime = DocumentEngineFactory.live()
        expectFailure(runtime.mutationGateway.setActiveLayer(99), .invalidLayerIndex(99))
    }

    @Test
    func clearLayerRejectsLockedLayer() {
        let runtime = DocumentEngineFactory.live()
        expectSuccess(runtime.setLayerLocked(0, true))
        expectFailure(runtime.mutationGateway.clearLayer(0), .layerLocked(0))
    }

    @Test
    func setLayerOpacityRejectsInvalidOpacity() {
        let runtime = DocumentEngineFactory.live()
        expectFailure(runtime.setLayerOpacity(0, 1.4), .invalidOpacity(1.4))
    }

    @Test
    func assignLayerRejectsInvalidFolderID() {
        let runtime = DocumentEngineFactory.live()
        switch runtime.makeEditingGateway().execute(.structure(.assignLayerToFolder(index: 0, folderID: 999))) {
        case let .failure(failure):
            #expect(failure == .invalidFolderID(999))
        case .success:
            Issue.record("Expected invalid folder failure")
        }
    }

    @Test
    func createFolderRejectsStaleLayerAnchorIndex() throws {
        let runtime = DocumentEngineFactory.live()
        let anchor = try #require(DocumentLayerMutationContext(
            layerCount: 1,
            folderIDs: [],
            isLayerLocked: { _ in false }
        ).anchorLayerIndex(0))

        _ = try runtime.mutationGateway.addLayer("Ink").get()
        let currentRevision = try runtime.queryGateway.lightweightPresentation().get().revision

        switch runtime.createFolder("Group", anchor) {
        case .success:
            Issue.record("Expected stale layer anchor failure")
        case let .failure(failure):
            #expect(failure == .staleLayerAnchor(
                anchorLayerIndex: anchor.rawValue,
                validationRevision: anchor.revision,
                currentRevision: currentRevision
            ))
        }
    }

    @Test
    func replaceLayerPixelsRejectsEmptyInput() {
        let runtime = DocumentEngineFactory.live()
        expectFailure(runtime.mutationGateway.replaceLayerPixels(0, Data()), .emptyInput)
    }

    @Test
    func replaceLayerPixelsInRectRejectsEmptyInput() {
        let runtime = DocumentEngineFactory.live()
        let rect = LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2)
        expectFailure(runtime.mutationGateway.replaceLayerPixelsInRect(0, rect, Data()), .emptyInput)
    }

    @Test
    func replaceLayerPixelsInRectRejectsMismatchedRectPayload() {
        let runtime = DocumentEngineFactory.live()
        let rect = LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2)
        expectFailure(
            runtime.mutationGateway.replaceLayerPixelsInRect(0, rect, Data(count: 4)),
            .gpu(.invalidPayloadSize(
                operation: "replaceLayerPixelsInRect",
                expected: 16,
                actual: 4
            ))
        )
    }

    @Test
    func applyLayerMaskUsesGpuMutationPath() throws {
        let runtime = DocumentEngineFactory.live()
        let presentation = try runtime.queryGateway.lightweightPresentation().get()
        let width = max(Int(presentation.canvasSize.width.rounded()), 1)
        let height = max(Int(presentation.canvasSize.height.rounded()), 1)
        var pixelBytes = [UInt8](repeating: 0, count: width * height * 4)
        pixelBytes[0] = 10
        pixelBytes[1] = 20
        pixelBytes[2] = 30
        pixelBytes[3] = 255
        let pixelData = Data(pixelBytes)
        var maskBytes = [UInt8](repeating: 0, count: width * height)
        maskBytes[0] = 128
        let maskData = Data(maskBytes)
        expectSuccess(runtime.mutationGateway.replaceLayerPixels(0, pixelData))
        expectSuccess(runtime.mutationGateway.replaceLayerMask(0, maskData))

        let result = runtime.mutationGateway.applyLayerMask(0)

        if PrimoMetalDocumentProcessingClient.shared.isAvailable {
            expectSuccess(result)
            let output = try runtime.renderGateway.pixelDataForLayer(0).get()
            #expect(output.count == width * height * 4)
            #expect(output[0] == 10)
            #expect(output[1] == 20)
            #expect(output[2] == 30)
            #expect(output[3] == 128)
        } else {
            expectFailure(result, .gpu(.kernelFailed(operation: "applyLayerMask")))
        }
    }

    @Test
    func mergeLayerDownUsesGpuMutationPath() throws {
        let runtime = DocumentEngineFactory.live()
        let presentation = try runtime.queryGateway.lightweightPresentation().get()
        let width = max(Int(presentation.canvasSize.width.rounded()), 1)
        let height = max(Int(presentation.canvasSize.height.rounded()), 1)
        var lowerBytes = [UInt8](repeating: 0, count: width * height * 4)
        lowerBytes[0] = 255
        lowerBytes[3] = 255
        var upperBytes = [UInt8](repeating: 0, count: width * height * 4)
        upperBytes[2] = 255
        upperBytes[3] = 255
        let lower = Data(lowerBytes)
        let upper = Data(upperBytes)

        expectSuccess(runtime.mutationGateway.replaceLayerPixels(0, lower))
        switch runtime.mutationGateway.addLayer("Upper") {
        case let .success(index):
            expectSuccess(runtime.mutationGateway.replaceLayerPixels(index.rawValue, upper))
            let result = runtime.mergeLayerDown(index.rawValue)
            if PrimoMetalDocumentProcessingClient.shared.isAvailable {
                expectSuccess(result)
                let merged = try runtime.renderGateway.pixelDataForLayer(0).get()
                #expect(merged.count == width * height * 4)
                #expect(merged[2] == 255)
            } else {
                expectFailure(result, .bridgeMutationFailed("mergeLayerDown"))
            }
        case let .failure(failure):
            Issue.record("Expected addLayer success, got \(String(describing: failure))")
        }
    }

    @Test
    func mergeLayerDownRecordsSingleTimelapseOperation() throws {
        guard PrimoMetalDocumentProcessingClient.shared.isAvailable else { return }
        let runtime = DocumentEngineFactory.live()
        let presentation = try runtime.queryGateway.lightweightPresentation().get()
        let width = max(Int(presentation.canvasSize.width.rounded()), 1)
        let height = max(Int(presentation.canvasSize.height.rounded()), 1)
        let lower = Data(repeating: 0x20, count: width * height * 4)
        let upper = Data(repeating: 0x80, count: width * height * 4)

        expectSuccess(runtime.mutationGateway.replaceLayerPixels(0, lower))
        let upperIndex: Int
        switch runtime.mutationGateway.addLayer("Upper") {
        case let .success(index):
            upperIndex = index.rawValue
        case let .failure(failure):
            Issue.record("Expected addLayer success, got \(String(describing: failure))")
            return
        }
        expectSuccess(runtime.mutationGateway.replaceLayerPixels(upperIndex, upper))
        guard case let .operations(beforeOperations) = try runtime.exportGateway.timelapseCapture().get()?.source else {
            Issue.record("Expected operation-backed timelapse capture")
            return
        }

        expectSuccess(runtime.mergeLayerDown(upperIndex))

        guard case let .operations(afterOperations) = try runtime.exportGateway.timelapseCapture().get()?.source else {
            Issue.record("Expected operation-backed timelapse capture")
            return
        }
        let mergeOperations = Array(afterOperations.dropFirst(beforeOperations.count))
        #expect(mergeOperations == [.mergeLayerDown(index: .unchecked(upperIndex))])
        #expect(try runtime.queryGateway.lightweightPresentation().get().layerRows.count == 1)
    }

    @Test
    func compositeSurfaceUsesGpuQueryPath() throws {
        let runtime = DocumentEngineFactory.live()
        let presentation = try runtime.queryGateway.lightweightPresentation().get()
        let width = max(Int(presentation.canvasSize.width.rounded()), 1)
        let height = max(Int(presentation.canvasSize.height.rounded()), 1)

        let surface = try runtime.renderGateway.compositeSurface().get()

        #expect(surface.width == width)
        #expect(surface.height == height)
        #expect(surface.pixelData.count == width * height * 4)
    }

    @Test
    func renderSnapshotUsesSurfaceOnlyLayerThumbnails() throws {
        let runtime = DocumentEngineFactory.live()

        let presentation = try runtime.queryGateway.presentation().get()

        guard let snapshot = presentation.renderSnapshot else {
            Issue.record("Expected render snapshot")
            return
        }
        #expect(snapshot.layers.isEmpty == false)
        #expect(snapshot.layers.allSatisfy { $0.thumbnailData == nil })
        if PrimoMetalDocumentProcessingClient.shared.isAvailable {
            #expect(snapshot.layers.allSatisfy { $0.thumbnailSurface != nil })
        }
    }

    @Test
    func applyLayerProcessingUsesGpuMutationPath() {
        let runtime = DocumentEngineFactory.live()
        let result = runtime.mutationGateway.applyLayerProcessing(
            0,
            .brightnessContrast(.init(brightness: 0.1, contrast: 1.0))
        )

        if PrimoMetalDocumentProcessingClient.shared.isAvailable {
            expectSuccess(result)
        } else {
            expectFailure(result, .gpu(.kernelFailed(operation: "applyLayerProcessing")))
        }
    }

    @Test
    func fillUsesGpuMutationPath() {
        let runtime = DocumentEngineFactory.live()
        let brush = BrushRuntimeSettings(
            tipKind: .ink,
            radius: 4,
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
            smudgeEngineEnabled: false,
            smudgeMode: .smearing,
            smudgeLength: 0,
            colorRate: 1,
            pressureSensitivity: 1,
            red: 255,
            green: 0,
            blue: 0
        )
        let sample = StylusSample(point: .zero, pressure: 1, altitude: 0, azimuth: 0, timestamp: 0)
        let result = runtime.strokeGateway.fill(sample, brush)

        if PrimoMetalDocumentProcessingClient.shared.isAvailable {
            expectSuccess(result)
        } else {
            expectFailure(result, .gpu(.kernelFailed(operation: "fill")))
        }
    }

    @Test
    func setTextLayerUsesGpuMutationPath() throws {
        let runtime = DocumentEngineFactory.live()
        let textLayer = try #require(TextLayerData(
            validatingText: "GPU",
            positionX: 8,
            positionY: 8,
            fontPostScriptName: "Helvetica",
            fontDisplayName: "Helvetica",
            fontSize: 16,
            red: 1,
            green: 1,
            blue: 1,
            alpha: 1
        ))
        let result = runtime.textLayerGateway.setTextLayer(0, textLayer)

        if PrimoMetalDocumentProcessingClient.shared.isAvailable {
            expectSuccess(result)
        } else {
            expectFailure(result, .bridgeMutationFailed("setTextLayer"))
        }
    }

    @Test
    func directProcessLayerProducesFullCanvasPayload() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let pixelData = Data([128, 128, 128, 255])

        let payload = client.processLayer(
            pixelData: pixelData,
            canvasWidth: 1,
            canvasHeight: 1,
            request: .brightnessContrast(.init(brightness: 0.1, contrast: 1.0))
        )

        if client.isAvailable {
            #expect(payload != nil)
            #expect(payload?.fullPixelData?.count == 4)
            #expect(payload?.dirtyRect == LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 1, height: 1))
        } else {
            #expect(payload == nil)
        }
    }

    @Test
    func directBlurPixelsReturnsDirtyRectPayload() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let pixelData = Data(repeating: 0, count: 32 * 32 * 4)
        let brush = BrushRuntimeSettings(
            tipKind: .ink,
            radius: 4,
            opacity: 1,
            hardness: 0.8,
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
            smudgeEngineEnabled: false,
            smudgeMode: .smearing,
            smudgeLength: 0,
            colorRate: 1,
            pressureSensitivity: 1,
            red: 255,
            green: 255,
            blue: 255
        )
        let payload = client.blurPixels(
            pixelData: pixelData,
            canvasWidth: 32,
            canvasHeight: 32,
            samples: [StylusSample(point: CGPoint(x: 12, y: 10), pressure: 1, altitude: 0, azimuth: 0, timestamp: 0)],
            brush: brush
        )

        if client.isAvailable {
            #expect(payload != nil)
            #expect((payload?.dirtyRect.width ?? 0) > 0)
            #expect((payload?.rectPixelData.count ?? 0) > 0)
        } else {
            #expect(payload == nil)
        }
    }

    @Test
    func directRasterizeTextLayerProducesPayload() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let payload = client.rasterizeTextLayer(
            try #require(TextLayerData(
                validatingText: "Metal",
                positionX: 4,
                positionY: 4,
                fontPostScriptName: "Helvetica",
                fontDisplayName: "Helvetica",
                fontSize: 14,
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1
            )),
            canvasSize: CGSize(width: 32, height: 32)
        )

        if client.isAvailable {
            #expect(payload != nil)
            #expect(payload?.fullPixelData?.count == 32 * 32 * 4)
        } else {
            #expect(payload == nil)
        }
    }

    @Test
    func directTextLayoutRectProducesGeometry() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let rect = client.textLayoutRect(
            for: try #require(TextLayerData(
                validatingText: "Metal",
                positionX: 4,
                positionY: 6,
                fontPostScriptName: "Helvetica",
                fontDisplayName: "Helvetica",
                fontSize: 14,
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1
            )),
            canvasSize: CGSize(width: 64, height: 64)
        )

        #expect(rect != nil)
        #expect((rect?.width ?? 0) > 0)
        #expect((rect?.height ?? 0) > 0)
    }

    @Test
    func directScaledPixelDataProducesTargetSizedOutput() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let source = Data([
            255, 0, 0, 255,
            0, 255, 0, 255,
            0, 0, 255, 255,
            255, 255, 255, 255,
        ])

        let scaled = client.scaledPixelData(
            source,
            sourceWidth: 2,
            sourceHeight: 2,
            targetWidth: 4,
            targetHeight: 4
        )

        if client.isAvailable {
            #expect(scaled != nil)
            #expect(scaled?.count == 4 * 4 * 4)
        } else {
            #expect(scaled == nil)
        }
    }

    @Test
    func directTranslatedMaskDataProducesTargetSizedOutput() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let source = Data([
            255, 0,
            0, 128,
        ])

        let translated = client.translatedMaskData(
            source,
            sourceWidth: 2,
            sourceHeight: 2,
            targetWidth: 4,
            targetHeight: 4,
            offsetX: 1,
            offsetY: 1
        )

        if client.isAvailable {
            #expect(translated != nil)
            #expect(translated?.count == 16)
            #expect(translated?[5] == 255)
            #expect(translated?[10] == 128)
        } else {
            #expect(translated == nil)
        }
    }

    private func createdFolderID(in runtime: DocumentEngineLive, name: String) -> Int? {
        let anchor = DocumentLayerMutationContext(
            layerCount: 1,
            folderIDs: [],
            isLayerLocked: { _ in false }
        ).anchorLayerIndex(0)
        switch runtime.createFolder(name, anchor!) {
        case let .success(folderID):
            return folderID.rawValue
        case let .failure(failure):
            Issue.record("Expected folder creation success, got \(String(describing: failure))")
            return nil
        }
    }

    private func folder(in runtime: DocumentEngineLive, id: Int) -> LayerFolderModel? {
        guard case let .success(presentation) = runtime.queryGateway.lightweightPresentation() else {
            return nil
        }
        return presentation.layerSidebarRows.compactMap { row in
            if case let .folder(folder) = row, folder.id == id {
                return folder
            }
            return nil
        }.first
    }

    private func temporaryProjectURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PrimoMutationContractTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func expectSuccess(_ result: DocumentMutationResult) {
        switch result {
        case .success:
            #expect(Bool(true))
        case let .failure(failure):
            Issue.record("Expected success, got \(String(describing: failure))")
        }
    }

    private func expectFailure(_ result: DocumentMutationResult, _ expected: DocumentMutationFailure) {
        switch result {
        case .success:
            Issue.record("Expected failure \(String(describing: expected)), got success")
        case let .failure(failure):
            #expect(failure == expected)
        }
    }
}
