import SwiftUI
import SwiftData

struct MetadataSearchDemoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var appNav
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
                    SearchResultRowView(
                        result: result,
                        isSaved: viewModel.savedIDs.contains(result.id),
                        onAdd: { addBook(result) },
                        onRemove: { removeBook(result) }
                    )
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
            .onChange(of: appNav.searchQuery) { _, newQuery in
                guard let query = newQuery, !query.isEmpty else { return }
                viewModel.query = query
                appNav.searchQuery = nil
                Task {
                    await viewModel.search()
                }
            }
        }
    }

    private func addBook(_ result: BookSearchResult) {
        // Prevent duplicates by checking title + authors
        let title = result.title
        let authors = result.authors
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate {
            $0.title == title && $0.authors == authors
        })
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existing == 0 else {
            viewModel.savedIDs.insert(result.id)
            return
        }

        let book = result.toBook()
        modelContext.insert(book)
        viewModel.savedIDs.insert(result.id)
    }

    private func removeBook(_ result: BookSearchResult) {
        let title = result.title
        let authors = result.authors
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate {
            $0.title == title && $0.authors == authors
        })
        if let books = try? modelContext.fetch(descriptor) {
            for book in books {
                modelContext.delete(book)
            }
        }
        viewModel.savedIDs.remove(result.id)
    }
}

@Observable
final class SearchViewModel {
    var query = ""
    var results: [BookSearchResult] = []
    var isSearching = false
    var errorMessage: String?
    var savedIDs: Set<String> = []

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
