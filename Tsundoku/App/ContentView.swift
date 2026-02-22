import SwiftUI

@Observable
class AppNavigation {
    var selectedTab: Int = 0
    var searchQuery: String?
}

struct ContentView: View {
    @State private var appNav = AppNavigation()

    var body: some View {
        TabView(selection: $appNav.selectedTab) {
            MetadataSearchDemoView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(0)

            ShelfScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(1)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(2)
        }
        .environment(appNav)
    }
}
