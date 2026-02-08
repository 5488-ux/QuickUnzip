import Foundation
import AVFoundation
import UIKit

class MorseCodeService {
    static let shared = MorseCodeService()

    private let morseMap: [Character: String] = [
        "A": ".-",    "B": "-...",  "C": "-.-.",  "D": "-..",
        "E": ".",     "F": "..-.",  "G": "--.",   "H": "....",
        "I": "..",    "J": ".---",  "K": "-.-",   "L": ".-..",
        "M": "--",    "N": "-.",    "O": "---",   "P": ".--.",
        "Q": "--.-",  "R": ".-.",   "S": "...",   "T": "-",
        "U": "..-",   "V": "...-",  "W": ".--",   "X": "-..-",
        "Y": "-.--",  "Z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--",
        "4": "....-", "5": ".....", "6": "-....", "7": "--...",
        "8": "---..", "9": "----.",
        " ": "/",
        ".": ".-.-.-", ",": "--..--", "?": "..--..", "!": "-.-.--",
        "'": ".----.", "/": "-..-.", "(": "-.--.", ")": "-.--.-",
        "&": ".-...", ":": "---...", ";": "-.-.-.", "=": "-...-",
        "+": ".-.-.", "-": "-....-", "_": "..--.-", "\"": ".-..-.",
        "$": "...-..-", "@": ".--.-.",
    ]

    private var reverseMorseMap: [String: Character] = [:]
    private var isFlashing = false
    var onStopFlashing: (() -> Void)?

    init() {
        for (char, morse) in morseMap {
            reverseMorseMap[morse] = char
        }
    }

    // MARK: - Text to Morse

    func textToMorse(_ text: String) -> String {
        text.uppercased().map { char in
            morseMap[char] ?? ""
        }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    // MARK: - Morse to Text

    func morseToText(_ morse: String) -> String {
        let words = morse.components(separatedBy: " / ")
        return words.map { word in
            word.components(separatedBy: " ").map { code in
                reverseMorseMap[code].map(String.init) ?? ""
            }.joined()
        }.joined(separator: " ")
    }

    // MARK: - Flashlight Signal

    func flashMorse(_ morse: String) async {
        isFlashing = true
        let dotDuration: UInt64 = 150_000_000  // 150ms
        let dashDuration: UInt64 = 450_000_000  // 450ms
        let gapDuration: UInt64 = 150_000_000   // gap between signals
        let letterGap: UInt64 = 450_000_000     // gap between letters
        let wordGap: UInt64 = 1_050_000_000     // gap between words

        for char in morse {
            guard isFlashing else { break }
            switch char {
            case ".":
                toggleFlashlight(on: true)
                try? await Task.sleep(nanoseconds: dotDuration)
                toggleFlashlight(on: false)
                try? await Task.sleep(nanoseconds: gapDuration)
            case "-":
                toggleFlashlight(on: true)
                try? await Task.sleep(nanoseconds: dashDuration)
                toggleFlashlight(on: false)
                try? await Task.sleep(nanoseconds: gapDuration)
            case "/":
                try? await Task.sleep(nanoseconds: wordGap)
            case " ":
                try? await Task.sleep(nanoseconds: letterGap)
            default:
                break
            }
        }

        isFlashing = false
        toggleFlashlight(on: false)
        await MainActor.run { onStopFlashing?() }
    }

    func stopFlashing() {
        isFlashing = false
        toggleFlashlight(on: false)
    }

    private func toggleFlashlight(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: - Haptic Signal

    func vibrateMorse(_ morse: String) async {
        isFlashing = true
        let dotDuration: UInt64 = 100_000_000
        let dashDuration: UInt64 = 300_000_000
        let gapDuration: UInt64 = 100_000_000
        let letterGap: UInt64 = 300_000_000
        let wordGap: UInt64 = 700_000_000

        for char in morse {
            guard isFlashing else { break }
            switch char {
            case ".":
                await MainActor.run {
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                }
                try? await Task.sleep(nanoseconds: dotDuration)
            case "-":
                await MainActor.run {
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                }
                try? await Task.sleep(nanoseconds: dashDuration / 3)
                await MainActor.run {
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                }
                try? await Task.sleep(nanoseconds: dashDuration / 3)
                await MainActor.run {
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                }
                try? await Task.sleep(nanoseconds: gapDuration)
            case "/":
                try? await Task.sleep(nanoseconds: wordGap)
            case " ":
                try? await Task.sleep(nanoseconds: letterGap)
            default:
                break
            }
        }
        isFlashing = false
        await MainActor.run { onStopFlashing?() }
    }
}
