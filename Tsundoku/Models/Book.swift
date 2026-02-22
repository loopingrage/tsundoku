import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var authors: [String]
    var bookDescription: String
    var categories: [String]
    var pageCount: Int?
    var publishedYear: String?
    var isbn10: String?
    var isbn13: String?
    var coverImageURL: String?
    var coverThumbnailURL: String?
    var dateAdded: Date
    var source: String
    var readingStatus: String

    init(
        id: UUID = UUID(),
        title: String,
        authors: [String] = [],
        bookDescription: String = "",
        categories: [String] = [],
        pageCount: Int? = nil,
        publishedYear: String? = nil,
        isbn10: String? = nil,
        isbn13: String? = nil,
        coverImageURL: String? = nil,
        coverThumbnailURL: String? = nil,
        dateAdded: Date = Date(),
        source: String = "manual",
        readingStatus: String = "unread"
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.bookDescription = bookDescription
        self.categories = categories
        self.pageCount = pageCount
        self.publishedYear = publishedYear
        self.isbn10 = isbn10
        self.isbn13 = isbn13
        self.coverImageURL = coverImageURL
        self.coverThumbnailURL = coverThumbnailURL
        self.dateAdded = dateAdded
        self.source = source
        self.readingStatus = readingStatus
    }
}
