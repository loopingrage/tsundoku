import Foundation

enum Secrets {
    static var googleBooksAPIKey: String {
        if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String, !bundleKey.isEmpty {
            return bundleKey
        }
        return ProcessInfo.processInfo.environment["GOOGLE_BOOKS_API_KEY"] ?? ""
    }
}
