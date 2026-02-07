import SwiftUI
import AVFoundation

struct AudioPreviewView: View {
    let url: URL
    @StateObject private var player = AudioPlayerManager()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Album art placeholder
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundColor(.pink)
            }

            // File name
            Text(url.lastPathComponent)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Time display
            HStack {
                Text(player.currentTimeString)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                Text(player.durationString)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            // Progress slider
            Slider(
                value: $player.progress,
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing {
                        player.seek(to: player.progress)
                    }
                }
            )
            .tint(.pink)
            .padding(.horizontal, 32)

            // Playback controls
            HStack(spacing: 40) {
                // Rewind 15s
                Button(action: { player.skip(seconds: -15) }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                }

                // Play/Pause
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: .pink.opacity(0.4), radius: 12, y: 6)

                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }

                // Forward 15s
                Button(action: { player.skip(seconds: 15) }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                }
            }

            Spacer()
        }
        .onAppear {
            player.load(url: url)
        }
        .onDisappear {
            player.stop()
        }
    }
}

// MARK: - Audio Player Manager

class AudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTimeString: String = "0:00"
    @Published var durationString: String = "0:00"

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            durationString = formatTime(audioPlayer?.duration ?? 0)
        } catch {
            print("Audio load error: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = audioPlayer else { return }

        if isPlaying {
            player.pause()
            timer?.invalidate()
        } else {
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }

    func stop() {
        audioPlayer?.stop()
        timer?.invalidate()
        isPlaying = false
    }

    func skip(seconds: Double) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(player.duration, player.currentTime + seconds))
        player.currentTime = newTime
        updateProgress()
    }

    func seek(to value: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = value * player.duration
        updateProgress()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        guard let player = audioPlayer, player.duration > 0 else { return }
        progress = player.currentTime / player.duration
        currentTimeString = formatTime(player.currentTime)

        if !player.isPlaying && isPlaying {
            isPlaying = false
            timer?.invalidate()
            progress = 0
            currentTimeString = "0:00"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
