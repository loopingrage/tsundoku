import Foundation

struct BookMetadataServiceImpl: BookMetadataService {
    let primary: BookMetadataService
    let fallback: BookMetadataService

    init(
        primary: BookMetadataService = GoogleBooksService(),
        fallback: BookMetadataService = OpenLibraryService()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func search(query: String) async throws -> [BookSearchResult] {
        do {
            return try await primary.search(query: query)
        } catch {
            return try await fallback.search(query: query)
        }
    }

    func lookup(isbn: String) async throws -> BookSearchResult {
        do {
            return try await primary.lookup(isbn: isbn)
        } catch {
            return try await fallback.lookup(isbn: isbn)
        }
    }
}
