import Foundation

enum DetectionPipeline: String, CaseIterable, Sendable {
    case classical
    case yolo
    case fastsam

    var displayName: String {
        switch self {
        case .classical: return "Classical"
        case .yolo: return "YOLO"
        case .fastsam: return "FastSAM"
        }
    }
}
