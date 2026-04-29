import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoDocumentApplication
import PrimoDocumentContracts
import XCTest

final class DocumentCommandPerformanceTests: XCTestCase {
    func testApplyGpuStrokeSurfaceRequestDispatchPerformance() {
        let samples = (0..<512).map { index in
            StylusSample(
                point: CGPoint(x: index, y: index),
                pressure: 1.0,
                altitude: 0.0,
                azimuth: 0.0,
                timestamp: Double(index) * 0.01
            )
        }
        let service = DocumentStrokeCommandService(
            strokeGateway: StrokeInputGateway(
                beginStroke: { _, _ in },
                appendStroke: { _ in },
                endStroke: { .success(()) },
                cancelStroke: {},
                blurStroke: { _, _, _, _ in .success(()) },
                endBlurStroke: {},
                fill: { _, _ in .success(()) },
                applyGpuStrokeSurface: { _, _, _ in .success(()) }
            )
        )
        let brush = BrushRuntimeSettings(
            tipKind: .ink,
            radius: 8,
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
            pressureSensitivity: 1,
            red: 255,
            green: 255,
            blue: 255
        )

        measure {
            guard case .success = service.applyGpuStrokeSurface(samples, brush, 0) else {
                XCTFail("Expected applyGpuStrokeSurface command dispatch to succeed")
                return
            }
        }
    }
}
