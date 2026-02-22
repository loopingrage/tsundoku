import Foundation

// MARK: - Google Books API

struct GoogleBooksResponse: Codable {
    let totalItems: Int
    let items: [GoogleBooksVolume]?
}

struct GoogleBooksVolume: Codable {
    let id: String
    let volumeInfo: GoogleBooksVolumeInfo
}

struct GoogleBooksVolumeInfo: Codable {
    let title: String
    let authors: [String]?
    let description: String?
    let categories: [String]?
    let pageCount: Int?
    let publishedDate: String?
    let imageLinks: GoogleBooksImageLinks?
    let industryIdentifiers: [GoogleBooksIdentifier]?
}

struct GoogleBooksImageLinks: Codable {
    let smallThumbnail: String?
    let thumbnail: String?
}

struct GoogleBooksIdentifier: Codable {
    let type: String
    let identifier: String
}

// MARK: - Open Library API

struct OpenLibrarySearchResponse: Codable {
    let numFound: Int
    let docs: [OpenLibraryDoc]
}

struct OpenLibraryDoc: Codable {
    let key: String
    let title: String
    let authorName: [String]?
    let firstPublishYear: Int?
    let isbn: [String]?
    let subject: [String]?
    let coverId: Int?

    enum CodingKeys: String, CodingKey {
        case key, title, isbn, subject
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverId = "cover_i"
    }
}

struct OpenLibraryISBNResponse: Codable {
    let title: String
    let authors: [OpenLibraryAuthorRef]?
    let description: OpenLibraryDescription?
    let covers: [Int]?
    let subjects: [String]?
    let numberOfPages: Int?
    let publishDate: String?

    enum CodingKeys: String, CodingKey {
        case title, authors, description, covers, subjects
        case numberOfPages = "number_of_pages"
        case publishDate = "publish_date"
    }
}

struct OpenLibraryAuthorRef: Codable {
    let key: String
}

enum OpenLibraryDescription: Codable {
    case string(String)
    case object(OpenLibraryDescriptionObject)

    struct OpenLibraryDescriptionObject: Codable {
        let value: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            let obj = try container.decode(OpenLibraryDescriptionObject.self)
            self = .object(obj)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .object(let obj):
            try container.encode(obj)
        }
    }

    var text: String {
        switch self {
        case .string(let value): return value
        case .object(let obj): return obj.value
        }
    }
}
