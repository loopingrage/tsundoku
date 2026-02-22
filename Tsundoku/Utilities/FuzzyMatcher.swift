import Foundation

/// Scores BookSearchResult candidates against raw OCR text to find the best match.
enum FuzzyMatcher {

    /// Score a single search result against the full OCR text from a spine.
    /// Higher score = better match. Returns 0 if no meaningful overlap.
    static func score(result: BookSearchResult, ocrText: String) -> Double {
        let ocrLower = ocrText.lowercased()
        var totalScore = 0.0

        // 1. Title word overlap (primary signal)
        let titleWords = tokenize(result.title)
        let matchingTitleChars = titleWords
            .filter { $0.count >= 3 }
            .filter { ocrLower.contains($0.lowercased()) }
            .reduce(0) { $0 + $1.count }

        let totalTitleChars = titleWords
            .filter { $0.count >= 3 }
            .reduce(0) { $0 + $1.count }

        if totalTitleChars > 0 {
            // Weight by fraction of title characters matched, scaled 0-60
            totalScore += Double(matchingTitleChars) / Double(totalTitleChars) * 60.0
        }

        // 2. Author match (secondary signal)
        let authorScore = scoreAuthors(result.authors, ocrText: ocrLower)
        totalScore += authorScore * 30.0

        // 3. Short-title penalty: single-word titles under 6 chars are too generic
        if titleWords.count == 1, (titleWords.first?.count ?? 0) < 6 {
            totalScore *= 0.7
        }

        // 4. Exact substring bonus: if a significant portion of the title appears as a contiguous substring
        let titleLower = result.title.lowercased()
        if titleLower.count >= 6, ocrLower.contains(titleLower) {
            totalScore += 10.0
        }

        return totalScore
    }

    /// Re-rank an array of search results against OCR text. Returns results sorted by score descending.
    static func rerank(results: [BookSearchResult], ocrText: String) -> [BookSearchResult] {
        guard !ocrText.isEmpty, results.count > 1 else { return results }

        let scored = results.map { (result: $0, score: score(result: $0, ocrText: ocrText)) }
        return scored.sorted { $0.score > $1.score }.map(\.result)
    }

    // MARK: - Private

    private static func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: CharacterSet.alphanumerics.inverted) }
            .filter { !$0.isEmpty }
    }

    private static func scoreAuthors(_ authors: [String], ocrText: String) -> Double {
        guard !authors.isEmpty else { return 0 }

        var bestAuthorScore = 0.0
        for author in authors {
            let fragments = tokenize(author).filter { $0.count >= 3 }
            guard !fragments.isEmpty else { continue }

            let matched = fragments.filter { ocrText.contains($0.lowercased()) }.count
            let ratio = Double(matched) / Double(fragments.count)
            bestAuthorScore = max(bestAuthorScore, ratio)
        }
        return bestAuthorScore
    }
}
