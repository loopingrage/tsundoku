import CoreGraphics
import Foundation

enum SpineDetectionError: Error, LocalizedError {
    case imageConversionFailed
    case noSpinesDetected
    case visionRequestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process the shelf image."
        case .noSpinesDetected:
            return "No book spines were detected in this image."
        case .visionRequestFailed(let error):
            return "Vision analysis failed: \(error.localizedDescription)"
        }
    }
}

struct OCRObservationInfo: Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Vision coordinates (bottom-left origin, 0...1)
    let boundingBoxArea: CGFloat
    let isSearchCandidate: Bool  // true = this was used as the search query
}

struct SpineDebugInfo: @unchecked Sendable {
    let spineRect: CGRect          // normalized rect in original image (top-left origin)
    let spinePixelWidth: Int
    let spinePixelHeight: Int
    let searchQuery: String        // actual string sent to metadata API
    let observations: [OCRObservationInfo]
    let processingTimeMs: Int      // metadata lookup time
    let metadataError: String?     // if lookup failed, the error message
}

enum MatchConfidence: Int, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: MatchConfidence, rhs: MatchConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SpineScanResult: Identifiable, @unchecked Sendable {
    let id: UUID
    let spineImage: CGImage
    let rawOCRText: String
    let metadataMatch: BookSearchResult?
    let confidence: MatchConfidence
    let debug: SpineDebugInfo
}

protocol SpineDetectionService: Sendable {
    func scanShelf(image: PlatformImage) async throws -> [SpineScanResult]
}

struct SpineOCROutput: Sendable {
    let cgImage: CGImage
    let searchQuery: String
    let allText: String
    let observationDetails: [OCRObservationInfo]
    let normalizedRect: CGRect
}

protocol SteppedSpineDetectionService: Sendable {
    func detectSpines(in image: PlatformImage) throws -> [CGRect]
    func ocrSpine(in image: PlatformImage, rect: CGRect) async throws -> SpineOCROutput?
    func lookupMetadata(for output: SpineOCROutput, in image: PlatformImage, rect: CGRect) async throws -> SpineScanResult
}

// MARK: - Pluggable Component Protocols

/// Abstracts the spine detection step so different algorithms can be swapped in.
protocol SpineDetector: Sendable {
    func detect(in image: PlatformImage) throws -> [CGRect]
}

/// Abstracts the OCR/recognition step so a VLM can replace Apple Vision OCR.
protocol SpineRecognizer: Sendable {
    func recognize(in image: CGImage) async throws -> SpineRecognition?
}

struct SpineRecognition: Sendable {
    let searchQuery: String
    let fullText: String
    let observations: [OCRObservationInfo]
}
