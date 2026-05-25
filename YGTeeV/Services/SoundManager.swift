//
//  SoundManager.swift
//  YGTeeV
//
//  Created by Claude Code on 5/8/26.
//

import AVFoundation
import SwiftUI

@MainActor
@Observable
class SoundManager {
    static let shared = SoundManager()
    
    private var players: [String: AVAudioPlayer] = [:]
    private var isSoundEnabled = true
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Sound Effects
    
    /// Play correct answer sound (success chime)
    func playCorrectAnswer() {
        guard isSoundEnabled else { return }
        playSound(named: "correct_answer", withExtension: "mp3", volume: 0.6)
    }
    
    /// Play XP earned sound (coins/level up)
    func playXPEarned() {
        guard isSoundEnabled else { return }
        // Slight delay so it plays after correct answer
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            playSound(named: "xp_earned", withExtension: "mp3", volume: 0.5)
        }
    }
    
    /// Play wrong answer sound
    func playWrongAnswer() {
        guard isSoundEnabled else { return }
        playSound(named: "wrong_answer", withExtension: "mp3", volume: 0.4)
    }
    
    /// Play level up sound
    func playLevelUp() {
        guard isSoundEnabled else { return }
        playSound(named: "level_up", withExtension: "mp3", volume: 0.7)
    }
    
    // MARK: - Playback
    
    private func playSound(named name: String, withExtension ext: String, volume: Float = 0.5) {
        // Try to get existing player or create new one
        let key = "\(name).\(ext)"
        
        if let player = players[key] {
            player.currentTime = 0
            player.volume = volume
            player.play()
            return
        }
        
        // Create new player
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            // Sound file doesn't exist yet - that's OK, we'll add them
            print("⚠️ Sound file not found: \(name).\(ext)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            players[key] = player
            player.play()
        } catch {
            print("❌ Error playing sound \(name): \(error)")
        }
    }
    
    // MARK: - Settings
    
    func toggleSound() {
        isSoundEnabled.toggle()
    }
    
    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }
}
