import SwiftUI
import UniformTypeIdentifiers

// MARK: - Text Editor View

struct TextEditorMainView: View {
    @EnvironmentObject var store: FileStore
    @State private var documents: [TextDocument] = []
    @State private var showFilePicker = false
    @State private var showNewFileSheet = false
    @State private var selectedDocument: TextDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 快捷操作卡片
                    quickActionsCard

                    // 最近文档
                    if !documents.isEmpty {
                        recentDocumentsSection
                    } else {
                        emptyState
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color(hex: "f8f9ff").ignoresSafeArea())
            .navigationTitle("文本编辑")
            .sheet(isPresented: $showFilePicker) {
                TextDocumentPicker { url in
                    openDocument(url: url)
                }
            }
            .sheet(isPresented: $showNewFileSheet) {
                NewTextFileSheet { name, content in
                    createNewDocument(name: name, content: content)
                }
            }
            .sheet(item: $selectedDocument) { doc in
                TextEditingView(document: doc) { updatedDoc in
                    updateDocument(updatedDoc)
                }
            }
            .onAppear {
                loadDocuments()
            }
        }
    }

    // MARK: - Quick Actions Card

    var quickActionsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // 新建文档
                TextEditorActionButton(
                    icon: "doc.badge.plus",
                    title: "新建文档",
                    color: Color(hex: "667eea")
                ) {
                    showNewFileSheet = true
                }

                // 打开文件
                TextEditorActionButton(
                    icon: "folder.badge.plus",
                    title: "打开文件",
                    color: Color(hex: "764ba2")
                ) {
                    showFilePicker = true
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Recent Documents Section

    var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近文档")
                    .font(.headline)
                Spacer()
                Button("清空") {
                    documents.removeAll()
                    saveDocumentsList()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ForEach(documents) { doc in
                DocumentRow(document: doc) {
                    selectedDocument = doc
                } onDelete: {
                    deleteDocument(doc)
                }
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "667eea").opacity(0.5))

            Text("暂无文档")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("点击上方按钮新建或打开文档")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Functions

    func loadDocuments() {
        if let data = UserDefaults.standard.data(forKey: "text_documents"),
           let docs = try? JSONDecoder().decode([TextDocument].self, from: data) {
            documents = docs
        }
    }

    func saveDocumentsList() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: "text_documents")
        }
    }

    func openDocument(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let doc = TextDocument(
                name: url.lastPathComponent,
                originalExtension: url.pathExtension,
                content: content,
                originalURL: url
            )
            documents.insert(doc, at: 0)
            saveDocumentsList()
            selectedDocument = doc
        } catch {
            print("读取文件失败: \(error)")
        }
    }

    func createNewDocument(name: String, content: String) {
        let fileName = name.hasSuffix(".txt") ? name : "\(name).txt"
        let doc = TextDocument(
            name: fileName,
            originalExtension: "txt",
            content: content,
            originalURL: nil
        )
        documents.insert(doc, at: 0)
        saveDocumentsList()
        selectedDocument = doc
    }

    func updateDocument(_ doc: TextDocument) {
        if let index = documents.firstIndex(where: { $0.id == doc.id }) {
            documents[index] = doc
            saveDocumentsList()
        }
    }

    func deleteDocument(_ doc: TextDocument) {
        documents.removeAll { $0.id == doc.id }
        saveDocumentsList()
    }
}

// MARK: - Text Document Model

struct TextDocument: Identifiable, Codable {
    let id: UUID
    var name: String
    var originalExtension: String
    var content: String
    var originalURLString: String?
    var lastModified: Date

    var originalURL: URL? {
        get { originalURLString.flatMap { URL(string: $0) } }
        set { originalURLString = newValue?.absoluteString }
    }

    var isTxtFile: Bool {
        originalExtension.lowercased() == "txt"
    }

    var displayName: String {
        if isTxtFile {
            return name
        } else {
            return "\(name) → .txt"
        }
    }

    init(name: String, originalExtension: String, content: String, originalURL: URL?) {
        self.id = UUID()
        self.name = name
        self.originalExtension = originalExtension
        self.content = content
        self.originalURLString = originalURL?.absoluteString
        self.lastModified = Date()
    }
}

