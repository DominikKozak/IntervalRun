import AudioToolbox
import AVFoundation
import Foundation
import UIKit
import UserNotifications

@MainActor
final class WorkoutViewModel: NSObject, ObservableObject {
    @Published var segments: [IntervalSegment] = []
    @Published var rounds: Int = 6
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var currentSegmentIndex = 0
    @Published var currentRound = 1
    @Published var secondsRemaining = 0
    @Published var countdownToStart = 0
    @Published var enableVoice = true
    @Published var enableSound = true
    @Published var notificationPermissionState = "Nezjisteno"

    private let saveKey = "savedWorkoutConfig"
    private let notificationCenter = UNUserNotificationCenter.current()
    private let speaker = AVSpeechSynthesizer()
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var timer: Timer?

    override init() {
        super.init()
        load()
        Task {
            await refreshNotificationPermission()
        }
    }

    var currentSegment: IntervalSegment? {
        guard segments.indices.contains(currentSegmentIndex) else { return nil }
        return segments[currentSegmentIndex]
    }

    var nextSegment: IntervalSegment? {
        guard !segments.isEmpty else { return nil }

        let nextIndex = currentSegmentIndex + 1
        if segments.indices.contains(nextIndex) {
            return segments[nextIndex]
        }

        if currentRound < rounds {
            return segments.first
        }

        return nil
    }

    var totalWorkoutSeconds: Int {
        segments.reduce(0) { $0 + $1.durationSeconds } * max(rounds, 1)
    }

    var totalWorkoutDescription: String {
        format(seconds: totalWorkoutSeconds)
    }

    var totalRemainingSeconds: Int {
        guard !segments.isEmpty else { return 0 }

        if !isRunning && countdownToStart == 0 {
            return totalWorkoutSeconds
        }

        var remaining = secondsRemaining

        if currentSegmentIndex + 1 < segments.count {
            remaining += segments[(currentSegmentIndex + 1)...].reduce(0) { $0 + $1.durationSeconds }
        }

        let remainingRounds = max(rounds - currentRound, 0)
        if remainingRounds > 0 {
            remaining += segments.reduce(0) { $0 + $1.durationSeconds } * remainingRounds
        }

        return remaining
    }

    var progress: Double {
        guard totalWorkoutSeconds > 0 else { return 0 }
        return min(max(Double(totalWorkoutSeconds - totalRemainingSeconds) / Double(totalWorkoutSeconds), 0), 1)
    }

    func addSegment() {
        segments.append(IntervalSegment(title: "Novy interval", durationSeconds: 60))
        save()
    }

    func removeSegments(at offsets: IndexSet) {
        segments.remove(atOffsets: offsets)
        if segments.isEmpty {
            segments = .starterIntervals
        }
        save()
    }

