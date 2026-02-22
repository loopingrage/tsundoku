import CoreImage
import Foundation
import Vision

// MARK: - Classical Spine Detector

/// Detects spine boundaries using a combination of contour detection and vertical projection profiles.
struct ClassicalSpineDetector: SpineDetector, Sendable {

    struct DetectedSpine: Sendable {
        let normalizedRect: CGRect // top-left origin, 0...1
    }

    // Calibration constants
    private let minimumAspectRatio: CGFloat = 2.0
    private let minimumHeightFraction: CGFloat = 0.15
    private let minPeakDistanceFraction: CGFloat = 0.015
    private let peakThresholdFraction: Float = 0.05
    private let iouDeduplicationThreshold: CGFloat = 0.5
    private let maxWidthFraction: CGFloat = 0.20
    private let minCropPixelWidth: CGFloat = 100
    private let valleyDepthThreshold: Float = 0.50

    // MARK: - SpineDetector conformance

    func detect(in image: PlatformImage) throws -> [CGRect] {
        try detectSpines(in: image).map(\.normalizedRect)
    }

    // MARK: - Internal detection

    func detectSpines(in image: PlatformImage) throws -> [DetectedSpine] {
        guard let cgImage = image.cgImage else {
            throw SpineDetectionError.imageConversionFailed
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // 1. Contour-based detection
        let contourSpines = try detectViaContours(cgImage: cgImage, imageWidth: imageWidth, imageHeight: imageHeight)

        // 2. Projection profile detection
        let projectionSpines = detectViaProjectionProfile(image: image, imageWidth: imageWidth, imageHeight: imageHeight)

        // 3. Merge candidates, deduplicate
        let allCandidates = contourSpines + projectionSpines
        let deduplicated = deduplicateByIoU(allCandidates)

        // 4. Sort left-to-right
        return deduplicated.sorted { $0.normalizedRect.origin.x < $1.normalizedRect.origin.x }
    }

    // MARK: - Contour Detection

    private func detectViaContours(cgImage: CGImage, imageWidth: CGFloat, imageHeight: CGFloat) throws -> [DetectedSpine] {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.5
        request.detectsDarkOnLight = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw SpineDetectionError.visionRequestFailed(error)
        }

        guard let observation = request.results?.first else { return [] }

        var spines: [DetectedSpine] = []
        let contourCount = observation.contourCount
        for i in 0..<contourCount {
            guard let contour = try? observation.contour(at: i) else { continue }
            let boundingBox = contour.normalizedPath.boundingBox

            // Vision uses bottom-left origin — convert to top-left
            let normalizedRect = CGRect(
                x: boundingBox.origin.x,
                y: 1.0 - boundingBox.origin.y - boundingBox.height,
                width: boundingBox.width,
                height: boundingBox.height
            )

            let pixelHeight = normalizedRect.height * imageHeight
            let pixelWidth = normalizedRect.width * imageWidth
            guard pixelWidth > 0 else { continue }

            let aspectRatio = pixelHeight / pixelWidth
            let heightFraction = normalizedRect.height

            let widthFraction = normalizedRect.width
            if aspectRatio >= minimumAspectRatio && heightFraction >= minimumHeightFraction && widthFraction <= maxWidthFraction {
                spines.append(DetectedSpine(normalizedRect: normalizedRect))
            }
        }

        return spines
    }

    // MARK: - Projection Profile Detection

