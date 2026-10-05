import CoreGraphics
import Foundation
import Vision

/// Reads QR codes in an image, such as a pasted screenshot of a Demiplane character sheet's code.
public enum QRCodeReader {
    /// The text of every QR code found, in the order Vision reports them.
    public static func payloads(in image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            throw CharacterImportError.unreadableImage(operation: "Reading a QR code", underlying: error)
        }
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }

    /// The first Demiplane reference in the image's QR codes.
    public static func reference(in image: CGImage) throws -> DemiplaneReference? {
        try payloads(in: image).lazy.compactMap(DemiplaneReference.parse).first
    }
}
