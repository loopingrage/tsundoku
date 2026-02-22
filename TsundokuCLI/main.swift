import AppKit
import CoreGraphics
import Foundation

// MARK: - JSON Output Types

private struct JSONRect: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.width)
        height = Double(rect.height)
    }
}

private struct JSONMatch: Encodable {
    let title: String
    let authors: [String]
    let source: String
}

private struct JSONSpineResult: Encodable {
    let index: Int
    let rect: JSONRect
    let pixelWidth: Int
    let pixelHeight: Int
    let ocrText: String
    let searchQuery: String
    let match: JSONMatch?
    let lookupTimeMs: Int?
}

private struct JSONOutput: Encodable {
    let imagePath: String
    let pipeline: String
    let imagePixelWidth: Int
    let imagePixelHeight: Int
    let detectedRects: [JSONRect]
    let spinesDetected: Int
    let spinesWithOCR: Int
    let results: [JSONSpineResult]
    let detectOnly: Bool
    let totalTimeMs: Int
}

private struct CLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - CLI

@MainActor
func run() async throws {
    var args = Array(CommandLine.arguments.dropFirst())
    var doLookup = false
    var useVLM = false
    var pipelineName = "classical"

    // Parse flags
    if let lookupIndex = args.firstIndex(of: "--lookup") {
        doLookup = true
        args.remove(at: lookupIndex)
    }

    // Remove --detect-only flag if present (it's the default)
    if let detectIndex = args.firstIndex(of: "--detect-only") {
        args.remove(at: detectIndex)
    }

    if let vlmIndex = args.firstIndex(of: "--vlm") {
        useVLM = true
        args.remove(at: vlmIndex)
    }

    if let pipelineIndex = args.firstIndex(of: "--pipeline") {
        let valueIndex = args.index(after: pipelineIndex)
        guard valueIndex < args.endIndex else {
            throw CLIError(message: "Missing value for --pipeline. Use: classical, yolo, fastsam")
        }
        pipelineName = args[valueIndex]
        args.remove(at: valueIndex)
        args.remove(at: pipelineIndex)
    }

    guard let pipeline = DetectionPipeline(rawValue: pipelineName) else {
        throw CLIError(message: "Unknown pipeline '\(pipelineName)'. Use: classical, yolo, fastsam")
    }

    guard let imagePath = args.first else {
        throw CLIError(message: "Usage: TsundokuCLI [--lookup] [--detect-only] [--pipeline classical|yolo|fastsam] [--vlm] <image-path>")
    }

    let url = URL(fileURLWithPath: (imagePath as NSString).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CLIError(message: "File not found: \(url.path)")
    }

    guard let image = NSImage(contentsOf: url) else {
        throw CLIError(message: "Could not load image: \(url.path)")
    }

    if doLookup && Secrets.googleBooksAPIKey.isEmpty {
        FileHandle.standardError.write(Data("Warning: GOOGLE_BOOKS_API_KEY not set. Metadata lookup will use Open Library only.\n".utf8))
    }

    let totalStart = ContinuousClock.now

    let recognizer: SpineRecognizer? = useVLM ? VLMSpineRecognizer() : nil
    let service = try PipelineFactory.makeService(pipeline: pipeline, recognizerOverride: recognizer)

    // Step 1: Detect spine rects
    let rects = try service.detectSpines(in: image)

    // Step 2: OCR each spine
    var ocrOutputs: [SpineOCROutput] = []
    for rect in rects {
        if let output = try await service.ocrSpine(in: image, rect: rect) {
            ocrOutputs.append(output)
        }
    }

    // Step 3: Optionally look up metadata
    var jsonResults: [JSONSpineResult] = []

    guard let cgImage = image.cgImage else {
        throw CLIError(message: "Could not get CGImage from image.")
    }
    let imagePixelWidth = cgImage.width
    let imagePixelHeight = cgImage.height

    for (index, output) in ocrOutputs.enumerated() {
        var match: JSONMatch?
        var lookupTimeMs: Int?

        if doLookup {
            let lookupStart = ContinuousClock.now
            do {
                let result = try await service.lookupMetadata(for: output, in: image, rect: output.normalizedRect)
                if let m = result.metadataMatch {
                    match = JSONMatch(title: m.title, authors: m.authors, source: m.source.rawValue)
                }
            } catch {
                // Lookup errors are non-fatal; match stays nil
            }
            let elapsed = ContinuousClock.now - lookupStart
            lookupTimeMs = Int(elapsed.components.seconds * 1000)
                + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        }

        let spinePixelWidth = Int(output.normalizedRect.width * CGFloat(imagePixelWidth))
        let spinePixelHeight = Int(output.normalizedRect.height * CGFloat(imagePixelHeight))

        jsonResults.append(JSONSpineResult(
            index: index,
            rect: JSONRect(output.normalizedRect),
            pixelWidth: spinePixelWidth,
            pixelHeight: spinePixelHeight,
            ocrText: output.allText,
            searchQuery: String(output.searchQuery.prefix(60)),
            match: match,
            lookupTimeMs: lookupTimeMs
        ))
    }

    let totalElapsed = ContinuousClock.now - totalStart
    let totalMs = Int(totalElapsed.components.seconds * 1000)
        + Int(totalElapsed.components.attoseconds / 1_000_000_000_000_000)

    let output = JSONOutput(
        imagePath: url.path,
        pipeline: pipeline.rawValue,
        imagePixelWidth: imagePixelWidth,
        imagePixelHeight: imagePixelHeight,
        detectedRects: rects.map { JSONRect($0) },
        spinesDetected: rects.count,
        spinesWithOCR: ocrOutputs.count,
        results: jsonResults,
        detectOnly: !doLookup,
        totalTimeMs: totalMs
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(output)
    FileHandle.standardOutput.write(jsonData)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

// Entry point
do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
