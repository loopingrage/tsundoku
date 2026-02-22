import Foundation

struct OpenLibraryService: BookMetadataService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, ocrContext: String? = nil) async throws -> [BookSearchResult] {
        guard var components = URLComponents(string: "https://openlibrary.org/search.json") else {
            throw BookMetadataError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "fields", value: "key,title,author_name,first_publish_year,isbn,subject,cover_i"),
        ]

        guard let url = components.url else {
            throw BookMetadataError.invalidURL
        }

        let response: OpenLibrarySearchResponse = try await fetch(url: url)

        guard !response.docs.isEmpty else {
            throw BookMetadataError.noResults
        }

        return response.docs.map { doc in
            mapDoc(doc)
        }
    }

    func lookup(isbn: String) async throws -> BookSearchResult {
        guard let url = URL(string: "https://openlibrary.org/isbn/\(isbn).json") else {
            throw BookMetadataError.invalidURL
        }

        let response: OpenLibraryISBNResponse = try await fetch(url: url)

        let coverURL = response.covers?.first.map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" }
        let thumbURL = response.covers?.first.map { "https://covers.openlibrary.org/b/id/\($0)-S.jpg" }

        let isISBN13 = isbn.count == 13
        return BookSearchResult(
            id: "ol-isbn-\(isbn)",
            title: response.title,
            authors: [],
            description: response.description?.text ?? "",
            categories: response.subjects ?? [],
            pageCount: response.numberOfPages,
            publishedYear: response.publishDate,
            isbn10: isISBN13 ? nil : isbn,
            isbn13: isISBN13 ? isbn : nil,
            coverImageURL: coverURL,
            coverThumbnailURL: thumbURL,
            source: .openLibrary
        )
    }

    // MARK: - Private

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Tsundoku/1.0 (iOS Book Cataloging App)", forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw BookMetadataError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BookMetadataError.decodingError(error)
        }
    }

    private func mapDoc(_ doc: OpenLibraryDoc) -> BookSearchResult {
        let coverURL = doc.coverId.map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" }
        let thumbURL = doc.coverId.map { "https://covers.openlibrary.org/b/id/\($0)-S.jpg" }

        let isbn13 = doc.isbn?.first(where: { $0.count == 13 })
        let isbn10 = doc.isbn?.first(where: { $0.count == 10 })

        let year = doc.firstPublishYear.map { String($0) }

        return BookSearchResult(
            id: doc.key,
            title: doc.title,
            authors: doc.authorName ?? [],
            description: "",
            categories: doc.subject?.prefix(5).map { $0 } ?? [],
            pageCount: nil,
            publishedYear: year,
            isbn10: isbn10,
            isbn13: isbn13,
            coverImageURL: coverURL,
            coverThumbnailURL: thumbURL,
            source: .openLibrary
        )
    }
}
