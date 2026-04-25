import AVFoundation
import CoreGraphics
import UIKit

struct CanvasViewportGeometry {
    var bounds: CGRect
    var documentSize: CGSize
    var viewportOffset: CGSize
    var zoomScale: CGFloat

    var contentRect: CGRect {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fitted.width * zoomScale, height: fitted.height * zoomScale)
        return CGRect(
            x: fitted.midX - (scaledSize.width / 2) + viewportOffset.width,
            y: fitted.midY - (scaledSize.height / 2) + viewportOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    func documentPoint(fromViewPoint viewPoint: CGPoint) -> CGPoint {
        let rect = contentRect
        return CGPoint(
            x: ((viewPoint.x - rect.minX) / max(rect.width, 1)) * documentSize.width,
            y: ((viewPoint.y - rect.minY) / max(rect.height, 1)) * documentSize.height
        )
    }

    func viewPoint(fromDocumentPoint point: CGPoint) -> CGPoint {
        let rect = contentRect
        guard rect.width > 0, rect.height > 0, documentSize.width > 0, documentSize.height > 0 else {
            return .zero
        }
        return CGPoint(
            x: rect.minX + ((point.x / documentSize.width) * rect.width),
            y: rect.minY + ((point.y / documentSize.height) * rect.height)
        )
    }

    func viewRect(forDocumentRect rect: CGRect) -> CGRect {
        guard contentRect.width > 0, contentRect.height > 0, documentSize.width > 0, documentSize.height > 0 else {
            return .zero
        }
        let minPoint = viewPoint(fromDocumentPoint: rect.origin)
        let maxPoint = viewPoint(fromDocumentPoint: CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(
            x: minPoint.x,
            y: minPoint.y,
            width: max(1, maxPoint.x - minPoint.x),
            height: max(1, maxPoint.y - minPoint.y)
        )
    }

    func documentTranslation(from viewTranslation: CGPoint) -> CGSize {
        let rect = contentRect
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGSize(
            width: (viewTranslation.x / rect.width) * documentSize.width,
            height: (viewTranslation.y / rect.height) * documentSize.height
        )
    }

    func clampedViewportOffset(_ proposedOffset: CGSize, zoomScale overrideZoomScale: CGFloat? = nil) -> CGSize {
        let resolvedZoomScale = overrideZoomScale ?? zoomScale
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * resolvedZoomScale
        let scaledHeight = fitted.height * resolvedZoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    func offsetKeepingDocumentPointStable(
        _ documentPoint: CGPoint,
        at viewPoint: CGPoint,
        zoomScale newZoomScale: CGFloat
    ) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * newZoomScale, height: fittedRect.height * newZoomScale)
        let normalizedX = documentPoint.x / max(documentSize.width, 1)
        let normalizedY = documentPoint.y / max(documentSize.height, 1)
        let desiredOrigin = CGPoint(
            x: viewPoint.x - (normalizedX * scaledSize.width),
            y: viewPoint.y - (normalizedY * scaledSize.height)
        )
        let baseOrigin = CGPoint(
            x: fittedRect.midX - (scaledSize.width / 2),
            y: fittedRect.midY - (scaledSize.height / 2)
        )
        return clampedViewportOffset(
            CGSize(width: desiredOrigin.x - baseOrigin.x, height: desiredOrigin.y - baseOrigin.y),
            zoomScale: newZoomScale
        )
    }
}
