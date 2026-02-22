import CoreGraphics
import CoreML
import Foundation
@preconcurrency import Vision

/// Detects book spines using a YOLO26n CoreML model trained on COCO (class 73 = "book").
/// The model outputs end-to-end detections in [x1, y1, x2, y2, confidence, class_id] format.
struct YOLOSpineDetector: SpineDetector, @unchecked Sendable {

    private static let bookClassId: Float = 73.0
    private static let confidenceThreshold: Float = 0.25
    private static let modelInputSize: CGFloat = 640.0

    private let model: VNCoreMLModel

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let mlModel = try YOLOBookDetector(configuration: config).model
        self.model = try VNCoreMLModel(for: mlModel)
    }

    func detect(in image: PlatformImage) throws -> [CGRect] {
        guard let cgImage = image.cgImage else {
            throw SpineDetectionError.imageConversionFailed
        }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results as? [VNCoreMLFeatureValueObservation],
              let multiArray = results.first?.featureValue.multiArrayValue else {
            return []
        }

        return parseDetections(multiArray, imageWidth: CGFloat(cgImage.width), imageHeight: CGFloat(cgImage.height))
    }

    /// Parse the YOLO26 end-to-end output tensor [1, 300, 6].
    /// Each row: [x1, y1, x2, y2, confidence, class_id] in pixel coords (relative to 640x640 input).
    private func parseDetections(_ multiArray: MLMultiArray, imageWidth: CGFloat, imageHeight: CGFloat) -> [CGRect] {
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count == 3, shape[2] == 6 else { return [] }

        let maxDetections = shape[1]
        let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)

        var rects: [CGRect] = []

        for i in 0..<maxDetections {
            let base = i * 6
            let confidence = pointer[base + 4]
            let classId = pointer[base + 5]

            guard confidence >= Self.confidenceThreshold,
                  classId == Self.bookClassId else { continue }

            // Coordinates are in model input space (640x640), normalize to 0...1
            let x1 = CGFloat(pointer[base + 0]) / Self.modelInputSize
            let y1 = CGFloat(pointer[base + 1]) / Self.modelInputSize
            let x2 = CGFloat(pointer[base + 2]) / Self.modelInputSize
            let y2 = CGFloat(pointer[base + 3]) / Self.modelInputSize

            // Convert to top-left origin CGRect (Vision uses bottom-left, but YOLO xyxy is already top-left)
            let rect = CGRect(
                x: max(0, x1),
                y: max(0, y1),
                width: min(1, x2) - max(0, x1),
                height: min(1, y2) - max(0, y1)
            )

            guard rect.width > 0, rect.height > 0 else { continue }
            rects.append(rect)
        }

        // Sort left-to-right
        return rects.sorted { $0.origin.x < $1.origin.x }
    }
}
