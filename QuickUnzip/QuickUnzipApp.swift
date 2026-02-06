import SwiftUI

@main
struct QuickUnzipApp: App {
    @StateObject private var store = FileStore()
    @StateObject private var updateChecker = UpdateChecker()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(updateChecker)
                .sheet(isPresented: $updateChecker.showUpdateLog) {
                    UpdateLogView()
                }
                .onAppear {
                    updateChecker.checkForUpdate()
                }
        }
    }
}

// MARK: - Update Checker

class UpdateChecker: ObservableObject {
    @Published var showUpdateLog = false

    private let lastSeenVersionKey = "lastSeenAppVersion"
    private let currentVersion = "2.9.2"

    func checkForUpdate() {
        let lastSeenVersion = UserDefaults.standard.string(forKey: lastSeenVersionKey) ?? ""

        if lastSeenVersion != currentVersion {
            // New version detected, show update log
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showUpdateLog = true
            }
            // Save current version
            UserDefaults.standard.set(currentVersion, forKey: lastSeenVersionKey)
        }
    }

    func resetUpdateLog() {
        // For testing: reset the last seen version
        UserDefaults.standard.removeObject(forKey: lastSeenVersionKey)
    }
}

// MARK: - Main Tab View

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
