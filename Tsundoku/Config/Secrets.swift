import Foundation

enum Secrets {
    static var googleBooksAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String ?? ""
    }
}
