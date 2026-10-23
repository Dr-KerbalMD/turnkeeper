import CoreGraphics
import Foundation

/// The first page of a PDF as an image, such as a map copied out of a PDF viewer, on white like the page.
enum PDFPageImage {
    static func firstPage(of data: Data, maximumPixels: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let page = CGPDFDocument(provider)?.page(at: 1) else { return nil }
        let bounds = page.getBoxRect(.cropBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        // Up to 2× the page's size in points, so a small copied figure stays sharp, within the cap.
        let scale = min(2, CGFloat(maximumPixels) / max(bounds.width, bounds.height))
        let width = Int((bounds.width * scale).rounded()), height = Int((bounds.height * scale).rounded())
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }
}
