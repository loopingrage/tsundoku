import CoreImage

enum ImageProcessing {

    // MARK: - Preprocessing

    /// Boost contrast, desaturate, and apply edge detection for spine boundary detection.
    static func preprocessForSpineDetection(_ image: PlatformImage) -> CIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Desaturate to grayscale
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.5
        ])

        // Sobel-X edge detection to highlight vertical edges (spine boundaries)
        let edges = grayscale.applyingFilter("CIEdges", parameters: [
            kCIInputIntensityKey: 5.0
        ])

        return edges
    }

    // MARK: - Column Projection Profile

    /// Render the edge image to a pixel buffer and sum each column's grayscale intensity.
    /// Returns an array of length equal to the image's pixel width.
    static func computeColumnSums(from edgeImage: CIImage, context: CIContext = CIContext()) -> [Float] {
        let extent = edgeImage.extent
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return [] }

        // Render to 8-bit grayscale buffer
        var pixelData = [UInt8](repeating: 0, count: width * height)
        context.render(
            edgeImage,
            toBitmap: &pixelData,
            rowBytes: width,
            bounds: extent,
            format: .L8,
            colorSpace: CGColorSpaceCreateDeviceGray()
        )

        // Sum each column
        var columnSums = [Float](repeating: 0, count: width)
        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width {
                columnSums[x] += Float(pixelData[rowOffset + x])
            }
        }

        return columnSums
    }

    // MARK: - Peak Detection

    /// Find local maxima in a 1D signal that exceed a threshold and are separated by at least minPeakDistance.
    static func findPeaks(in profile: [Float], minPeakDistance: Int, threshold: Float) -> [Int] {
        guard profile.count >= 3 else { return [] }

        // Find all local maxima above threshold
        var candidates: [(index: Int, value: Float)] = []
        for i in 1..<(profile.count - 1) {
            if profile[i] > profile[i - 1] && profile[i] > profile[i + 1] && profile[i] >= threshold {
                candidates.append((i, profile[i]))
            }
        }

        // Sort by descending value (greedy: keep strongest peaks first)
        candidates.sort { $0.value > $1.value }

        // Greedily select peaks respecting minimum distance
        var selected: [Int] = []
        for candidate in candidates {
            let tooClose = selected.contains { abs($0 - candidate.index) < minPeakDistance }
            if !tooClose {
                selected.append(candidate.index)
            }
        }

        // Return sorted left-to-right
        return selected.sorted()
    }

    // MARK: - Cropping

    /// Crop a PlatformImage to a normalized rect (0...1 coordinate space, top-left origin) and return a CGImage.
    /// When horizontalPadding > 0, extends the crop by that fraction of the spine width on each side (clamped to image bounds).
    static func crop(_ image: PlatformImage, to normalizedRect: CGRect, horizontalPadding: CGFloat = 0) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        let fullWidth = CGFloat(cgImage.width)
        let fullHeight = CGFloat(cgImage.height)

        var rect = normalizedRect
        if horizontalPadding > 0 {
            let padAmount = rect.width * horizontalPadding
            rect = CGRect(
                x: max(0, rect.origin.x - padAmount),
                y: rect.origin.y,
                width: min(1.0 - max(0, rect.origin.x - padAmount), rect.width + padAmount * 2),
                height: rect.height
            )
        }

        let pixelRect = CGRect(
            x: rect.origin.x * fullWidth,
            y: rect.origin.y * fullHeight,
            width: rect.width * fullWidth,
            height: rect.height * fullHeight
        ).integral

        return cgImage.cropping(to: pixelRect)
    }
}
