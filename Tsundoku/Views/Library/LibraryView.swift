import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "No Books Yet",
                        systemImage: "books.vertical",
                        description: Text("Search for books and tap + to add them to your library.")
                    )
                } else {
                    List {
                        ForEach(books) { book in
                            HStack(alignment: .top, spacing: 12) {
                                // Cover
                                if let urlString = book.coverThumbnailURL, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        default:
                                            bookPlaceholder
                                        }
                                    }
                                    .frame(width: 50, height: 75)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    bookPlaceholder
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.headline)
                                        .lineLimit(2)

                                    if !book.authors.isEmpty {
                                        Text(book.authors.joined(separator: ", "))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    if let year = book.publishedYear {
                                        Text(year)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteBooks)
                    }
                }
            }
            .navigationTitle("Library")
        }
    }

    private var bookPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .frame(width: 50, height: 75)
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(books[index])
        }
    }
}
