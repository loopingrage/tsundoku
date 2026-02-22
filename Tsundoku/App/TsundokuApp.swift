import SwiftUI
import SwiftData

@main
struct TsundokuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Book.self)
    }
}
