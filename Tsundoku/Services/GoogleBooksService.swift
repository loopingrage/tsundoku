import Foundation

struct GoogleBooksService: BookMetadataService {
    private let session: URLSession
    private let apiKey: String

    init(session: URLSession = .shared, apiKey: String = Secrets.googleBooksAPIKey) {
        self.session = session
        self.apiKey = apiKey
    }

    func search(query: String, ocrContext: String? = nil) async throws -> [BookSearchResult] {
        guard var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes") else {
            throw BookMetadataError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "10"),
        ]

        if !apiKey.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "key", value: apiKey))
        }

        guard let url = components.url else {
            throw BookMetadataError.invalidURL
        }

        let response: GoogleBooksResponse = try await fetch(url: url)

        guard let items = response.items, !items.isEmpty else {
            throw BookMetadataError.noResults
        }

        return items.map { volume in
            mapVolume(volume)
        }
    }

    func lookup(isbn: String) async throws -> BookSearchResult {
        guard var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes") else {
            throw BookMetadataError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn)"),
        ]

        if !apiKey.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "key", value: apiKey))
        }

        guard let url = components.url else {
            throw BookMetadataError.invalidURL
        }

        let response: GoogleBooksResponse = try await fetch(url: url)

        guard let items = response.items, let first = items.first else {
            throw BookMetadataError.noResults
        }

        return mapVolume(first)
    }

    // MARK: - Private

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch {
            throw BookMetadataError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BookMetadataError.decodingError(error)
        }
    }

    private func mapVolume(_ volume: GoogleBooksVolume) -> BookSearchResult {
        let info = volume.volumeInfo
        let isbn10 = info.industryIdentifiers?.first(where: { $0.type == "ISBN_10" })?.identifier
        let isbn13 = info.industryIdentifiers?.first(where: { $0.type == "ISBN_13" })?.identifier

        // Google Books sometimes returns http:// URLs for covers - upgrade to https
        let thumbnail = info.imageLinks?.thumbnail?.replacingOccurrences(of: "http://", with: "https://")
        let smallThumbnail = info.imageLinks?.smallThumbnail?.replacingOccurrences(of: "http://", with: "https://")

        let description = info.description.map { HTMLStripper.strip($0) } ?? ""

        // Extract year from publishedDate (can be "2011", "2011-01", or "2011-01-15")
        let year = info.publishedDate.map { String($0.prefix(4)) }

        return BookSearchResult(
            id: volume.id,
            title: info.title,
            authors: info.authors ?? [],
            description: description,
            categories: info.categories ?? [],
            pageCount: info.pageCount,
            publishedYear: year,
            isbn10: isbn10,
            isbn13: isbn13,
            coverImageURL: thumbnail,
            coverThumbnailURL: smallThumbnail,
            source: .googleBooks
        )
    }
}