    func moveSegments(from source: IndexSet, to destination: Int) {
        segments.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func updateSegment(id: UUID, title: String, minutes: Int, seconds: Int) {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        let clampedMinutes = max(0, minutes)
        let clampedSeconds = min(max(0, seconds), 59)
        let totalSeconds = max(5, (clampedMinutes * 60) + clampedSeconds)
        segments[index].title = title.isEmpty ? "Interval" : title
        segments[index].durationSeconds = totalSeconds
        save()
    }

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in
                await self?.refreshNotificationPermission()
            }
        }
    }

    func startWorkout() {
        guard !segments.isEmpty else { return }

        timer?.invalidate()
        currentSegmentIndex = 0
        currentRound = 1
        secondsRemaining = segments[0].durationSeconds
        countdownToStart = 5
        isRunning = false
        isPaused = false

        startTimer()
    }

    func pauseOrResumeWorkout() {
        guard isRunning || isPaused else { return }

        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            removeScheduledNotifications()
            setIdleTimer(disabled: false)
        } else {
            scheduleNotifications()
            startTimer()
            setIdleTimer(disabled: true)
        }
    }

    func resetWorkout() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        currentSegmentIndex = 0
        currentRound = 1
        countdownToStart = 0
        secondsRemaining = segments.first?.durationSeconds ?? 0
        removeScheduledNotifications()
        setIdleTimer(disabled: false)
    }

    func format(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode(SavedWorkoutConfig.self, from: data) {
            segments = saved.segments.isEmpty ? .starterIntervals : saved.segments
            rounds = max(1, saved.rounds)
            enableVoice = saved.enableVoice
            enableSound = saved.enableSound
        } else {
            segments = .starterIntervals
        }

        secondsRemaining = segments.first?.durationSeconds ?? 0
    }

    func save() {
        let config = SavedWorkoutConfig(
            segments: segments,
            rounds: rounds,
            enableVoice: enableVoice,
            enableSound: enableSound
        )

        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard !isPaused else { return }

        if countdownToStart > 0 {
            countdownToStart -= 1

            if countdownToStart == 0 {
                isRunning = true
                setIdleTimer(disabled: true)
                scheduleNotifications()
                announceCurrentSegment(prefix: "Start")
            } else if countdownToStart <= 3 {
                speak("\(countdownToStart)")
            }

            return
        }

        guard isRunning else { return }

        if secondsRemaining > 1 {
            secondsRemaining -= 1
            return
        }

        advanceSegment()
    }

    private func advanceSegment() {
        if currentSegmentIndex < segments.count - 1 {
            currentSegmentIndex += 1
        } else if currentRound < rounds {
            currentRound += 1
            currentSegmentIndex = 0
        } else {
            finishWorkout()
            return
        }

        secondsRemaining = segments[currentSegmentIndex].durationSeconds
        announceCurrentSegment(prefix: "Ted")
    }

    private func finishWorkout() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        countdownToStart = 0
        secondsRemaining = 0
        removeScheduledNotifications()
        setIdleTimer(disabled: false)
        feedbackGenerator.notificationOccurred(.success)
        playSound()
        speak("Hotovo. Trenink skoncil.")
    }

    private func announceCurrentSegment(prefix: String) {
        let title = currentSegment?.title ?? "interval"
        let message = "\(prefix) \(title.lowercased())"
        feedbackGenerator.notificationOccurred(.warning)
        playSound()
        speak(message)
    }

    private func playSound() {
        guard enableSound else { return }
        AudioServicesPlaySystemSound(1113)
    }

    private func speak(_ message: String) {
        guard enableVoice else { return }
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "cs-CZ") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        speaker.speak(utterance)
    }

    private func scheduleNotifications() {
        removeScheduledNotifications()

        guard !segments.isEmpty, isRunning else { return }

        var elapsed = secondsRemaining
        var requestIndex = 0
        var roundIndex = currentRound - 1
        var segmentIndex = currentSegmentIndex

        while roundIndex < rounds {
            let isLastSegment = roundIndex == rounds - 1 && segmentIndex == segments.count - 1

            if elapsed > 0 {
                let content = UNMutableNotificationContent()
                content.sound = .default

                if isLastSegment {
                    content.title = "Trenink dokoncen"
                    content.body = "Hotovo. Skvela prace."
                } else {
                    let nextTitle = nextTitleAfter(round: roundIndex, segment: segmentIndex)
                    content.title = "Zmena intervalu"
                    content.body = "Ted \(nextTitle.lowercased())."
                }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(elapsed), repeats: false)
                let id = "interval-run-coach-\(requestIndex)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                notificationCenter.add(request)
                requestIndex += 1
            }

            if isLastSegment {
                break
            }

            let nextPosition = nextPositionAfter(round: roundIndex, segment: segmentIndex)
            roundIndex = nextPosition.round
            segmentIndex = nextPosition.segment
            elapsed += segments[segmentIndex].durationSeconds
        }
    }

    private func nextTitleAfter(round: Int, segment: Int) -> String {
        let nextSegmentIndex = segment + 1
        if segments.indices.contains(nextSegmentIndex) {
            return segments[nextSegmentIndex].title
        }

        if round + 1 < rounds {
            return segments.first?.title ?? "Dalsi interval"
        }

        return "Konec"
    }

    private func scheduledNotificationIDs() -> [String] {
        let total = max(segments.count * rounds, 1)
        return (0..<total).map { "interval-run-coach-\($0)" }
    }

    private func removeScheduledNotifications() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: scheduledNotificationIDs())
    }

    private func nextPositionAfter(round: Int, segment: Int) -> (round: Int, segment: Int) {
        let nextSegmentIndex = segment + 1
        if segments.indices.contains(nextSegmentIndex) {
            return (round, nextSegmentIndex)
        }

        return (round + 1, 0)
    }

    func applyPreset(runSeconds: Int, walkSeconds: Int, rounds: Int) {
        guard !isRunning, !isPaused else { return }
        self.segments = [
            IntervalSegment(title: "Beh", durationSeconds: runSeconds),
            IntervalSegment(title: "Chuze", durationSeconds: walkSeconds)
        ]
        self.rounds = max(1, rounds)
        self.secondsRemaining = self.segments.first?.durationSeconds ?? 0
        save()
    }

    private func setIdleTimer(disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    private func refreshNotificationPermission() async {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationPermissionState = "Povoleno"
        case .denied:
            notificationPermissionState = "Zakazano"
        case .notDetermined:
            notificationPermissionState = "Nezjisteno"
        @unknown default:
            notificationPermissionState = "Nezname"
        }
    }
}

private struct SavedWorkoutConfig: Codable {
    var segments: [IntervalSegment]
    var rounds: Int
    var enableVoice: Bool
    var enableSound: Bool
}
