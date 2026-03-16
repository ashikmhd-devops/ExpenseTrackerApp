import AppKit
import PDFKit

struct ReceiptImageHelper {

    /// Renders the first page of a PDF to an NSImage at 2× scale.
    static func pdfToImage(url: URL) -> NSImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let imageSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let image = NSImage(size: imageSize)
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        ctx.scaleBy(x: scale, y: scale)
        NSColor.white.setFill()
        NSBezierPath.fill(pageRect)
        page.draw(with: .mediaBox, to: ctx)
        image.unlockFocus()
        return image
    }

    /// Converts an NSImage to a JPEG base64 string (max 1024px longest side).
    static func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        // Downscale if needed
        let maxDim: CGFloat = 1024
        let size = bitmap.size
        let scale = min(maxDim / max(size.width, size.height), 1.0)

        let finalBitmap: NSBitmapImageRep
        if scale < 1.0 {
            let newSize = NSSize(width: size.width * scale, height: size.height * scale)
            let resized = NSImage(size: newSize)
            resized.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            resized.unlockFocus()
            guard let tiff2 = resized.tiffRepresentation,
                  let bm2 = NSBitmapImageRep(data: tiff2) else { return nil }
            finalBitmap = bm2
        } else {
            finalBitmap = bitmap
        }

        guard let jpegData = finalBitmap.representation(using: .jpeg,
                                                         properties: [.compressionFactor: 0.85]) else { return nil }
        return jpegData.base64EncodedString()
    }
}
