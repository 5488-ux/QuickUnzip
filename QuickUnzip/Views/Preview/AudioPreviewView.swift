import SwiftUI
import AVFoundation
import Combine

struct AudioPreviewView: View {
    let url: URL
    @StateObject private var manager = AudioPlayerManager()

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

            // Error message
            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 32)
            }

            // Time display
            HStack {
                Text(manager.currentTimeString)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                Text(manager.durationString)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            // Progress slider
            Slider(
                value: $manager.progress,
                in: 0...1,
                onEditingChanged: { editing in
                    manager.isSeeking = editing
                    if !editing {
                        manager.seek(to: manager.progress)
                    }
                }
            )
            .tint(.pink)
            .padding(.horizontal, 32)

            // Playback controls
            HStack(spacing: 40) {
                Button(action: { manager.skip(seconds: -15) }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                }

                Button(action: { manager.togglePlayPause() }) {
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

                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }

                Button(action: { manager.skip(seconds: 15) }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                }
            }

            Spacer()
        }
        .onAppear {
            manager.load(url: url)
        }
        .onDisappear {
            manager.stop()
        }
    }
}

// MARK: - Audio Player Manager

class AudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTimeString: String = "0:00"
    @Published var durationString: String = "0:00"
    @Published var errorMessage: String?
    var isSeeking = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    func load(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "音频会话初始化失败"
        }

        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        self.player = avPlayer

        // Observe duration
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .readyToPlay {
                    let duration = CMTimeGetSeconds(playerItem.duration)
                    if duration.isFinite && duration > 0 {
                        self.durationString = self.formatTime(duration)
                    }
                } else if status == .failed {
                    self.errorMessage = playerItem.error?.localizedDescription ?? "无法加载音频"
                }
            }
            .store(in: &cancellables)

        // Periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            guard let item = avPlayer.currentItem else { return }
            let duration = CMTimeGetSeconds(item.duration)
            let current = CMTimeGetSeconds(time)
            guard duration.isFinite && duration > 0 else { return }
            self.progress = current / duration
            self.currentTimeString = self.formatTime(current)
        }

        // Observe playback end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.progress = 0
                self?.currentTimeString = "0:00"
                avPlayer.seek(to: .zero)
            }
            .store(in: &cancellables)
    }

    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func stop() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        cancellables.removeAll()
        player = nil
        isPlaying = false
    }

    func skip(seconds: Double) {
        guard let player = player, let item = player.currentItem else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let duration = CMTimeGetSeconds(item.duration)
        guard duration.isFinite else { return }
        let newTime = max(0, min(duration, current + seconds))
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }

    func seek(to value: Double) {
        guard let player = player, let item = player.currentItem else { return }
        let duration = CMTimeGetSeconds(item.duration)
        guard duration.isFinite else { return }
        let target = value * duration
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
