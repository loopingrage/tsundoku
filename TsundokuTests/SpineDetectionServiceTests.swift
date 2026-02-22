import Testing
import UIKit
@testable import Tsundoku

// MARK: - findPeaks Tests

struct FindPeaksTests {

    @Test func findsPeaksInSimpleProfile() {
        // Profile with clear peaks at indices 2, 6, 10
        let profile: [Float] = [0, 1, 5, 1, 0, 1, 8, 1, 0, 1, 6, 1, 0]
        let peaks = ImageProcessing.findPeaks(in: profile, minPeakDistance: 2, threshold: 3.0)
        #expect(peaks == [2, 6, 10])
    }

    @Test func respectsMinPeakDistance() {
        // Two peaks close together — only the stronger one should survive
        let profile: [Float] = [0, 1, 10, 1, 9, 1, 0]
        let peaks = ImageProcessing.findPeaks(in: profile, minPeakDistance: 3, threshold: 5.0)
        // Peak at 2 (value 10) is stronger, so 4 (value 9) is suppressed
        #expect(peaks == [2])
    }

    @Test func respectsThreshold() {
        // All peaks below threshold should be ignored
        let profile: [Float] = [0, 1, 3, 1, 0, 1, 2, 1, 0]
        let peaks = ImageProcessing.findPeaks(in: profile, minPeakDistance: 1, threshold: 5.0)
        #expect(peaks.isEmpty)
    }

    @Test func returnsEmptyForShortProfile() {
        let peaks = ImageProcessing.findPeaks(in: [1.0, 2.0], minPeakDistance: 1, threshold: 0.0)
        #expect(peaks.isEmpty)
    }

    @Test func returnsEmptyForEmptyProfile() {
        let peaks = ImageProcessing.findPeaks(in: [], minPeakDistance: 1, threshold: 0.0)
        #expect(peaks.isEmpty)
    }

    @Test func returnsPeaksSortedLeftToRight() {
        // Stronger peak is on the right, but results should still be sorted by index
        let profile: [Float] = [0, 1, 5, 1, 0, 1, 10, 1, 0]
        let peaks = ImageProcessing.findPeaks(in: profile, minPeakDistance: 2, threshold: 3.0)
        #expect(peaks == [2, 6])
    }

    @Test func handlesPlateauNotAsPeak() {
        // A plateau (equal neighbors) should NOT be detected as a peak
        let profile: [Float] = [0, 5, 5, 5, 0]
        let peaks = ImageProcessing.findPeaks(in: profile, minPeakDistance: 1, threshold: 1.0)
        #expect(peaks.isEmpty)
    }
}

// MARK: - Mock SpineDetectionService

struct MockSpineDetectionService: SpineDetectionService {
    var resultToReturn: Result<[SpineScanResult], Error>

    func scanShelf(image: UIImage) async throws -> [SpineScanResult] {
        try resultToReturn.get()
    }
}

// MARK: - ViewModel Tests

@MainActor
struct ShelfScanViewModelTests {

    @Test func initialStateIsIdle() {
        let viewModel = ShelfScanViewModel()
        guard case .idle = viewModel.scanState else {
            Issue.record("Expected idle state, got \(viewModel.scanState)")
            return
        }
    }

    @Test func resetReturnToIdle() {
        let viewModel = ShelfScanViewModel()
        viewModel.savedIDs.insert(UUID())
        viewModel.scanState = .error("test")
        viewModel.reset()

        guard case .idle = viewModel.scanState else {
            Issue.record("Expected idle state after reset")
            return
        }
        #expect(viewModel.savedIDs.isEmpty)
        #expect(viewModel.selectedPhotoItem == nil)
    }
}