    private func detectViaProjectionProfile(image: PlatformImage, imageWidth: CGFloat, imageHeight: CGFloat) -> [DetectedSpine] {
        guard let edgeImage = ImageProcessing.preprocessForSpineDetection(image) else { return [] }

        let context = CIContext()
        let columnSums = ImageProcessing.computeColumnSums(from: edgeImage, context: context)
        guard !columnSums.isEmpty else { return [] }

        let maxSum = columnSums.max() ?? 1.0
        let threshold = maxSum * peakThresholdFraction
        let minPeakDistance = max(1, Int(imageWidth * minPeakDistanceFraction))

        let rawPeaks = ImageProcessing.findPeaks(in: columnSums, minPeakDistance: minPeakDistance, threshold: threshold)
        guard rawPeaks.count >= 2 else { return [] }

        // Valley-depth filtering: merge adjacent peaks when the valley between them
        // is too shallow to represent a real spine boundary.
        var peaks = filterByValleyDepth(peaks: rawPeaks, profile: columnSums)
        guard peaks.count >= 2 else { return [] }

        // Add image edges as implicit peaks to ensure full shelf coverage.
        // This handles books at the far left/right that may not have detected boundary peaks.
        if let first = peaks.first, first > Int(imageWidth * 0.02) {
            peaks.insert(0, at: 0)
        }
        if let last = peaks.last, last < Int(imageWidth) - Int(imageWidth * 0.02) {
            peaks.append(Int(imageWidth) - 1)
        }

        // Convert peak pairs to spine rects (each pair of adjacent peaks defines a spine boundary)
        var spines: [DetectedSpine] = []
        for i in 0..<(peaks.count - 1) {
            let leftX = CGFloat(peaks[i]) / imageWidth
            let rightX = CGFloat(peaks[i + 1]) / imageWidth
            let width = rightX - leftX

            // Skip if too narrow or too wide
            let pixelWidth = width * imageWidth
            let expectedMinWidth = imageWidth * 0.01
            let expectedMaxWidth = imageWidth * maxWidthFraction
            guard pixelWidth >= expectedMinWidth, pixelWidth <= expectedMaxWidth else { continue }

            let rect = CGRect(x: leftX, y: 0.0, width: width, height: 1.0)
            spines.append(DetectedSpine(normalizedRect: rect))
        }

        return spines
    }

    // MARK: - Deduplication

    private func deduplicateByIoU(_ candidates: [DetectedSpine]) -> [DetectedSpine] {
        guard !candidates.isEmpty else { return [] }

        var kept: [DetectedSpine] = []
        for candidate in candidates {
            let isDuplicate = kept.contains { existing in
                iou(existing.normalizedRect, candidate.normalizedRect) > iouDeduplicationThreshold
            }
            if !isDuplicate {
                kept.append(candidate)
            }
        }
        return kept
    }

    // MARK: - Valley-Depth Filtering

    /// Remove peaks where the valley between adjacent peaks is too shallow,
    /// indicating an internal spine feature rather than a real boundary between books.
    private func filterByValleyDepth(peaks: [Int], profile: [Float]) -> [Int] {
        guard peaks.count > 2 else { return peaks }

        var filtered = [peaks[0]]

        for i in 1..<peaks.count {
            let prevPeak = filtered.last!
            let currPeak = peaks[i]

            // Find the minimum value (valley) between the two peaks
            let valleyMin = profile[prevPeak...currPeak].min() ?? 0
            let peakAvg = (profile[prevPeak] + profile[currPeak]) / 2.0

            // If the valley doesn't dip enough relative to the peak heights,
            // skip this peak (merge the segments)
            guard peakAvg > 0 else {
                filtered.append(currPeak)
                continue
            }

            let valleyRatio = valleyMin / peakAvg
            if valleyRatio < valleyDepthThreshold {
                // Deep valley = real boundary, keep the peak
                filtered.append(currPeak)
            }
            // Shallow valley = internal feature, drop the peak (merge segments)
        }

        return filtered
    }

    private func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }
}

// MARK: - OCR Helper

enum SpineOCR {

    struct OCRResult {
        let searchQuery: String
        let allText: String
        let observationDetails: [OCRObservationInfo]
    }

    /// Check if text contains mostly Latin characters (reject OCR that produces Thai, CJK, etc.)
    static func isLatinText(_ text: String) -> Bool {
        let latinCount = text.unicodeScalars.filter { scalar in
            (0x0020...0x024F).contains(scalar.value) // Basic Latin + Latin Extended
        }.count
        return latinCount > text.unicodeScalars.count / 2
    }

    static func recognizeText(in cgImage: CGImage) throws -> OCRResult {
        // Try both orientations and pick the one with better average confidence.
        // .right = text reads top-to-bottom, .left = text reads bottom-to-top
        let rightResult = try performOCR(in: cgImage, orientation: .right)
        let leftResult = try performOCR(in: cgImage, orientation: .left)

        // Filter out non-Latin results (Vision sometimes hallucinates CJK/Thai text)
        let rightIsLatin = isLatinText(rightResult.allText)
        let leftIsLatin = isLatinText(leftResult.allText)

        if rightIsLatin && !leftIsLatin { return rightResult }
        if leftIsLatin && !rightIsLatin { return leftResult }

        let rightConf = rightResult.observationDetails.isEmpty ? 0 :
            rightResult.observationDetails.map(\.confidence).reduce(0, +) / Float(rightResult.observationDetails.count)
        let leftConf = leftResult.observationDetails.isEmpty ? 0 :
            leftResult.observationDetails.map(\.confidence).reduce(0, +) / Float(leftResult.observationDetails.count)

        return leftConf > rightConf ? leftResult : rightResult
    }

