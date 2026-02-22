import SwiftUI

struct SpineScanDetailView: View {
    let result: SpineScanResult
    let index: Int

    @State private var showingFullImage = false

    var body: some View {
        List {
            spineImageSection
            ocrObservationsSection
            searchQuerySection
            metadataMatchSection
            segmentationSection
            timingSection
        }
        .listStyle(.grouped)
        .navigationTitle("Spine #\(index + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Spine Image

    private var spineImageSection: some View {
        Section("Cropped Spine Image") {
            HStack {
                Spacer()
                Button {
                    showingFullImage = true
                } label: {
                    Image(decorative: result.spineImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .fullScreenCover(isPresented: $showingFullImage) {
                    SpineImageFullScreenView(cgImage: result.spineImage)
                }
                Spacer()
            }
            LabeledContent("Crop Size") {
                Text("\(result.spineImage.width) x \(result.spineImage.height) px")
                    .monospacedDigit()
            }
        }
    }

    // MARK: - OCR Observations

    private var ocrObservationsSection: some View {
        Section("OCR Observations (\(result.debug.observations.count))") {
            if result.debug.observations.isEmpty {
                Text("No text detected")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(result.debug.observations.enumerated()), id: \.offset) { idx, obs in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(obs.text)
                                .font(.body.monospaced())
                            Spacer()
                            if obs.isSearchCandidate {
                                Text("QUERY")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 16) {
                            Label(String(format: "%.1f%%", obs.confidence * 100), systemImage: "checkmark.seal")
                            Label(String(format: "%.4f", obs.boundingBoxArea), systemImage: "rectangle.dashed")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("bbox: (\(f(obs.boundingBox.origin.x)), \(f(obs.boundingBox.origin.y)), \(f(obs.boundingBox.width)), \(f(obs.boundingBox.height)))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Search Query

    private var searchQuerySection: some View {
        Section("Metadata Search") {
            LabeledContent("Query Sent") {
                Text(result.debug.searchQuery)
                    .font(.body.monospaced())
                    .foregroundStyle(.blue)
            }
            LabeledContent("Query Length") {
                Text("\(result.debug.searchQuery.count) chars")
                    .monospacedDigit()
            }
            if let error = result.debug.metadataError {
                LabeledContent("Lookup Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Metadata Match

    private var metadataMatchSection: some View {
        Section("Metadata Match") {
            if let match = result.metadataMatch {
                LabeledContent("Title", value: match.title)
                LabeledContent("Authors", value: match.authors.joined(separator: ", "))
                LabeledContent("Source", value: match.source.rawValue)
                if let year = match.publishedYear {
                    LabeledContent("Year", value: year)
                }
                if let isbn13 = match.isbn13 {
                    LabeledContent("ISBN-13", value: isbn13)
                }
                if let isbn10 = match.isbn10 {
                    LabeledContent("ISBN-10", value: isbn10)
                }
                if let pages = match.pageCount {
                    LabeledContent("Pages") {
                        Text("\(pages)")
                            .monospacedDigit()
                    }
                }
                if !match.categories.isEmpty {
                    LabeledContent("Categories", value: match.categories.joined(separator: ", "))
                }
                if !match.description.isEmpty {
                    DisclosureGroup("Description") {
                        Text(match.description)
                            .font(.caption)
                    }
                }
                LabeledContent("Result ID", value: match.id)
                if let coverURL = match.coverThumbnailURL {
                    LabeledContent("Cover URL") {
                        Text(coverURL)
                            .font(.caption2.monospaced())
                            .lineLimit(2)
                    }
                }
            } else {
                Text("No match found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Segmentation

    private var segmentationSection: some View {
        Section("Segmentation") {
            let r = result.debug.spineRect
            LabeledContent("Normalized Rect") {
                Text("(\(f(r.origin.x)), \(f(r.origin.y)), \(f(r.width)), \(f(r.height)))")
                    .font(.caption.monospaced())
            }
            LabeledContent("Pixel Size") {
                Text("\(result.debug.spinePixelWidth) x \(result.debug.spinePixelHeight) px")
                    .monospacedDigit()
            }
            LabeledContent("Width %") {
                Text(String(format: "%.1f%%", result.debug.spineRect.width * 100))
                    .monospacedDigit()
            }
            LabeledContent("Height %") {
                Text(String(format: "%.1f%%", result.debug.spineRect.height * 100))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Timing

    private var timingSection: some View {
        Section("Timing") {
            LabeledContent("Metadata Lookup") {
                Text("\(result.debug.processingTimeMs) ms")
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Helpers

    private func f(_ value: CGFloat) -> String {
        String(format: "%.3f", value)
    }
}
