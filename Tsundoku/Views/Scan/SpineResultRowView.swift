import SwiftUI

struct SpineResultRowView: View {
    let result: SpineScanResult
    let isSaved: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onSearch: () -> Void

    @State private var showingFullImage = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            imageView
            detailsView
            Spacer()
            actionButtons
        }
        .padding(.vertical, 4)
    }

    // MARK: - Image (cover preferred, spine fallback)

    @ViewBuilder
    private var imageView: some View {
        if let urlString = result.metadataMatch?.coverThumbnailURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                default:
                    spineImageButton
                }
            }
        } else {
            spineImageButton
        }
    }

    private var spineImageButton: some View {
        Button {
            showingFullImage = true
        } label: {
            Image(decorative: result.spineImage, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingFullImage) {
            SpineImageFullScreenView(cgImage: result.spineImage)
        }
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsView: some View {
        if let match = result.metadataMatch {
            matchedDetailsView(match: match)
        } else {
            unmatchedDetailsView
        }
    }

    private func matchedDetailsView(match: BookSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(match.title)
                .font(.headline)
                .lineLimit(2)

            if !match.authors.isEmpty {
                Text(match.authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                if let year = match.publishedYear {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(match.source.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
            }
        }
    }

    private var unmatchedDetailsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No match found")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(result.rawOCRText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(3)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                onSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if result.metadataMatch != nil {
                Button {
                    if isSaved {
                        onRemove()
                    } else {
                        onAdd()
                    }
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isSaved ? .green : .accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
