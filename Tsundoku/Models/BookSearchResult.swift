import Foundation

enum BookDataSource: String, Sendable {
    case googleBooks = "Google Books"
    case openLibrary = "Open Library"
}

struct BookSearchResult: Identifiable, Sendable {
    let id: String
    let title: String
    let authors: [String]
    let description: String
    let categories: [String]
    let pageCount: Int?
    let publishedYear: String?
    let isbn10: String?
    let isbn13: String?
    let coverImageURL: String?
    let coverThumbnailURL: String?
    let source: BookDataSource

    func toBook() -> Book {
        Book(
            title: title,
            authors: authors,
            bookDescription: description,
            categories: categories,
            pageCount: pageCount,
            publishedYear: publishedYear,
            isbn10: isbn10,
            isbn13: isbn13,
            coverImageURL: coverImageURL,
            coverThumbnailURL: coverThumbnailURL,
            source: source.rawValue
        )
    }
}
