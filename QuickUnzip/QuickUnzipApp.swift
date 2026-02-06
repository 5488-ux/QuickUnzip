import SwiftUI

@main
struct QuickUnzipApp: App {
    @StateObject private var store = FileStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "archivebox.fill" : "archivebox")
                    Text("解压")
                }
                .tag(0)

            CompressView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "doc.zipper" : "doc.zipper")
                    Text("压缩")
                }
                .tag(1)
        }
        .tint(Color(hex: "667eea"))
    }
}
