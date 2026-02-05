import SwiftUI

@main
struct QuickUnzipApp: App {
    @StateObject private var store = FileStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}
