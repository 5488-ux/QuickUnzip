import SwiftUI

struct FileListView: View {
    @EnvironmentObject var store: FileStore
    @StateObject var vm: FileListViewModel

    init(url: URL, title: String? = nil) {
        _vm = StateObject(wrappedValue: FileListViewModel(url: url, title: title))
    }

    var body: some View {
        List {
            ForEach(vm.filteredFiles) { item in
                if item.isDirectory {
                    NavigationLink(destination: FileListView(url: item.url)) {
                        FileRowView(item: item, isFavorite: store.isFavorite(item.url))
                    }
                } else if item.isPreviewable {
                    NavigationLink(destination: FileDetailView(item: item)) {
                        FileRowView(item: item, isFavorite: store.isFavorite(item.url))
                    }
                } else {
                    FileRowView(item: item, isFavorite: store.isFavorite(item.url))
                }
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    let item = vm.filteredFiles[idx]
                    vm.deleteFile(item)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $vm.searchText, prompt: "Search files")
        .navigationTitle(vm.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort", selection: $vm.sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { opt in
                            Label(opt.rawValue, systemImage: sortIcon(opt))
                                .tag(opt)
                        }
                    }
                    Divider()
                    Button(action: { vm.sortAscending.toggle(); vm.sortFiles() }) {
                        Label(vm.sortAscending ? "Descending" : "Ascending",
                              systemImage: vm.sortAscending ? "arrow.down" : "arrow.up")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .onChange(of: vm.sortOption) { _ in vm.sortFiles() }
        .overlay {
            if vm.filteredFiles.isEmpty {
                EmptyStateView(icon: "folder", message: "No files found")
            }
        }
    }

    func sortIcon(_ opt: SortOption) -> String {
        switch opt {
        case .name: return "textformat.abc"
        case .size: return "internaldrive"
        case .date: return "calendar"
        case .type: return "doc"
        }
    }
}
