import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MetadataSearchDemoView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
        }
    }
}