// MARK: - Text Editor Action Button

struct TextEditorActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "f8f9ff"))
            .cornerRadius(12)
        }
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: TextDocument
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(document.isTxtFile
                              ? Color(hex: "667eea").opacity(0.15)
                              : Color(hex: "f7971e").opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: document.isTxtFile ? "doc.text" : "doc.text.magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(document.isTxtFile ? Color(hex: "667eea") : Color(hex: "f7971e"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !document.isTxtFile {
                            Text("原始: .\(document.originalExtension)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Text(formatDate(document.lastModified))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 删除按钮
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
        }
        .padding(.horizontal)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Text Editing View

struct TextEditingView: View {
    @Environment(\.dismiss) private var dismiss
    @State var document: TextDocument
    @State private var editedContent: String
    @State private var showSaveOptions = false
    @State private var showSaveSuccess = false
    @State private var isSaving = false

    let onSave: (TextDocument) -> Void

    init(document: TextDocument, onSave: @escaping (TextDocument) -> Void) {
        self._document = State(initialValue: document)
        self._editedContent = State(initialValue: document.content)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 文件信息栏
                if !document.isTxtFile {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("临时转换为 .txt 编辑，保存时将恢复原始格式 .\(document.originalExtension)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                }

                // 文本编辑器
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.white)

                // 底部工具栏
                HStack {
                    // 字数统计
                    Text("\(editedContent.count) 字符")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // 行数统计
                    Text("\(editedContent.components(separatedBy: "\n").count) 行")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(hex: "f8f9ff"))
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSaveOptions = true }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text("保存")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .confirmationDialog("保存选项", isPresented: $showSaveOptions) {
                Button("保存到应用内") {
                    saveToApp()
                }

                if document.originalURL != nil {
                    Button("保存到原位置") {
                        saveToOriginalLocation()
                    }
                }

                Button("导出文件") {
                    exportFile()
                }

                Button("取消", role: .cancel) {}
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("好的") {
                    dismiss()
                }
            } message: {
                Text("文件已成功保存")
            }
        }
    }

    func saveToApp() {
        var updatedDoc = document
        updatedDoc.content = editedContent
        updatedDoc.lastModified = Date()
        onSave(updatedDoc)
        showSaveSuccess = true
    }

    func saveToOriginalLocation() {
        guard let url = document.originalURL else { return }

        isSaving = true
        let accessing = url.startAccessingSecurityScopedResource()

        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
                DispatchQueue.main.async { isSaving = false }
            }

            do {
                try editedContent.write(to: url, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    saveToApp()
                }
            } catch {
                print("保存失败: \(error)")
            }
        }
    }

    func exportFile() {
        // 保存到应用文档目录
        let fileName = document.isTxtFile ? document.name : document.name.replacingOccurrences(of: ".txt", with: ".\(document.originalExtension)")

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(fileName)

        do {
            try editedContent.write(to: filePath, atomically: true, encoding: .utf8)
            saveToApp()
        } catch {
            print("导出失败: \(error)")
        }
    }
}

// MARK: - New Text File Sheet

struct NewTextFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fileName = ""
    @State private var content = ""

    let onCreate: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("文件名") {
                    HStack {
                        TextField("请输入文件名", text: $fileName)
                        Text(".txt")
                            .foregroundColor(.secondary)
                    }
                }

                Section("内容（可选）") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("新建文档")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        onCreate(fileName, content)
                        dismiss()
                    }
                    .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Text Document Picker

struct TextDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .text,
            .plainText,
            .utf8PlainText,
            .sourceCode,
            .json,
            .xml,
            .html,
            .yaml,
            UTType(filenameExtension: "md") ?? .text,
            UTType(filenameExtension: "log") ?? .text,
            UTType(filenameExtension: "ini") ?? .text,
            UTType(filenameExtension: "conf") ?? .text,
            UTType(filenameExtension: "cfg") ?? .text,
            .data // 允许所有文件
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
