import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
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
    func lassoSelectionBuildsMaskForBothWindingDirections() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let clockwise = [
            CGPoint(x: 1, y: 1),
            CGPoint(x: 6, y: 1),
            CGPoint(x: 6, y: 6),
            CGPoint(x: 1, y: 6),
            CGPoint(x: 1, y: 1),
        ]
        let counterClockwise = Array(clockwise.reversed())

        let clockwiseMask = client.lassoSelection(
            points: clockwise,
            canvasWidth: 8,
            canvasHeight: 8
        )
        let counterClockwiseMask = client.lassoSelection(
            points: counterClockwise,
            canvasWidth: 8,
            canvasHeight: 8
        )

        if client.isAvailable {
            let resolvedClockwise = try #require(clockwiseMask)
            let resolvedCounterClockwise = try #require(counterClockwiseMask)
            #expect(resolvedClockwise.contains(where: { $0 != 0 }))
            #expect(resolvedCounterClockwise.contains(where: { $0 != 0 }))
            #expect(resolvedClockwise.filter { $0 != 0 }.count == resolvedCounterClockwise.filter { $0 != 0 }.count)
        } else {
            #expect(clockwiseMask == nil)
            #expect(counterClockwiseMask == nil)
        }
    }

    @Test
    func circularLassoBuildsNonEmptyMask() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let polygon = [
            CGPoint(x: 5, y: 4),
            CGPoint(x: 10, y: 2),
            CGPoint(x: 16, y: 4),
            CGPoint(x: 19, y: 10),
            CGPoint(x: 17, y: 17),
            CGPoint(x: 10, y: 20),
            CGPoint(x: 4, y: 17),
            CGPoint(x: 2, y: 10),
            CGPoint(x: 5, y: 4),
        ]

        let mask = client.lassoSelection(
            points: polygon,
            canvasWidth: 24,
            canvasHeight: 24
        )

        if client.isAvailable {
            let resolved = try #require(mask)
            #expect(polygon.first == polygon.last)
            #expect(resolved.count == 576)
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
    func directRasterizeTextLayerProducesPixelsForMultilineRotation() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let payload = client.rasterizeTextLayer(
            try #require(TextLayerData(
                validatingText: "GPU\nTEXT",
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
            )),
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
    func directTextLayoutRectProducesRotatedBounds() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let rect = client.textLayoutRect(
            for: try #require(TextLayerData(
                validatingText: "HELLO WORLD",
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
            )),
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
    func directQuadLayerTransformTranslatesOpaquePixels() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let transparent: [UInt8] = [0, 0, 0, 0]
        let red: [UInt8] = [255, 0, 0, 255]
        let pixels = Data(red + transparent + transparent)
        let quad = TransformQuad(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 2, y: 0),
            bottomLeft: CGPoint(x: 0, y: 0),
            bottomRight: CGPoint(x: 2, y: 0)
        )

        let output = client.transformedLayerPixelData(
            source: pixels,
            canvasWidth: 3,
            canvasHeight: 1,
            expandedSelectionMask: nil,
            translation: CGSize(width: 1, height: 0),
            scaleX: 1,
            scaleY: 1,
            rotationDegrees: 0,
            pivot: .zero,
            sourceQuad: quad,
            destinationQuad: quad,
            usesFreeformQuad: false
        )

        if client.isAvailable {
            let resolved = try #require(output)
            #expect(resolved == Data(transparent + red + transparent))
        } else {
            #expect(output == nil)
        }
    }

    @Test
    func directAlphaMaskExtractsOpaquePixels() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let pixels = Data([
            255, 0, 0, 255,
            0, 255, 0, 0,
            0, 0, 255, 128,
        ])

        let mask = client.alphaMask(pixelData: pixels, width: 3, height: 1)

        if client.isAvailable {
            #expect(mask == [255, 0, 255])
        } else {
            #expect(mask == nil)
        }
    }

    @Test
    func directQuadMaskTransformTranslatesSelection() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let quad = TransformQuad(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 2, y: 0),
            bottomLeft: CGPoint(x: 0, y: 0),
            bottomRight: CGPoint(x: 2, y: 0)
        )

        let output = client.transformedSelectionMask(
            expandedSelectionMask: [255, 0, 0],
            canvasWidth: 3,
            canvasHeight: 1,
            translation: CGSize(width: 1, height: 0),
            scaleX: 1,
            scaleY: 1,
            rotationDegrees: 0,
            pivot: .zero,
            sourceQuad: quad,
            destinationQuad: quad,
            usesFreeformQuad: false
        )

        if client.isAvailable {
            #expect(output == [0, 255, 0])
        } else {
            #expect(output == nil)
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
    func directCroppedSelectionMaskExtractsBoundsAndMaskData() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let mask: [UInt8] = [
            0, 0, 0, 0, 0,
            0, 255, 0, 0, 0,
            0, 0, 128, 255, 0,
            0, 0, 0, 0, 0,
        ]

        let cropped = client.croppedSelectionMask(mask: mask, width: 5, height: 4)

        if client.isAvailable {
            let resolved = try #require(cropped)
            #expect(resolved.bounds == CGRect(x: 1, y: 1, width: 3, height: 2))
            #expect(resolved.maskWidth == 3)
            #expect(resolved.maskHeight == 2)
            #expect(resolved.maskData == Data([
                255, 0, 0,
                0, 128, 255,
            ]))
        } else {
            #expect(cropped == nil)
        }
    }

    @Test
    func directCroppedSelectionMaskReturnsNilForEmptyMask() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let cropped = client.croppedSelectionMask(mask: [UInt8](repeating: 0, count: 12), width: 4, height: 3)

        #expect(cropped == nil)
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
