import Testing
@testable import Tsundoku

// MARK: - Mock Services

struct MockSuccessService: BookMetadataService {
    let results: [BookSearchResult]

    func search(query: String, ocrContext: String?) async throws -> [BookSearchResult] {
        results
    }

    func lookup(isbn: String) async throws -> BookSearchResult {
        guard let first = results.first else {
            throw BookMetadataError.noResults
        }
        return first
    }
}

struct MockFailureService: BookMetadataService {
    func search(query: String, ocrContext: String?) async throws -> [BookSearchResult] {
        throw BookMetadataError.noResults
    }

    func lookup(isbn: String) async throws -> BookSearchResult {
        throw BookMetadataError.noResults
    }
}

// MARK: - Test Data

private let sampleResult = BookSearchResult(
    id: "test-1",
    title: "Test Book",
    authors: ["Test Author"],
    description: "A test book",
    categories: ["Fiction"],
    pageCount: 200,
    publishedYear: "2023",
    isbn10: "0123456789",
    isbn13: "9780123456789",
    coverImageURL: nil,
    coverThumbnailURL: nil,
    source: .googleBooks
)

private let fallbackResult = BookSearchResult(
    id: "ol-1",
    title: "Fallback Book",
    authors: ["Fallback Author"],
    description: "",
    categories: ["Non-Fiction"],
    pageCount: nil,
    publishedYear: "2020",
    isbn10: nil,
    isbn13: nil,
    coverImageURL: nil,
    coverThumbnailURL: nil,
    source: .openLibrary
)

// MARK: - Tests

@Suite("BookMetadataServiceImpl")
struct BookMetadataServiceImplTests {

    @Test("Google success returns results without fallback")
    func googleSuccessNoFallback() async throws {
        let service = BookMetadataServiceImpl(
            primary: MockSuccessService(results: [sampleResult]),
            fallback: MockFailureService()
        )

        let results = try await service.search(query: "Test")
        #expect(results.count == 1)
        #expect(results[0].title == "Test Book")
        #expect(results[0].source == .googleBooks)
    }

    @Test("Google failure falls back to Open Library")
    func fallbackOnGoogleFailure() async throws {
        let service = BookMetadataServiceImpl(
            primary: MockFailureService(),
            fallback: MockSuccessService(results: [fallbackResult])
        )

        let results = try await service.search(query: "Fallback")
        #expect(results.count == 1)
        #expect(results[0].title == "Fallback Book")
        #expect(results[0].source == .openLibrary)
    }

    @Test("Both services fail throws error")
    func bothFail() async {
        let service = BookMetadataServiceImpl(
            primary: MockFailureService(),
            fallback: MockFailureService()
        )

        await #expect(throws: BookMetadataError.self) {
            _ = try await service.search(query: "Nothing")
        }
    }

    @Test("ISBN lookup falls back on primary failure")
    func isbnLookupFallback() async throws {
        let service = BookMetadataServiceImpl(
            primary: MockFailureService(),
            fallback: MockSuccessService(results: [fallbackResult])
        )

        let result = try await service.lookup(isbn: "9780123456789")
        #expect(result.title == "Fallback Book")
    }

    @Test("BookSearchResult converts to Book correctly")
    func toBookConversion() {
        let book = sampleResult.toBook()
        #expect(book.title == "Test Book")
        #expect(book.authors == ["Test Author"])
        #expect(book.bookDescription == "A test book")
        #expect(book.isbn13 == "9780123456789")
        #expect(book.source == "Google Books")
        #expect(book.readingStatus == "unread")
    }
}

@Suite("HTMLStripper")
struct HTMLStripperTests {

    @Test("Strips basic HTML tags")
    func stripBasicTags() {
        let input = "<p>Hello <b>world</b></p>"
        let result = HTMLStripper.strip(input)
        #expect(result == "Hello world")
    }

    @Test("Decodes HTML entities")
    func decodeEntities() {
        let input = "Tom &amp; Jerry &lt;3&gt;"
        let result = HTMLStripper.strip(input)
        #expect(result == "Tom & Jerry <3>")
    }

    @Test("Returns plain text unchanged")
    func plainTextUnchanged() {
        let input = "Just plain text"
        let result = HTMLStripper.strip(input)
        #expect(result == "Just plain text")
    }

    @Test("Handles br tags as newlines")
    func brTagsToNewlines() {
        let input = "Line one<br>Line two<br/>Line three"
        let result = HTMLStripper.strip(input)
        #expect(result.contains("Line one"))
        #expect(result.contains("Line two"))
        #expect(result.contains("Line three"))
    }
}
