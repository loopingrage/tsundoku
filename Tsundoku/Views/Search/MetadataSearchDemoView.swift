import SwiftUI
import SwiftData

struct MetadataSearchDemoView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.results.isEmpty && viewModel.errorMessage == nil && !viewModel.isSearching {
                    ContentUnavailableView(
                        "Search for Books",
                        systemImage: "magnifyingglass",
                        description: Text("Type a book title to search.")
                    )
                }

                if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "book.closed",
                        description: Text(error)
                    )
                }

                ForEach(viewModel.results) { result in
                    SearchResultRowView(result: result) {
                        addBook(result)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Book title...")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.search()
                }
            }
            .overlay {
                if viewModel.isSearching {
                    ProgressView("Searching...")
                }
            }
        }
    }

    private func addBook(_ result: BookSearchResult) {
        let book = result.toBook()
        modelContext.insert(book)
    }
}

@Observable
final class SearchViewModel {
    var query = ""
    var results: [BookSearchResult] = []
    var isSearching = false
    var errorMessage: String?

    private let service: BookMetadataService = BookMetadataServiceImpl()

    @MainActor
    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        results = []

        do {
            results = try await service.search(query: trimmed)
        } catch let error as BookMetadataError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}
