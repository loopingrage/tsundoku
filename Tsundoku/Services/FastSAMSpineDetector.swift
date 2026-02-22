import CoreGraphics
import CoreML
import Foundation

/// Detects book spines using FastSAM-s instance segmentation in "everything" mode.
/// Segments all visually distinct regions, then filters for spine-like aspect ratios.
///
/// Model output: `var_1057` [1, 37, 8400] — 8400 candidates, each with
///   [cx, cy, w, h, confidence, 32 mask coefficients]
/// We only use bounding boxes (not masks) since SpineDetector returns [CGRect].
struct FastSAMSpineDetector: SpineDetector, @unchecked Sendable {

    private static let confidenceThreshold: Float = 0.25
    private static let nmsIoUThreshold: CGFloat = 0.5
    private static let modelInputSize: CGFloat = 640.0

    // Spine shape filters
    private static let minimumAspectRatio: CGFloat = 1.5  // height/width
    private static let minimumHeightFraction: CGFloat = 0.10
    private static let maximumWidthFraction: CGFloat = 0.25

    private let model: MLModel

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        self.model = try FastSAMBookSegmenter(configuration: config).model
    }

    func detect(in image: PlatformImage) throws -> [CGRect] {
        guard let cgImage = image.cgImage else {
            throw SpineDetectionError.imageConversionFailed
        }

        // Prepare input as pixel buffer
        let input = try FastSAMBookSegmenterInput(imageWith: cgImage)
        let output = try model.prediction(from: input)

        guard let detections = output.featureValue(for: "var_1057")?.multiArrayValue else {
            return []
        }

        let candidates = parseDetections(detections)
        let afterNMS = applyNMS(candidates)
        let spines = filterSpines(afterNMS)

        return spines.sorted { $0.origin.x < $1.origin.x }
    }

    // MARK: - Detection Parsing

    private struct Detection {
        let rect: CGRect      // normalized 0...1
        let confidence: Float
    }

    /// Parse [1, 37, 8400] tensor. Dim 0 = batch, Dim 1 = features, Dim 2 = candidates.
    /// Features: [cx, cy, w, h, confidence, 32 mask_coeffs]
    private func parseDetections(_ multiArray: MLMultiArray) -> [Detection] {
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count == 3, shape[1] == 37 else { return [] }

        let numCandidates = shape[2]  // 8400
        // shape[1] = 37: 4 bbox + 1 confidence + 32 mask coefficients
        let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)

        // Data layout: [1, 37, 8400] — feature-major.
        // pointer[f * numCandidates + i] = feature f of candidate i
        var detections: [Detection] = []

        for i in 0..<numCandidates {
            let confidence = pointer[4 * numCandidates + i]
            guard confidence >= Self.confidenceThreshold else { continue }

            let cx = CGFloat(pointer[0 * numCandidates + i]) / Self.modelInputSize
            let cy = CGFloat(pointer[1 * numCandidates + i]) / Self.modelInputSize
            let w  = CGFloat(pointer[2 * numCandidates + i]) / Self.modelInputSize
            let h  = CGFloat(pointer[3 * numCandidates + i]) / Self.modelInputSize

            let rect = CGRect(
                x: max(0, cx - w / 2),
                y: max(0, cy - h / 2),
                width: min(1, w),
                height: min(1, h)
            )

            guard rect.width > 0, rect.height > 0 else { continue }
            detections.append(Detection(rect: rect, confidence: confidence))
        }

        // Sort by confidence descending for NMS
        return detections.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - NMS

    private func applyNMS(_ detections: [Detection]) -> [Detection] {
        var kept: [Detection] = []
        for detection in detections {
            let isDuplicate = kept.contains { existing in
                iou(existing.rect, detection.rect) > Self.nmsIoUThreshold
            }
            if !isDuplicate {
                kept.append(detection)
            }
        }
        return kept
    }

    // MARK: - Spine Filtering

    private func filterSpines(_ detections: [Detection]) -> [CGRect] {
        detections.compactMap { detection in
            let rect = detection.rect
            let aspectRatio = rect.height / rect.width

            guard aspectRatio >= Self.minimumAspectRatio,
                  rect.height >= Self.minimumHeightFraction,
                  rect.width <= Self.maximumWidthFraction else {
                return nil
            }

            return rect
        }
    }

    // MARK: - IoU

    private func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }
}
