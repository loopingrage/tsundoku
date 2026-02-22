import Foundation

enum BookMetadataError: Error, LocalizedError {
    case noResults
    case networkError(Error)
    case decodingError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No books found matching your search."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid search URL."
        }
    }
}

protocol BookMetadataService: Sendable {
    func search(query: String, ocrContext: String?) async throws -> [BookSearchResult]
    func lookup(isbn: String) async throws -> BookSearchResult
}

extension BookMetadataService {
    func search(query: String) async throws -> [BookSearchResult] {
        try await search(query: query, ocrContext: nil)
    }
}
