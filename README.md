# atelierprime

`atelierprime` is an iPad-first painting prototype that combines a SwiftUI front end with a C++ painting core.

## What is included

- Multi-layer raster document model
- Pencil-like brush with pressure-aware opacity and radius
- Fast C++ stroke rasterization with Metal-based display compositing
- Objective-C++ bridge for Swift consumption
- TCA-based SwiftUI app architecture
- SwiftUI iPad interface with layer list, brush controls, and canvas
- A checked-in Xcode project you can open directly

## Project structure

- `Engine/` C++ painting engine
- `Bridge/` Objective-C++ bridge exposed to Swift
- `App/` SwiftUI iPad app

## Getting started

1. Open the project in Xcode.

```bash
open atelierprime.xcodeproj
```

2. Build and run the `atelierprime` scheme on an iPad simulator or device.

## Architecture notes

- Each layer owns its own premultiplied RGBA buffer in C++.
- Strokes are rendered directly into the active layer with a dab-based brush.
- Swift uploads layer buffers to Metal textures and composites them on the GPU for preview.
- SwiftUI owns interaction state, while the drawing core remains platform-agnostic.

## Next steps

- Tile-based renderer and dirty-rect updates
- GPU presentation path with Metal textures
- More realistic brush grain, tilt, and wet-mix dynamics
- Undo/redo journal and persistent document serialization