    private static func performOCR(in cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw SpineDetectionError.visionRequestFailed(error)
        }

        let observations = request.results ?? []
        guard !observations.isEmpty else {
            return OCRResult(searchQuery: "", allText: "", observationDetails: [])
        }

        // Build detailed info for each observation
        var details: [OCRObservationInfo] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let area = obs.boundingBox.width * obs.boundingBox.height
            details.append(OCRObservationInfo(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: obs.boundingBox,
                boundingBoxArea: area,
                isSearchCandidate: false
            ))
        }

        let allText = details.map(\.text).joined(separator: "\n")

        // Build search query: use the observation with the largest bounding box (usually the title),
        // then add the second largest for disambiguation. The full OCR text (allText) is passed
        // separately as ocrContext for on-device fuzzy re-ranking against the broader candidate set.
        let viable = details
            .filter { $0.confidence >= 0.3 && $0.text.count >= 3 }
            .sorted { $0.boundingBoxArea > $1.boundingBoxArea }
        let searchQuery: String
        if viable.count >= 2 {
            searchQuery = viable[0].text + " " + viable[1].text
        } else {
            searchQuery = viable.first?.text
                ?? details.max { $0.boundingBoxArea < $1.boundingBoxArea }?.text
                ?? ""
        }

        return OCRResult(searchQuery: searchQuery, allText: allText, observationDetails: details)
    }
}

// MARK: - VisionOCRRecognizer

/// Wraps the existing SpineOCR engine as a SpineRecognizer for use in the classical pipeline.
struct VisionOCRRecognizer: SpineRecognizer, Sendable {
    func recognize(in image: CGImage) async throws -> SpineRecognition? {
        let ocr = try SpineOCR.recognizeText(in: image)
        let query = ocr.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, SpineOCR.isLatinText(query) else { return nil }
        return SpineRecognition(
            searchQuery: ocr.searchQuery,
            fullText: ocr.allText,
            observations: ocr.observationDetails
        )
    }
}

// MARK: - SpineDetectionServiceImpl

struct SpineDetectionServiceImpl: SpineDetectionService {

    private let detector: SpineDetector
    private let recognizer: SpineRecognizer
    private let metadataService: BookMetadataService

    init(detector: SpineDetector = ClassicalSpineDetector(),
         recognizer: SpineRecognizer = VisionOCRRecognizer(),
         metadataService: BookMetadataService = BookMetadataServiceImpl()) {
        self.detector = detector
        self.recognizer = recognizer
        self.metadataService = metadataService
    }

