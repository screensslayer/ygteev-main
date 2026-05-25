//
//  MuxVideoPlayer.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/9/26.
//

import SwiftUI
import AVFoundation
import AVKit

// Looping video player. Defaults to Mux HLS playback when given a
// `playbackId`, but also accepts a direct `URL` for cases like Instagram-
// scraped feed posts where the source isn't on Mux.
struct MuxVideoPlayer: View {
    let videoURL: URL
    let isActive: Bool

    @State private var player: AVPlayer?
    @State private var playerLooper: AVPlayerLooper?

    /// Mux playback ID → HLS URL. Existing call sites stay untouched.
    init(playbackId: String, isActive: Bool) {
        self.videoURL = URL(string: "https://stream.mux.com/\(playbackId).m3u8")
            ?? URL(string: "https://stream.mux.com/.m3u8")!
        self.isActive = isActive
    }

    /// Arbitrary URL (HLS, mp4, or any AVPlayer-supported media) — used
    /// for feed posts whose source isn't on Mux.
    init(url: URL, isActive: Bool) {
        self.videoURL = url
        self.isActive = isActive
    }

    var body: some View {
        Group {
            if let player = player {
                CustomVideoPlayer(player: player)
            } else {
                Rectangle()
                    .fill(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            setupPlayer()
        }
        .onChange(of: isActive) { _, active in
            if active {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    private func setupPlayer() {
        // Configure audio session to play even in silent mode
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        let playerItem = AVPlayerItem(url: videoURL)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        
        // Setup looping
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        // Unmuted by default
        queuePlayer.isMuted = false
        
        // Auto-play when active
        if isActive {
            queuePlayer.play()
        }
        
        player = queuePlayer
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player = nil
        playerLooper = nil
    }
}

// Custom video player view without controls
struct CustomVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

// Custom UIView with AVPlayerLayer
class PlayerView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
            // Use resizeAspectFill to fill the entire screen edge-to-edge
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

#Preview {
    MuxVideoPlayer(
        playbackId: "wm00CvwuSaBjsJkcm2qT001mZMR00eIY3ZT3bYsjvpIa5I",
        isActive: true
    )
    .frame(height: 800)
}
