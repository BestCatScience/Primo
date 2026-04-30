import CoreGraphics
import Foundation
import PrimoBrushFileFormats
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMetalStrokeInfrastructure
import Testing
@testable import PrimoDocumentRenderingInfrastructure

private let metalRuntimeAvailable = PrimoMetalDocumentProcessingClient.shared.isAvailable

struct DocumentGpuOperationGatewayTests {
    @Test
    func metalBackendFactoryInjectsProvidedBackendIntoDependentServices() throws {
        let repoRoot = try Self.repoRoot()
        let factorySource = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/MetalDocumentGpuOperationBackendFactory.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: factorySource, encoding: .utf8)

        #expect(body.contains("MetalLayerMutationService(client: backend)"))
        #expect(body.contains("MetalResourceStore(client: backend)"))
        #expect(body.contains("MetalOverlayExecutor(client: backend)"))
        #expect(body.contains("MetalTextService(client: backend)"))
        #expect(!body.contains("let layerMutationService = MetalLayerMutationService()"))
        #expect(!body.contains("let resourceStore = MetalResourceStore()"))
        #expect(!body.contains("let overlayService = GpuOverlayRenderingService()"))
        #expect(!body.contains("let textService = MetalTextService()"))
    }

    @Test
    func metalBackendTextLayerSurfaceRejectsMismatchedPayloadSize() throws {
        let repoRoot = try Self.repoRoot()
        let factorySource = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/MetalDocumentGpuOperationBackendFactory.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: factorySource, encoding: .utf8)

        #expect(body.contains("let width = max(Int(canvasSize.width.rounded()), 1)"))
        #expect(body.contains("let height = max(Int(canvasSize.height.rounded()), 1)"))
        #expect(body.contains("guard pixelData.count == width * height * 4 else"))
    }

    @Test
    func layerTransformExpandsCroppedSelectionWithOriginBeforeCanvasSize() {
        let box = ExpandedSelectionMaskCallBox()
        let gateway = DocumentGpuOperationGateway(
            compositedPaperPreviewRGBA: { _, _, _, _ in nil },
            compositedPreviewPixelData: { _, _, _ in nil },
            compositedPreviewIncrementalUpdate: { _, _, _, _ in nil },
            selectionOverlayRGBA: { _, _, _ in nil },
            eyedropperLoupeRGBA: { _, _, _, _, _, _, _, _ in nil },
            shapePreviewSurface: { _, _, _, _ in nil },
            textLayerSurface: { _, _ in nil },
            textLayoutRect: { _, _ in nil },
            processedLayerPixelData: { _, _, _, _ in nil },
            alphaMask: { _, _, _ in nil },
            croppedSelectionMask: { _, _, _ in nil },
            combinedSelectionMask: { _, _, _, _, _ in nil },
            expandedSelectionMask: { request in
                box.arguments = (
                    maskWidth: request.maskWidth,
                    maskHeight: request.maskHeight,
                    originX: request.originX,
                    originY: request.originY,
                    canvasWidth: request.canvasWidth,
                    canvasHeight: request.canvasHeight
                )
                return [UInt8](repeating: 255, count: request.canvasWidth * request.canvasHeight)
            },
            lassoSelection: { _, _, _ in nil },
            autoSelection: { _, _, _, _, _, _, _, _, _ in nil },
            colorRangeSelection: { _, _, _, _ in nil },
            expandedMask: { source, _, _, _ in source },
            contractedMask: { source, _, _, _ in source },
            featheredMask: { source, _, _, _ in source },
            invertMask: { _ in nil },
            transformedSelectionMask: { _ in nil },
            transformedLayerPixelData: { request in request.source },
            scaledPixelData: { _, _, _, _, _ in nil },
            translatedPixelData: { _, _, _, _, _, _, _ in nil },
            releaseSurfaceHandle: { _ in }
        )
        let processor = GpuLayerTransformProcessor(gpuOperations: gateway)
        let source = Data(repeating: 0, count: 4 * 3 * 4)
        let selection = CanvasSelection.unsafeUnchecked(
            bounds: CGRect(x: 2.4, y: 1.7, width: 2, height: 1),
            maskWidth: 2,
            maskHeight: 1,
            maskData: Data([255, 255]),
            mode: .lasso
        )

        let output = processor.transformedLayerPixels(
            source: source,
            canvasWidth: 4,
            canvasHeight: 3,
            selection: selection,
            translation: CGSize(width: 1, height: 0),
            scaleX: 1,
            scaleY: 1,
            rotationDegrees: 0,
            pivot: nil,
            mode: .standard,
            quadOffsets: .zero
        )

        #expect(output == source)
        #expect(box.arguments?.maskWidth == 2)
        #expect(box.arguments?.maskHeight == 1)
        #expect(box.arguments?.originX == 2)
        #expect(box.arguments?.originY == 1)
        #expect(box.arguments?.canvasWidth == 4)
        #expect(box.arguments?.canvasHeight == 3)
    }

    @Test
    func shapePreviewBrushSettingsExpandGrayscaleColorToRGB() throws {
        let box = BrushSettingsCallBox()
        let gateway = DocumentGpuOperationGateway(
            compositedPaperPreviewRGBA: { _, _, _, _ in nil },
            compositedPreviewPixelData: { _, _, _ in nil },
            compositedPreviewIncrementalUpdate: { _, _, _, _ in nil },
            selectionOverlayRGBA: { _, _, _ in nil },
            eyedropperLoupeRGBA: { _, _, _, _, _, _, _, _ in nil },
            shapePreviewSurface: { _, brush, width, height in
                box.brush = brush
                return DocumentCompositeSurface(
                    unsafeUncheckedWidth: width,
                    height: height,
                    pixelData: Data(repeating: 0, count: width * height * 4)
                )
            },
            textLayerSurface: { _, _ in nil },
            textLayoutRect: { _, _ in nil },
            processedLayerPixelData: { _, _, _, _ in nil },
            alphaMask: { _, _, _ in nil },
            croppedSelectionMask: { _, _, _ in nil },
            combinedSelectionMask: { _, _, _, _, _ in nil },
            expandedSelectionMask: { _ in nil },
            lassoSelection: { _, _, _ in nil },
            autoSelection: { _, _, _, _, _, _, _, _, _ in nil },
            colorRangeSelection: { _, _, _, _ in nil },
            expandedMask: { source, _, _, _ in source },
            contractedMask: { source, _, _, _ in source },
            featheredMask: { source, _, _, _ in source },
            invertMask: { _ in nil },
            transformedSelectionMask: { _ in nil },
            transformedLayerPixelData: { request in request.source },
            scaledPixelData: { _, _, _, _, _ in nil },
            translatedPixelData: { _, _, _, _, _, _, _ in nil },
            releaseSurfaceHandle: { _ in }
        )
        let renderer = GpuCanvasPreviewRenderer(gpuOperations: gateway)
        let stroke = Stroke(
            points: [
                StrokePoint(
                    position: SIMD2<Float>(1, 1),
                    pressure: 1,
                    altitude: Float.pi / 2,
                    azimuth: 0,
                    timestamp: 0,
                    isPredicted: false
                )
            ]
        )
        let grayscaleColor = CGColor(gray: 0.25, alpha: 0.7)

        let surface = renderer.shapePreviewSurface(
            stroke: stroke,
            style: PreviewStrokeStyle(
                tipKind: .ink,
                isEraser: false,
                radius: 4,
                opacity: 1,
                flow: 1,
                hardness: 1,
                roundness: 1,
                angle: 0,
                followsStrokeAngle: false,
                pressureSensitivity: 1,
                stabilization: 0,
                customTip: nil,
                color: grayscaleColor
            ),
            canvasWidth: 2,
            canvasHeight: 2
        )
        let brush = try #require(box.brush)

        #expect(surface != nil)
        #expect(brush.red == brush.green)
        #expect(brush.green == brush.blue)
        #expect(brush.blue > 0)
        #expect(brush.green != 179)
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func previewCompositeRunsBehindGpuGateway() throws {
        let gateway = DocumentGpuOperationGatewayFactory.live()
        let basePixels = Data([0, 0, 0, 0, 0, 0, 0, 0])
        let adjustedPixels = Data([255, 0, 0, 255, 0, 255, 0, 255])
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 2,
            height: 1,
            revision: 1,
            compositePixelData: basePixels,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: basePixels
                )
            ]
        )

        let composited = try #require(gateway.compositedPreviewPixelData(snapshot, 0, adjustedPixels))
        #expect(composited == adjustedPixels)
    }

    @Test
    func strokeDirtyRectIsResolvedThroughRuntimeBoundary() {
        let dirtyRect = GpuRenderingSupport.strokePreviewDirtyRect(
            samples: [
                StylusSample(
                    point: CGPoint(x: 24, y: 18),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                )
            ],
            brush: .init(
                tipKind: .ink,
                radius: 6,
                opacity: 1,
                hardness: 0.8,
                roundness: 1,
                angle: 0,
                angleMode: .fixed,
                stampSpacing: 0.2,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .off,
                textureStrength: 0,
                pressureSensitivity: 1,
                red: 255,
                green: 255,
                blue: 255
            ),
            canvasWidth: 128,
            canvasHeight: 128
        )

        #expect(dirtyRect != nil)
        #expect((dirtyRect?.width ?? 0) > 0)
        #expect((dirtyRect?.height ?? 0) > 0)
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func compositedPaperPreviewRGBAProducesExportReadyPixels() throws {
        let gateway = DocumentGpuOperationGatewayFactory.live()
        let compositePixels = Data([255, 255, 255, 255, 0, 0, 0, 255])
        let output = try #require(gateway.compositedPaperPreviewRGBA(compositePixels, 2, 1, .default))
        #expect(output.count == compositePixels.count)
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func processedLayerPixelDataRunsAdjustmentsThroughRuntimeBoundary() throws {
        let gateway = DocumentGpuOperationGatewayFactory.live()
        let pixels = Data([
            10, 20, 30, 255,
            200, 180, 160, 128,
        ])

        let output = try #require(gateway.processedLayerPixelData(pixels, 2, 1, .luminanceToAlpha))
        #expect(output.count == pixels.count)
        #expect(output[0] == 0)
        #expect(output[1] == 0)
        #expect(output[2] == 0)
        #expect(output[3] < 255)
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func interactiveStrokePreviewBuildsPreviewThroughRuntimeBoundary() throws {
        let strokeService = DocumentStrokeProcessingService()
        let basePixels = Data(count: 32 * 32 * 4)
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 32,
            height: 32,
            revision: 3,
            compositePixelData: basePixels,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: basePixels
                )
            ]
        )

        let preview = try #require(strokeService.makePreviewSurface(
            snapshot: snapshot,
            activeLayerIndex: 0,
            basePixelData: basePixels,
            samples: [
                StylusSample(
                    point: CGPoint(x: 12, y: 12),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                ),
                StylusSample(
                    point: CGPoint(x: 20, y: 20),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0.016
                )
            ],
            brush: .init(
                tipKind: .ink,
                radius: 4,
                opacity: 1,
                hardness: 0.9,
                roundness: 1,
                angle: 0,
                angleMode: .fixed,
                stampSpacing: 0.15,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .off,
                textureStrength: 0,
                pressureSensitivity: 1,
                red: 255,
                green: 255,
                blue: 255
            ),
            preserveAlphaLockedPixels: false
        ))

        let surface = try #require(preview.surface)
        let dirtyRegion = try #require(preview.dirtyRegion)
        #expect(surface.width == 32)
        #expect(surface.height == 32)
        #expect(preview.incrementalUpdate?.gpuBufferHandle != nil)
        #expect(dirtyRegion.width > 0)
        #expect(dirtyRegion.height > 0)
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func committedEraserStrokePreservesLayerColorChannels() throws {
        let strokeService = DocumentStrokeProcessingService()
        let basePixel: [UInt8] = [28, 42, 56, 255]
        let basePixels = Data((0..<32 * 32).flatMap { _ in basePixel })
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 32,
            height: 32,
            revision: 4,
            compositePixelData: basePixels,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: basePixels
                )
            ]
        )

        let committed = try #require(strokeService.makeCommittedSurface(
            snapshot: snapshot,
            activeLayerIndex: 0,
            samples: [
                StylusSample(
                    point: CGPoint(x: 16, y: 16),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                )
            ],
            brush: .init(
                tipKind: .ink,
                radius: 8,
                opacity: 1,
                hardness: 1,
                roundness: 1,
                angle: 0,
                angleMode: .fixed,
                stampSpacing: 0.15,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .off,
                textureStrength: 0,
                pressureSensitivity: 1,
                red: 255,
                green: 0,
                blue: 0,
                isEraser: true
            ),
            preserveAlphaLockedPixels: false
        ))
        let pixels = try #require(committed.fallbackPixelData ?? strokeService.materializedPixelData(for: committed.handle))
        let centerOffset = ((16 * 32) + 16) * 4

        #expect(pixels[centerOffset] == basePixel[0])
        #expect(pixels[centerOffset + 1] == basePixel[1])
        #expect(pixels[centerOffset + 2] == basePixel[2])
        #expect(pixels[centerOffset + 3] < basePixel[3])
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func responsiveOilPreviewWithoutSmudgeStaysExact() throws {
        let strokeService = DocumentStrokeProcessingService()
        let basePixels = Data(count: 32 * 32 * 4)
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 32,
            height: 32,
            revision: 4,
            compositePixelData: basePixels,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: basePixels
                )
            ]
        )

        let preview = try #require(strokeService.makePreviewSurface(
            snapshot: snapshot,
            activeLayerIndex: 0,
            basePixelData: basePixels,
            samples: [
                StylusSample(
                    point: CGPoint(x: 10, y: 10),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                ),
                StylusSample(
                    point: CGPoint(x: 22, y: 22),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0.016
                )
            ],
            brush: .init(
                tipKind: .oil,
                radius: 5,
                opacity: 1,
                hardness: 0.8,
                roundness: 0.8,
                angle: 0,
                angleMode: .strokeDirection,
                stampSpacing: 0.1,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .strokeLocked,
                textureStrength: 0.2,
                wetness: 0.12,
                colorMixStrength: 0.1,
                smudgeRadius: 0.36,
                paintLoad: 0.92,
                smudgeEngineEnabled: false,
                smudgeMode: .smearing,
                smudgeLength: 0.4,
                colorRate: 0.46,
                pressureSensitivity: 0.16,
                red: 46,
                green: 50,
                blue: 58
            ),
            preserveAlphaLockedPixels: false,
            usesResponsivePreview: true
        ))

        let dirtyRegion = try #require(preview.dirtyRegion)
        #expect(preview.isApproximatePreview == false)
        #expect(preview.incrementalUpdate?.gpuBufferHandle != nil)
        #expect(dirtyRegion.width > 0)
        #expect(dirtyRegion.height > 0)
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func responsiveSmudgePreviewProvidesLiveDisplayUpdateWhenIncrementalContinuationIsDisabled() throws {
        let strokeService = DocumentStrokeProcessingService()
        let basePixels = Data(count: 96 * 96 * 4)
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 96,
            height: 96,
            revision: 5,
            compositePixelData: basePixels,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: basePixels
                )
            ]
        )

        let preview = try #require(strokeService.makePreviewSurface(
            snapshot: snapshot,
            activeLayerIndex: 0,
            basePixelData: basePixels,
            samples: [
                StylusSample(
                    point: CGPoint(x: 24, y: 24),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                ),
                StylusSample(
                    point: CGPoint(x: 72, y: 72),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0.016
                )
            ],
            brush: .init(
                tipKind: .oil,
                radius: 40,
                opacity: 1,
                hardness: 0.2,
                roundness: 1,
                angle: 0,
                angleMode: .fixed,
                stampSpacing: 0.12,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .off,
                textureStrength: 0,
                wetness: 0.2,
                colorMixStrength: 0.24,
                smudgeRadius: 0.36,
                paintLoad: 0.5,
                smudgeEngineEnabled: true,
                smudgeMode: .smearing,
                smudgeLength: 0.32,
                colorRate: 0.5,
                pressureSensitivity: 0.12,
                red: 255,
                green: 150,
                blue: 40
            ),
            preserveAlphaLockedPixels: false,
            usesResponsivePreview: true
        ))

        let liveUpdate = try #require(preview.incrementalUpdate)
        #expect(!preview.isApproximatePreview)
        #expect(!liveUpdate.isEmpty)
        #expect(liveUpdate.width > 0)
        #expect(liveUpdate.height > 0)
    }

    @Test
    func responsivePreviewBrushPreservesToneAndTipSettings() {
        let customTip = BrushTipRaster(width: 2, height: 1, alphaData: Data([0, 255]))
        let original = BrushRuntimeSettings(
            tipKind: .oil,
            radius: 8.4,
            opacity: 0.72,
            hardness: 0.8,
            roundness: 0.74,
            angle: 0,
            angleMode: .strokeDirection,
            stampSpacing: 0.09,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .strokeLocked,
            textureStrength: 0.16,
            flow: 0.82,
            flowPressureSensitivity: 0.08,
            wetness: 0.12,
            opacityPressureSensitivity: 0.1,
            colorMixStrength: 0.1,
            smudgeRadius: 0.36,
            paintLoad: 0.92,
            smudgeEngineEnabled: false,
            smudgeMode: .smearing,
            smudgeLength: 0.4,
            colorRate: 0.46,
            customTip: customTip,
            pressureSensitivity: 0.16,
            red: 46,
            green: 50,
            blue: 58
        )

        let preview = GpuRenderingSupport.responsivePreviewBrush(from: original)

        #expect(preview == original)
    }

    @Test
    func responsivePreviewBrushPreservesSmudgeForLiveSmudgePreview() {
        let customTip = BrushTipRaster(width: 2, height: 1, alphaData: Data([64, 255]))
        let original = BrushRuntimeSettings(
            tipKind: .oil,
            radius: 10,
            opacity: 0.82,
            hardness: 0.36,
            roundness: 0.96,
            angle: 0,
            angleMode: .fixed,
            stampSpacing: 0.10,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .strokeLocked,
            textureStrength: 0.10,
            flow: 0.82,
            wetness: 0.20,
            colorMixStrength: 0.24,
            paintLoad: 0.08,
            smudgeEngineEnabled: true,
            smudgeMode: .smearing,
            smudgeLength: 0.32,
            colorRate: 0.08,
            customTip: customTip,
            pressureSensitivity: 0.12,
            red: 46,
            green: 47,
            blue: 50
        )

        let preview = GpuRenderingSupport.responsivePreviewBrush(from: original)

        #expect(preview == original)
        #expect(preview.customTip == original.customTip)
        #expect(preview.red == original.red)
        #expect(preview.green == original.green)
        #expect(preview.blue == original.blue)
    }

    @Test(.enabled(if: metalRuntimeAvailable))
    func compositedPreviewDoesNotReuseStaleLayerTextureAcrossDistinctSnapshots() throws {
        let gateway = DocumentGpuOperationGatewayFactory.live()
        let transparentActivePixels = Data([0, 0, 0, 0])
        let redBackground = Data([255, 0, 0, 255])
        let blueBackground = Data([0, 0, 255, 255])

        let firstSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 1,
            height: 1,
            revision: 0,
            compositePixelData: redBackground,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: redBackground
                ),
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 1,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: transparentActivePixels
                )
            ]
        )
        let secondSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 1,
            height: 1,
            revision: 0,
            compositePixelData: blueBackground,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: blueBackground
                ),
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 1,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: transparentActivePixels
                )
            ]
        )

        let firstComposite = try #require(
            gateway.compositedPreviewPixelData(firstSnapshot, 1, transparentActivePixels)
        )
        let secondComposite = try #require(
            gateway.compositedPreviewPixelData(secondSnapshot, 1, transparentActivePixels)
        )
        #expect(firstComposite == redBackground)
        #expect(secondComposite == blueBackground)
    }

    private static func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "PrimoModules" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                throw CocoaError(.fileReadNoSuchFile)
            }
            url = parent
        }
        return url.deletingLastPathComponent().deletingLastPathComponent()
    }
}

private final class ExpandedSelectionMaskCallBox: @unchecked Sendable {
    var arguments: (
        maskWidth: Int,
        maskHeight: Int,
        originX: Int,
        originY: Int,
        canvasWidth: Int,
        canvasHeight: Int
    )?
}

private final class BrushSettingsCallBox: @unchecked Sendable {
    var brush: BrushRuntimeSettings?
}
