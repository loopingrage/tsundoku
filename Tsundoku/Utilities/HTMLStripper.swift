import Foundation

enum HTMLStripper {
    static func strip(_ html: String) -> String {
        var result = html

        if html.contains("<") {
            result = result
                .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
                .replacingOccurrences(of: "<p>", with: "\n")
                .replacingOccurrences(of: "</p>", with: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }

        return result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
