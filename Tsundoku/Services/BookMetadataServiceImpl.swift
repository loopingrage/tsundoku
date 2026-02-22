import Foundation

struct BookMetadataServiceImpl: BookMetadataService {
    let primary: BookMetadataService
    let fallback: BookMetadataService

    init(
        primary: BookMetadataService = OpenLibraryService(),
        fallback: BookMetadataService = OpenLibraryService()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func search(query: String, ocrContext: String? = nil) async throws -> [BookSearchResult] {
        // Clean the query: remove punctuation, normalize whitespace
        let cleaned = query
            .replacingOccurrences(of: "[^a-zA-Z0-9' ]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let queryToUse = cleaned.isEmpty ? query : cleaned

        // Strategy: try full query on each provider, then retry with simplified query
        // (remove short words that are likely OCR noise)
        let strategies = buildQueryStrategies(queryToUse)

        for strategy in strategies {
            do {
                let results = try await primary.search(query: strategy)
                if !results.isEmpty {
                    return rerank(results, ocrContext: ocrContext)
                }
            } catch { /* continue to next strategy */ }

            do {
                let results = try await fallback.search(query: strategy)
                if !results.isEmpty {
                    return rerank(results, ocrContext: ocrContext)
                }
            } catch { /* continue to next strategy */ }
        }

        throw BookMetadataError.noResults
    }

    private func rerank(_ results: [BookSearchResult], ocrContext: String?) -> [BookSearchResult] {
        guard let ocrContext, !ocrContext.isEmpty else { return results }
        return FuzzyMatcher.rerank(results: results, ocrText: ocrContext)
    }

    private func buildQueryStrategies(_ query: String) -> [String] {
        var strategies = [query]

        // Strategy 2: Remove short words (likely OCR noise like "ord", "oN", etc.)
        let longWords = query.components(separatedBy: " ").filter { $0.count >= 4 }
        let longOnly = longWords.joined(separator: " ")
        if longOnly != query && !longOnly.isEmpty {
            strategies.append(longOnly)
        }

        return strategies
    }

    func lookup(isbn: String) async throws -> BookSearchResult {
        do {
            return try await primary.lookup(isbn: isbn)
        } catch {
            return try await fallback.lookup(isbn: isbn)
        }
    }
}
