import CoreGraphics
import Foundation
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import Testing

struct DocumentDTOInvariantTests {
    @Test
    func unitIntervalAcceptsOnlyFiniteZeroThroughOne() {
        #expect(UnitInterval(0)?.rawValue == 0)
        #expect(UnitInterval(1)?.rawValue == 1)
        #expect(UnitInterval(0.5)?.rawValue == 0.5)
        #expect(UnitInterval(-0.001) == nil)
        #expect(UnitInterval(1.001) == nil)
        #expect(UnitInterval(.infinity) == nil)
        #expect(UnitInterval(.nan) == nil)
    }

    @Test
    func finiteScalarTypesRejectInvalidValues() {
        #expect(PositiveFiniteDouble(0) == nil)
        #expect(PositiveFiniteDouble(-1) == nil)
        #expect(PositiveFiniteDouble(.infinity) == nil)
        #expect(PositiveFiniteDouble(1)?.rawValue == 1)

        #expect(FiniteDouble(.nan) == nil)
        #expect(FiniteDouble(.infinity) == nil)
        #expect(FiniteDouble(-10)?.rawValue == -10)
    }

    @Test
    func canvasColorAndPaperStyleValidateChannels() {
        #expect(CanvasColor(red: 1, green: 0.5, blue: 0, alpha: 1) != nil)
        #expect(CanvasColor(red: -0.1, green: 0.5, blue: 0, alpha: 1) == nil)
        #expect(CanvasColor(red: 1, green: .infinity, blue: 0, alpha: 1) == nil)

        let invalidPaper = CanvasPaperStyle(validatingRed: 1, green: 1, blue: 1, alpha: -10, isTransparent: false)
        #expect(invalidPaper == nil)
        #expect(CanvasPaperStyle.default.validatedColor != nil)
    }

    @Test
    func textLayerDataExposesValidatedScalarsAndColor() throws {
        let positionX = try #require(FiniteDouble(10))
        let positionY = try #require(FiniteDouble(20))
        let fontSize = try #require(PositiveFiniteDouble(18))
        let scale = try #require(PositiveFiniteDouble(1))
        let rotationDegrees = try #require(FiniteDouble(0))
        let color = try #require(CanvasColor(red: 1, green: 0, blue: 0, alpha: 1))
        let text = try #require(TextContent("Hello"))
        let validTextLayer = try #require(TextLayerData(
            text: text,
            positionX: positionX,
            positionY: positionY,
            fontPostScriptName: "Helvetica",
            fontDisplayName: "Helvetica",
            fontSize: fontSize,
            scale: scale,
            rotationDegrees: rotationDegrees,
            color: color
        ))
        #expect(validTextLayer.validatedFontSize?.rawValue == 18)
        #expect(validTextLayer.validatedColor != nil)

        #expect(TextContent(String(repeating: "a", count: TextContent.maxLength + 1)) == nil)
        #expect(TextLayerData(
            validatingText: "Hello",
            positionX: .infinity,
            positionY: 20,
            fontPostScriptName: "Helvetica",
            fontDisplayName: "Helvetica",
            fontSize: -1,
            scale: 0,
            rotationDegrees: .nan,
            red: 2,
            green: 0,
            blue: 0,
            alpha: 1
        ) == nil)
    }

    @Test
    func layerRowRequiresValidatedIndexAndOpacity() throws {
        let halfOpacity = try #require(UnitInterval(0.5))
        let validLayer = try #require(LayerRowModel(
            validatingIndex: 0,
            name: "Layer",
            visible: true,
            opacity: halfOpacity,
            isLocked: false,
            isAlphaLocked: false,
            isClipped: false,
            blendMode: .normal,
            folderID: nil,
            hasMask: false,
            isTextLayer: false,
            textLayer: nil
        ))
        #expect(validLayer.opacity == 0.5)
        #expect(validLayer.validatedOpacity?.rawValue == 0.5)
        #expect(UnitInterval(2) == nil)
        let fullOpacity = try #require(UnitInterval(1))
        #expect(LayerRowModel(
            validatingIndex: -1,
            name: "Layer",
            visible: true,
            opacity: fullOpacity,
            isLocked: false,
            isAlphaLocked: false,
            isClipped: false,
            blendMode: .normal,
            folderID: nil,
            hasMask: false,
            isTextLayer: false,
            textLayer: nil
        ) == nil)
    }

    @Test
    func presentationValidationRejectsMissingActiveLayerAndSnapshotSizeMismatch() throws {
        let fullOpacity = try #require(UnitInterval(1))
        let layer = try #require(LayerRowModel(
            validatingIndex: 0,
            name: "Layer",
            visible: true,
            opacity: fullOpacity,
            isLocked: false,
            isAlphaLocked: false,
            isClipped: false,
            blendMode: .normal,
            folderID: nil,
            hasMask: false,
            isTextLayer: false,
            textLayer: nil
        ))
        let matchingSnapshot = try #require(MetalDocumentSnapshot(
            validatingWidth: 2,
            height: 2,
            revision: 1,
            compositePixelData: Data(count: 16),
            layers: []
        ))
        #expect(PaintDocumentPresentation(
            validatingCanvasSize: CGSize(width: 2, height: 2),
            activeLayerIndex: 0,
            layerRows: [layer],
            layerSidebarRows: [.layer(layer, depth: 0)],
            renderSnapshot: matchingSnapshot
        ) != nil)
        #expect(PaintDocumentPresentation(
            validatingCanvasSize: CGSize(width: 2, height: 2),
            activeLayerIndex: 1,
            layerRows: [layer],
            layerSidebarRows: [.layer(layer, depth: 0)],
            renderSnapshot: matchingSnapshot
        ) == nil)

        let mismatchedSnapshot = try #require(MetalDocumentSnapshot(
            validatingWidth: 3,
            height: 2,
            revision: 1,
            compositePixelData: Data(count: 24),
            layers: []
        ))
        #expect(PaintDocumentPresentation(
            validatingCanvasSize: CGSize(width: 2, height: 2),
            activeLayerIndex: 0,
            layerRows: [layer],
            layerSidebarRows: [.layer(layer, depth: 0)],
            renderSnapshot: mismatchedSnapshot
        ) == nil)
    }
}
