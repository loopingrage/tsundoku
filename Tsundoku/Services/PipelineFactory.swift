import Foundation

enum PipelineFactory {
    static func makeService(
        pipeline: DetectionPipeline,
        recognizerOverride: SpineRecognizer? = nil,
        metadataService: BookMetadataService = BookMetadataServiceImpl()
    ) throws -> SpineDetectionServiceImpl {
        switch pipeline {
        case .classical:
            return SpineDetectionServiceImpl(
                recognizer: recognizerOverride ?? VisionOCRRecognizer(),
                metadataService: metadataService
            )
        case .yolo:
            return SpineDetectionServiceImpl(
                detector: try YOLOSpineDetector(),
                recognizer: recognizerOverride ?? VLMSpineRecognizer(),
                metadataService: metadataService
            )
        case .fastsam:
            return SpineDetectionServiceImpl(
                detector: try FastSAMSpineDetector(),
                recognizer: recognizerOverride ?? VisionOCRRecognizer(),
                metadataService: metadataService
            )
        }
    }
}
