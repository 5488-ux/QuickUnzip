import SwiftUI
import AVKit

struct VideoPreviewView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("无法播放视频")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(.all, edges: .bottom)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                    }
            } else {
                ProgressView("加载中...")
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // Observe when player is ready
        avPlayer.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .readyToPlay:
                    isLoading = false
                case .failed:
                    errorMessage = avPlayer.error?.localizedDescription ?? "未知错误"
                    isLoading = false
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

import Combine
