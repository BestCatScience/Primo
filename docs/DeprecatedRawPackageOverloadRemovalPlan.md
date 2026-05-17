# Deprecated Raw Package Overload Removal Plan

This plan tracks package-scoped raw overloads that remain only as short-term compatibility shims for app adapters and presentation protocols. New raw overloads are prohibited by `GpuSideEffectIsolationArchitectureTests.deprecatedPackageRawRuntimeOverloadBaselineDoesNotGrowAndPlanStaysCurrent`, which runs in CI through the package `swift test` job.

## CI Guard

- CI entrypoint: `.github/workflows/ci.yml` -> `package-tests` -> `swift test`
- Guard test: `GpuSideEffectIsolationArchitectureTests.deprecatedPackageRawRuntimeOverloadBaselineDoesNotGrowAndPlanStaysCurrent`
- Rule: the baseline below may shrink, but must not grow. When a raw overload is removed, delete it from this plan and from the expected baseline in the test in the same change.

## Current Baseline

- `CanvasMutationRuntime.package func createCanvas(_ width: Int, _ height: Int)`
- `CanvasMutationRuntime.package func resizeCanvas(_ width: Int, _ height: Int)`
- `CanvasMutationRuntime.package func resizeCanvasExtent(_ width: Int, _ height: Int)`
- `CanvasPreviewRuntime.package func compositePreviewImageData(snapshot: MetalDocumentSnapshot, activeLayerIndex: Int, adjustedActiveLayerPixels: Data)`
- `CanvasPreviewRuntime.package func eyedropperLoupeSurface( sourcePixelData: Data, canvasWidth: Int, canvasHeight: Int, centerX: Int, centerY: Int, gridSize: Int, paperStyle: CanvasPaperStyle, blendWithPaper: Bool )`
- `CanvasPreviewRuntime.package func paperCompositeSurface(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle)`
- `CanvasPreviewRuntime.package func selectionOverlaySurface(maskData: Data, width: Int, height: Int)`
- `DocumentPersistenceClient.package func newCanvas(_ width: Int, _ height: Int)`
- `DocumentPersistenceRuntime.package func newCanvas(_ width: Int, _ height: Int)`

## Removal Order

1. Replace app-side canvas mutation adapter calls with `ValidCanvasSize`, then remove `CanvasMutationRuntime.createCanvas(_:_:)`, `resizeCanvas(_:_:)`, and `resizeCanvasExtent(_:_:)`.
2. Replace persistence adapter calls with `ValidCanvasSize`, then remove `DocumentPersistenceClient.newCanvas(_:_:)` and `DocumentPersistenceRuntime.newCanvas(_:_:)`.
3. Move preview adapter protocols to typed `ExistingLayerIndex`, `RgbaSurface`, and `MaskSurface`, then remove `CanvasPreviewRuntime.compositePreviewImageData(snapshot:activeLayerIndex:adjustedActiveLayerPixels:)`, `paperCompositeSurface(pixelData:width:height:paperStyle:)`, and `selectionOverlaySurface(maskData:width:height:)`.
4. Move loupe preview to a typed source surface plus typed center/grid request, then remove `CanvasPreviewRuntime.eyedropperLoupeSurface(sourcePixelData:canvasWidth:canvasHeight:centerX:centerY:gridSize:paperStyle:blendWithPaper:)`.

## Exit Criteria

- The current baseline list is empty.
- Runtime facade package APIs no longer expose raw layer indexes, raw pixel payloads, or raw width/height overloads where typed value objects exist.
- The CI guard remains in place after the baseline reaches zero so new raw overloads fail fast.
