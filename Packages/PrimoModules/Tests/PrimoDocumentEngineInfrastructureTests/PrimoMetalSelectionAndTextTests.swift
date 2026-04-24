import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import Testing

struct PrimoMetalSelectionAndTextTests {
    @Test
    func lassoSelectionBuildsNonEmptyMask() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let mask = client.lassoSelection(
            points: [
                CGPoint(x: 1, y: 1),
                CGPoint(x: 6, y: 1),
                CGPoint(x: 3, y: 6),
                CGPoint(x: 1, y: 1),
            ],
            canvasWidth: 8,
            canvasHeight: 8
        )

        if client.isAvailable {
            let resolved = try #require(mask)
            #expect(resolved.count == 64)
            #expect(resolved.contains(where: { $0 != 0 }))
        } else {
            #expect(mask == nil)
        }
    }

    @Test
    func autoSelectionSelectsContiguousRegion() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let red: [UInt8] = [255, 0, 0, 255]
        let blue: [UInt8] = [0, 0, 255, 255]
        let bytes = red + red + blue + red + red + blue + red + red + blue
        let pixels = Data(bytes)

        let mask = client.autoSelection(
            pixelData: pixels,
            canvasWidth: 3,
            canvasHeight: 3,
            seedX: 0,
            seedY: 1,
            thresholdMode: .color,
            opacityTolerance: 0,
            colorTolerance: 0,
            expansion: 0
        )

        if client.isAvailable {
            let resolved = try #require(mask)
            #expect(resolved.filter { $0 != 0 }.count == 6)
            #expect(resolved[2] == 0)
            #expect(resolved[5] == 0)
            #expect(resolved[8] == 0)
        } else {
            #expect(mask == nil)
        }
    }

    @Test
    func directRasterizeTextLayerProducesPixelsForMultilineRotation() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let payload = client.rasterizeTextLayer(
            TextLayerData(
                text: "GPU\nTEXT",
                positionX: 6,
                positionY: 8,
                fontPostScriptName: "Helvetica",
                fontDisplayName: "Helvetica",
                fontSize: 14,
                scale: 1.25,
                rotationDegrees: 18,
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1
            ),
            canvasSize: CGSize(width: 80, height: 80)
        )

        if client.isAvailable {
            #expect(payload != nil)
            #expect(payload?.fullPixelData?.count == 80 * 80 * 4)
            #expect((payload?.dirtyRect.width ?? 0) > 0)
            #expect((payload?.dirtyRect.height ?? 0) > 0)
        } else {
            #expect(payload == nil)
        }
    }

    @Test
    func directTextLayoutRectProducesRotatedBounds() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let rect = client.textLayoutRect(
            for: TextLayerData(
                text: "HELLO WORLD",
                positionX: 4,
                positionY: 6,
                fontPostScriptName: "Helvetica",
                fontDisplayName: "Helvetica",
                fontSize: 12,
                scale: 1.4,
                rotationDegrees: 22,
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1
            ),
            canvasSize: CGSize(width: 96, height: 96)
        )

        #expect(rect != nil)
        #expect((rect?.width ?? 0) > 0)
        #expect((rect?.height ?? 0) > 0)
    }

    @Test
    func directInpaintCropPayloadProducesExpectedCrop() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let source = Data([
            1, 2, 3, 255, 11, 12, 13, 255, 21, 22, 23, 255,
            31, 32, 33, 255, 41, 42, 43, 255, 51, 52, 53, 255,
            61, 62, 63, 255, 71, 72, 73, 255, 81, 82, 83, 255,
        ])
        let mask: [UInt8] = [
            0, 0, 0,
            0, 255, 0,
            0, 0, 0,
        ]

        let payload = client.inpaintCropPayload(
            source: source,
            canvasWidth: 3,
            canvasHeight: 3,
            selectionBounds: CGRect(x: 1, y: 1, width: 1, height: 1),
            expandedMask: mask,
            padding: 1
        )

        if client.isAvailable {
            let resolved = try #require(payload)
            #expect(resolved.width == 3)
            #expect(resolved.height == 3)
            #expect(resolved.originX == 0)
            #expect(resolved.originY == 0)
            #expect(resolved.pixelData == source)
            #expect(resolved.selectionMask == mask)
        } else {
            #expect(payload == nil)
        }
    }

    @Test
    func directExpandedSelectionMaskPlacesCroppedMaskIntoCanvas() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let maskData = Data([
            0, 255,
            255, 0,
        ])

        let expanded = client.expandedSelectionMask(
            maskData: maskData,
            maskWidth: 2,
            maskHeight: 2,
            originX: 1,
            originY: 1,
            canvasWidth: 4,
            canvasHeight: 4
        )

        if client.isAvailable {
            let resolved = try #require(expanded)
            #expect(resolved == [
                0, 0, 0, 0,
                0, 0, 255, 0,
                0, 255, 0, 0,
                0, 0, 0, 0,
            ])
        } else {
            #expect(expanded == nil)
        }
    }

    @Test
    func directCombinedSelectionMaskSupportsAddAndSubtract() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let base: [UInt8] = [
            0, 255, 0, 0,
            0, 255, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
        ]
        let incoming: [UInt8] = [
            0, 0, 0, 0,
            0, 255, 255, 0,
            0, 0, 255, 0,
            0, 0, 0, 0,
        ]

        let added = client.combinedSelectionMask(
            base: base,
            incoming: incoming,
            mode: .add,
            width: 4,
            height: 4
        )
        let subtracted = client.combinedSelectionMask(
            base: base,
            incoming: incoming,
            mode: .subtract,
            width: 4,
            height: 4
        )

        if client.isAvailable {
            let addedResolved = try #require(added)
            let subtractedResolved = try #require(subtracted)
            #expect(addedResolved == [
                0, 255, 0, 0,
                0, 255, 255, 0,
                0, 0, 255, 0,
                0, 0, 0, 0,
            ])
            #expect(subtractedResolved == [
                0, 255, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
            ])
        } else {
            #expect(added == nil)
            #expect(subtracted == nil)
        }
    }

    @Test
    func directAlphaPreserveRetainsExistingAlphaAndZeroesTransparentPixels() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let source = Data([
            200, 210, 220, 255,
            50, 60, 70, 255,
        ])
        let existing = Data([
            10, 20, 30, 128,
            40, 50, 60, 0,
        ])

        let preserved = client.preservingExistingAlpha(
            source: source,
            existing: existing,
            width: 2,
            height: 1
        )

        if client.isAvailable {
            #expect(preserved == Data([
                200, 210, 220, 128,
                0, 0, 0, 0,
            ]))
        } else {
            #expect(preserved == nil)
        }
    }
}
