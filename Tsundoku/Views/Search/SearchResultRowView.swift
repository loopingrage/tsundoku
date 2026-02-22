import SwiftUI

struct SearchResultRowView: View {
    let result: BookSearchResult
    let isSaved: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Cover thumbnail
            if let urlString = result.coverThumbnailURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        coverPlaceholder
                    default:
                        ProgressView()
                            .frame(width: 50, height: 75)
                    }
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                coverPlaceholder
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                if !result.authors.isEmpty {
                    Text(result.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let year = result.publishedYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(result.source.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Add/remove button
            Button(action: isSaved ? onRemove : onAdd) {
                Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isSaved ? Color.green : Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .frame(width: 50, height: 75)
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }
}
