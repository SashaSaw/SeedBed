//
//  SoundEffectService.swift
//  Sown
//
//  Sound playback engine — system sounds for subtle interactions,
//  custom .caf files for key moments (celebration, completion, slip, success).
//

import AVFoundation
import AudioToolbox
import UIKit

final class SoundEffectService {
    static let shared = SoundEffectService()

    // MARK: - Pre-loaded custom sound players

    private var celebrationPlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?
    private var slipPlayer: AVAudioPlayer?
    private var successPlayer: AVAudioPlayer?
    private var undoPlayer: AVAudioPlayer?
    private var archivePlayer: AVAudioPlayer?
    private var deletePlayer: AVAudioPlayer?

    // UI interaction sounds (replacing system sounds)
    private var clickPlayer: AVAudioPlayer?
    private var tickPlayer: AVAudioPlayer?
    private var whooshPlayer: AVAudioPlayer?
    private var tabPlayer: AVAudioPlayer?
    private var dingPlayer: AVAudioPlayer?

    // Swipe gesture sounds
    private var swipingPlayer: AVAudioPlayer?      // Loops while swiping
    private var swipeCompletePlayer: AVAudioPlayer? // Plays on successful swipe
    private var swipeCancelPlayer: AVAudioPlayer?   // Plays when swipe cancelled

    // Timer to pause swiping sound when finger stops moving
    private var swipePauseTimer: Timer?
    private let swipePauseDelay: TimeInterval = 0.24  // Pause after 500ms of no movement

    // Continuous haptic feedback while swiping
    private var swipeHapticTimer: Timer?
    private let swipeHapticInterval: TimeInterval = 0.05  // Pulse every 50ms
    private let swipeHapticGenerator = UIImpactFeedbackGenerator(style: .soft)

    // MARK: - Init

    private init() {
        // Configure audio session immediately (fast)
        configureAudioSession()
        // Load sounds in background to avoid blocking main thread on first tap
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            preloadCustomSounds()
        }
        swipeHapticGenerator.prepare()
    }

    /// Trigger eager initialization so sounds are ready before first use.
    /// Call this early in app startup (e.g. in SownApp.init).
    static func warmUp() {
        _ = shared
    }

    private func configureAudioSession() {
        // .ambient respects the mute switch and mixes with other audio (e.g. music)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
    }

    private func preloadCustomSounds() {
        // Load into locals first, then assign on main thread to avoid races
        let celebration = loadPlayer(named: "celebration")
        let completion = loadPlayer(named: "completion")
        let slip = loadPlayer(named: "slip")
        let success = loadPlayer(named: "success")
        let undo = loadPlayer(named: "uipop")
        let archive = loadPlayer(named: "archive")
        let delete = loadPlayer(named: "delete")

        let swiping = loadPlayer(named: "swiping", looping: true)
        let swipeComplete = loadPlayer(named: "swipeComplete")
        let swipeCancel = loadPlayer(named: "swipeCancel")

        let click = loadPlayer(named: "click")
        let tick = loadPlayer(named: "tick")
        let whoosh = loadPlayer(named: "whoosh")
        let tab = loadPlayer(named: "tab")
        let ding = loadPlayer(named: "ding")

        DispatchQueue.main.async { [self] in
            celebrationPlayer = celebration
            completionPlayer = completion
            slipPlayer = slip
            successPlayer = success
            undoPlayer = undo
            archivePlayer = archive
            deletePlayer = delete
            swipingPlayer = swiping
            swipeCompletePlayer = swipeComplete
            swipeCancelPlayer = swipeCancel
            clickPlayer = click
            tickPlayer = tick
            whooshPlayer = whoosh
            tabPlayer = tab
            dingPlayer = ding
        }
    }

    private func loadPlayer(named name: String, looping: Bool = false) -> AVAudioPlayer? {
        // Try .caf first, then .mp3, then .wav — so you can drop in any format
        for ext in ["caf", "mp3", "wav", "m4a", "aiff"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                player?.volume = 0.25
                if looping {
                    player?.numberOfLoops = -1  // Loop indefinitely
                }
                return player
            }
        }
        return nil
    }

    // MARK: - Enabled Check

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "soundEffectsEnabled")
    }

    // MARK: - Playback Helpers

    private func playSystemSound(_ soundID: SystemSoundID) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    private func playCustom(_ player: AVAudioPlayer?) {
        guard isEnabled, let player else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: - Swipe Gesture Sounds

    /// Start or resume the looping swipe sound and haptic, and reset the pause timer.
    /// Call this on every drag movement to keep feedback going while finger moves.
    func startSwiping() {
        // Cancel any pending pause
        swipePauseTimer?.invalidate()

        // Start sound if enabled and not already playing
        if isEnabled, let player = swipingPlayer, !player.isPlaying {
            player.currentTime = 0
            player.play()
        }

        // Start haptic pulse if not already running
        if swipeHapticTimer == nil {
            swipeHapticTimer = Timer.scheduledTimer(withTimeInterval: swipeHapticInterval, repeats: true) { [weak self] _ in
                self?.swipeHapticGenerator.impactOccurred(intensity: 0.7)
            }
        }

        // Set timer to pause when finger stops moving
        swipePauseTimer = Timer.scheduledTimer(withTimeInterval: swipePauseDelay, repeats: false) { [weak self] _ in
            self?.swipingPlayer?.pause()
            self?.swipeHapticTimer?.invalidate()
            self?.swipeHapticTimer = nil
        }
    }

    /// Stop the looping swipe sound and haptic completely
    func stopSwiping() {
        swipePauseTimer?.invalidate()
        swipePauseTimer = nil
        swipeHapticTimer?.invalidate()
        swipeHapticTimer = nil
        swipingPlayer?.stop()
    }

    /// Play completion sound and stop the loop (call when swipe succeeds)
    func swipeCompleted() {
        stopSwiping()
        playCustom(swipeCompletePlayer)
    }

    /// Play cancel sound and stop the loop (call when swipe cancelled)
    func swipeCancelled() {
        stopSwiping()
        playCustom(swipeCancelPlayer)
    }

    // MARK: - Custom Sounds (key moments)

    func completion()    { playCustom(completionPlayer) }
    func celebration()   { playCustom(celebrationPlayer) }
    func slip()          { playCustom(slipPlayer) }
    func successSound()  { playCustom(successPlayer) }

    // MARK: - UI Sounds (subtle interactions)

    func thresholdCrossed() { playCustom(tickPlayer) }
    func undo()             { playCustom(undoPlayer) }
    func archive()          { playCustom(archivePlayer) }
    func deleteSound()      { playCustom(deletePlayer) }
    func buttonPress()      { playCustom(clickPlayer) }
    func sheetOpen()        { playCustom(whooshPlayer) }
    func tabSwitch()        { playCustom(tabPlayer) }
    func selection()        { playCustom(clickPlayer) }
    func longPress()        { playCustom(clickPlayer) }
    func groupToggle()      { playCustom(clickPlayer) }
    func ding()             { playCustom(dingPlayer) }
}