    func scanShelf(image: PlatformImage) async throws -> [SpineScanResult] {
        // 1. Detect spine boundaries
        let rects = try detector.detect(in: image)
        guard !rects.isEmpty else {
            throw SpineDetectionError.noSpinesDetected
        }

        // 2. Crop and recognize each spine
        var spinesWithRecognition: [(cgImage: CGImage, recognition: SpineRecognition, rect: CGRect)] = []
        let imgWidth = CGFloat(image.cgImage?.width ?? 1)
        for rect in rects {
            let spinePixelWidth = rect.width * imgWidth
            let padding: CGFloat = spinePixelWidth < 200 ? 0.3 : 0
            guard let croppedImage = ImageProcessing.crop(image, to: rect, horizontalPadding: padding) else { continue }

            guard let recognition = try? await recognizer.recognize(in: croppedImage) else { continue }

            let query = recognition.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.count >= 3 {
                spinesWithRecognition.append((croppedImage, recognition, rect))
            }
        }

        guard !spinesWithRecognition.isEmpty else {
            throw SpineDetectionError.noSpinesDetected
        }

        let imageWidth = Int(image.size.width * image.scale)
        let imageHeight = Int(image.size.height * image.scale)

        // 3. Look up metadata in parallel, preserving left-to-right order
        return await withTaskGroup(of: (Int, SpineScanResult).self, returning: [SpineScanResult].self) { group in
            for (index, spine) in spinesWithRecognition.enumerated() {
                group.addTask {
                    let query = String(spine.recognition.searchQuery.prefix(60))
                    let ocrContext = spine.recognition.fullText
                    let startTime = ContinuousClock.now
                    var match: BookSearchResult?
                    var metadataError: String?
                    do {
                        match = try await metadataService.search(query: query, ocrContext: ocrContext).first
                    } catch {
                        metadataError = error.localizedDescription
                    }
                    let elapsed = ContinuousClock.now - startTime
                    let elapsedMs = Int(elapsed.components.seconds * 1000)
                        + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)

                    let debug = SpineDebugInfo(
                        spineRect: spine.rect,
                        spinePixelWidth: Int(spine.rect.width * CGFloat(imageWidth)),
                        spinePixelHeight: Int(spine.rect.height * CGFloat(imageHeight)),
                        searchQuery: query,
                        observations: spine.recognition.observations,
                        processingTimeMs: elapsedMs,
                        metadataError: metadataError
                    )

                    let confidence: MatchConfidence
                    if let match {
                        let fuzzyScore = FuzzyMatcher.score(result: match, ocrText: spine.recognition.fullText)
                        if fuzzyScore >= 50 { confidence = .high }
                        else if fuzzyScore >= 20 { confidence = .medium }
                        else { confidence = .low }
                    } else {
                        confidence = .low
                    }

                    let result = SpineScanResult(
                        id: UUID(),
                        spineImage: spine.cgImage,
                        rawOCRText: spine.recognition.fullText,
                        metadataMatch: match,
                        confidence: confidence,
                        debug: debug
                    )
                    return (index, result)
                }
            }

            var indexed: [(Int, SpineScanResult)] = []
            for await pair in group {
                indexed.append(pair)
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}

// MARK: - SteppedSpineDetectionService

extension SpineDetectionServiceImpl: SteppedSpineDetectionService {

    func detectSpines(in image: PlatformImage) throws -> [CGRect] {
        try detector.detect(in: image)
    }

    func ocrSpine(in image: PlatformImage, rect: CGRect) async throws -> SpineOCROutput? {
        let spinePixelWidth = rect.width * CGFloat(image.cgImage?.width ?? 1)
        let padding: CGFloat = spinePixelWidth < 200 ? 0.3 : 0
        guard let croppedImage = ImageProcessing.crop(image, to: rect, horizontalPadding: padding) else { return nil }

        guard let recognition = try await recognizer.recognize(in: croppedImage) else { return nil }
        let query = recognition.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 3 else { return nil }

        return SpineOCROutput(
            cgImage: croppedImage,
            searchQuery: recognition.searchQuery,
            allText: recognition.fullText,
            observationDetails: recognition.observations,
            normalizedRect: rect
        )
    }

    func lookupMetadata(for output: SpineOCROutput, in image: PlatformImage, rect: CGRect) async throws -> SpineScanResult {
        let imageWidth = Int(image.size.width * image.scale)
        let imageHeight = Int(image.size.height * image.scale)
        let query = String(output.searchQuery.prefix(60))
        let ocrContext = output.allText

        let startTime = ContinuousClock.now
        var match: BookSearchResult?
        var metadataError: String?
        do {
            match = try await metadataService.search(query: query, ocrContext: ocrContext).first
        } catch {
            metadataError = error.localizedDescription
        }
        let elapsed = ContinuousClock.now - startTime
        let elapsedMs = Int(elapsed.components.seconds * 1000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)

        let debug = SpineDebugInfo(
            spineRect: rect,
            spinePixelWidth: Int(rect.width * CGFloat(imageWidth)),
            spinePixelHeight: Int(rect.height * CGFloat(imageHeight)),
            searchQuery: query,
            observations: output.observationDetails,
            processingTimeMs: elapsedMs,
            metadataError: metadataError
        )

        let confidence: MatchConfidence
        if let match {
            let fuzzyScore = FuzzyMatcher.score(result: match, ocrText: output.allText)
            if fuzzyScore >= 50 { confidence = .high }
            else if fuzzyScore >= 20 { confidence = .medium }
            else { confidence = .low }
        } else {
            confidence = .low
        }

        return SpineScanResult(
            id: UUID(),
            spineImage: output.cgImage,
            rawOCRText: output.allText,
            metadataMatch: match,
            confidence: confidence,
            debug: debug
        )
    }
}
