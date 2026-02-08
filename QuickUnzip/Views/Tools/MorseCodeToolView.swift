import SwiftUI

struct MorseCodeToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @State private var morseResult = ""
    @State private var isTextToMorse = true
    @State private var isFlashing = false
    @State private var isVibrating = false
    @State private var currentSignalIndex = 0

    private let service = MorseCodeService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mode Toggle
                    modeToggle

                    // Input
                    inputSection

                    // Convert Button
                    convertButton

                    // Result
                    if !morseResult.isEmpty {
                        resultSection
                    }

                    // Signal Buttons
                    if !morseResult.isEmpty && isTextToMorse {
                        signalButtons
                    }

                    // Morse Code Reference
                    referenceCard

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(hex: "f8f9ff").ignoresSafeArea())
            .navigationTitle("摩斯密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onDisappear {
                service.stopFlashing()
            }
        }
    }

    // MARK: - Mode Toggle

    var modeToggle: some View {
        HStack(spacing: 0) {
            Button(action: { withAnimation { isTextToMorse = true; morseResult = "" } }) {
                VStack(spacing: 6) {
                    Image(systemName: "textformat")
                        .font(.title3)
                    Text("文字 → 摩斯")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isTextToMorse ? Color(hex: "667eea") : Color.clear)
                .foregroundColor(isTextToMorse ? .white : .secondary)
            }

            Button(action: { withAnimation { isTextToMorse = false; morseResult = "" } }) {
                VStack(spacing: 6) {
                    Image(systemName: "wave.3.right")
                        .font(.title3)
                    Text("摩斯 → 文字")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(!isTextToMorse ? Color(hex: "667eea") : Color.clear)
                .foregroundColor(!isTextToMorse ? .white : .secondary)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Input Section

    var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isTextToMorse ? "输入文字" : "输入摩斯密码")
                .font(.headline)

            if isTextToMorse {
                TextField("Hello World", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            } else {
                TextField(".... . .-.. .-.. ---", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            if !isTextToMorse {
                Text("用空格分隔字母，/ 分隔单词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Convert Button

    var convertButton: some View {
        Button(action: convert) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("转换")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Result Section

    var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("转换结果")
                    .font(.headline)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = morseResult
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .font(.caption)
                    .foregroundColor(Color(hex: "667eea"))
                }
            }

            Text(morseResult)
                .font(isTextToMorse ? .system(.body, design: .monospaced) : .body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "f0f2ff"))
                .cornerRadius(12)

            if isTextToMorse {
                // Visual morse display
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(morseResult.enumerated()), id: \.offset) { index, char in
                            morseSignalView(char)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Signal Buttons

    var signalButtons: some View {
        VStack(spacing: 12) {
            Text("发送信号")
                .font(.headline)

            HStack(spacing: 16) {
                // Flashlight button
                Button(action: {
                    if isFlashing {
                        service.stopFlashing()
                        isFlashing = false
                    } else {
                        isFlashing = true
                        service.onStopFlashing = { isFlashing = false }
                        Task { await service.flashMorse(morseResult) }
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: isFlashing ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title2)
                        Text(isFlashing ? "停止" : "手电筒")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isFlashing ? Color(hex: "ffd700") : Color(hex: "667eea").opacity(0.1))
                    .foregroundColor(isFlashing ? .black : Color(hex: "667eea"))
                    .cornerRadius(14)
                }

                // Vibration button
                Button(action: {
                    if isVibrating {
                        service.stopFlashing()
                        isVibrating = false
                    } else {
                        isVibrating = true
                        service.onStopFlashing = { isVibrating = false }
                        Task { await service.vibrateMorse(morseResult) }
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: isVibrating ? "iphone.radiowaves.left.and.right" : "iphone.gen3")
                            .font(.title2)
                        Text(isVibrating ? "停止" : "震动")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isVibrating ? Color(hex: "ff6b6b").opacity(0.2) : Color(hex: "667eea").opacity(0.1))
                    .foregroundColor(isVibrating ? Color(hex: "ff6b6b") : Color(hex: "667eea"))
                    .cornerRadius(14)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Reference Card

    var referenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("摩斯密码表")
                .font(.headline)

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["A","B","C","D","E","F","G","H","I","J","K","L","M",
                          "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"], id: \.self) { letter in
                    VStack(spacing: 2) {
                        Text(letter)
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "667eea"))
                        Text(service.textToMorse(letter))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(hex: "f0f2ff"))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Helpers

    func convert() {
        if isTextToMorse {
            morseResult = service.textToMorse(inputText)
        } else {
            morseResult = service.morseToText(inputText)
        }
    }

    @ViewBuilder
    func morseSignalView(_ char: Character) -> some View {
        switch char {
        case ".":
            Circle()
                .fill(Color(hex: "667eea"))
                .frame(width: 10, height: 10)
        case "-":
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "764ba2"))
                .frame(width: 28, height: 10)
        case " ":
            Color.clear.frame(width: 6, height: 10)
        case "/":
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)
        default:
            EmptyView()
        }
    }
}
