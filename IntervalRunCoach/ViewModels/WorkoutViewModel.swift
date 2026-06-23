import Foundation
import UIKit
import UserNotifications

@MainActor
final class WorkoutViewModel: NSObject, ObservableObject {
    @Published var segments: [IntervalSegment] = []
    @Published var repeatMode: RepeatMode = .unlimited
    @Published var rounds: Int = 6
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var currentSegmentIndex = 0
    @Published var currentRound = 1
    @Published var secondsRemaining = 0
    @Published var countdownToStart = 0
    @Published var audioMode: AudioMode = .duck
    @Published var announcementType: AnnouncementType = .voiceAndSound
    @Published var announcementLanguage: AnnouncementLanguage = .czech
    @Published var voiceIdentifier: String?
    @Published var notificationPermissionState = "Nezjisteno"

    private let saveKey = "savedWorkoutConfig"
    private let maxScheduledNotifications = 64
    private let notificationCenter = UNUserNotificationCenter.current()
    private let audioCueManager = AudioCueManager()
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var timer: Timer?

    var isWorkoutActive: Bool {
        isRunning || isPaused || countdownToStart > 0
    }

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

        if repeatMode == .unlimited || currentRound < rounds {
            return segments.first
        }

        return nil
    }

    var totalWorkoutSeconds: Int {
        guard repeatMode == .fixedRounds else {
            return segments.reduce(0) { $0 + $1.durationSeconds }
        }
        return segments.reduce(0) { $0 + $1.durationSeconds } * max(rounds, 1)
    }

    var totalWorkoutDescription: String {
        format(seconds: totalWorkoutSeconds)
    }

    var totalRemainingSeconds: Int {
        guard !segments.isEmpty else { return 0 }
        guard repeatMode == .fixedRounds else { return secondsRemaining }

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
        if repeatMode == .unlimited {
            guard let currentSegment, currentSegment.durationSeconds > 0 else { return 0 }
            return min(max(Double(currentSegment.durationSeconds - secondsRemaining) / Double(currentSegment.durationSeconds), 0), 1)
        }

        guard totalWorkoutSeconds > 0 else { return 0 }
        return min(max(Double(totalWorkoutSeconds - totalRemainingSeconds) / Double(totalWorkoutSeconds), 0), 1)
    }

    var roundSummaryText: String {
        switch repeatMode {
        case .unlimited:
            return "Kolo \(currentRound)"
        case .fixedRounds:
            return "Kolo \(currentRound)/\(rounds)"
        }
    }

    var remainingSummaryText: String {
        switch repeatMode {
        case .unlimited:
            return "Neomezene"
        case .fixedRounds:
            return format(seconds: totalRemainingSeconds)
        }
    }

    func addSegment() {
        segments.append(IntervalSegment(title: "Novy interval", durationSeconds: 60))
        syncIdlePreviewState()
        save()
    }

    func removeSegments(at offsets: IndexSet) {
        segments.remove(atOffsets: offsets)
        if segments.isEmpty {
            segments = .starterIntervals
        }
        syncIdlePreviewState()
        save()
    }

    func moveSegments(from source: IndexSet, to destination: Int) {
        segments.move(fromOffsets: source, toOffset: destination)
        syncIdlePreviewState()
        save()
    }

    func updateSegment(id: UUID, title: String, minutes: Int, seconds: Int) {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        let clampedMinutes = max(0, minutes)
        let clampedSeconds = min(max(0, seconds), 59)
        let totalSeconds = max(5, (clampedMinutes * 60) + clampedSeconds)
        segments[index].title = title
        segments[index].durationSeconds = totalSeconds
        segments[index].cueRole = IntervalCueRole.inferred(from: segments[index].displayTitle)
        syncIdlePreviewState()
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

    func finishWorkout() {
        finishWorkout(playCue: true)
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
            repeatMode = saved.repeatMode
            rounds = max(1, saved.rounds)
            audioMode = saved.audioMode
            announcementType = saved.announcementType
            announcementLanguage = saved.announcementLanguage
            voiceIdentifier = saved.voiceIdentifier
        } else {
            segments = .starterIntervals
            repeatMode = .unlimited
        }

        secondsRemaining = segments.first?.durationSeconds ?? 0
    }

    func save() {
        let config = SavedWorkoutConfig(
            segments: segments,
            rounds: rounds,
            repeatMode: repeatMode,
            audioMode: audioMode,
            announcementType: announcementType,
            announcementLanguage: announcementLanguage,
            voiceIdentifier: voiceIdentifier
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
                audioCueManager.speakCountdown(
                    "\(countdownToStart)",
                    audioMode: audioMode,
                    announcementType: announcementType,
                    language: announcementLanguage,
                    voiceIdentifier: voiceIdentifier
                )
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
        } else if repeatMode == .unlimited {
            currentRound += 1
            currentSegmentIndex = 0
        } else if currentRound < rounds {
            currentRound += 1
            currentSegmentIndex = 0
        } else {
            finishWorkout(playCue: true)
            return
        }

        secondsRemaining = segments[currentSegmentIndex].durationSeconds
        announceCurrentSegment(prefix: "Ted")
    }

    private func finishWorkout(playCue: Bool) {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        countdownToStart = 0
        secondsRemaining = 0
        removeScheduledNotifications()
        setIdleTimer(disabled: false)
        feedbackGenerator.notificationOccurred(.success)
        guard playCue else { return }
        audioCueManager.playAnnouncement(
            role: .finish,
            phrase: finishPhrase,
            audioMode: audioMode,
            announcementType: announcementType,
            language: announcementLanguage,
            voiceIdentifier: voiceIdentifier
        )
    }

    private func announceCurrentSegment(prefix: String) {
        guard let currentSegment else { return }
        let message = announcementPhrase(prefix: prefix, segment: currentSegment)
        feedbackGenerator.notificationOccurred(.warning)
        audioCueManager.playAnnouncement(
            role: currentSegment.cueRole,
            phrase: message,
            audioMode: audioMode,
            announcementType: announcementType,
            language: announcementLanguage,
            voiceIdentifier: voiceIdentifier
        )
    }

    private var finishPhrase: String {
        switch announcementLanguage {
        case .czech:
            return "Hotovo. Trenink skoncil."
        case .english:
            return "Done. Workout finished."
        }
    }

    private func announcementPhrase(prefix: String, segment: IntervalSegment) -> String {
        let title = segment.displayTitle.lowercased()

        switch announcementLanguage {
        case .czech:
            return "\(prefix) \(title)"
        case .english:
            let englishPrefix = prefix == "Start" ? "Start" : "Now"
            return "\(englishPrefix) \(title)"
        }
    }

    private func scheduleNotifications() {
        removeScheduledNotifications()

        guard !segments.isEmpty, isRunning else { return }

        var elapsed = secondsRemaining
        var requestIndex = 0
        var roundIndex = currentRound - 1
        var segmentIndex = currentSegmentIndex

        while requestIndex < notificationScheduleLimit {
            let isLastSegment = repeatMode == .fixedRounds
                && roundIndex == rounds - 1
                && segmentIndex == segments.count - 1

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
            return segments[nextSegmentIndex].displayTitle
        }

        if repeatMode == .unlimited || round + 1 < rounds {
            return segments.first?.displayTitle ?? "Dalsi interval"
        }

        return "Konec"
    }

    private func scheduledNotificationIDs() -> [String] {
        let total = max(notificationScheduleLimit, 1)
        return (0..<total).map { "interval-run-coach-\($0)" }
    }

    private var notificationScheduleLimit: Int {
        switch repeatMode {
        case .unlimited:
            return maxScheduledNotifications
        case .fixedRounds:
            return max(segments.count * rounds, 1)
        }
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
            IntervalSegment(title: "Beh", durationSeconds: runSeconds, cueRole: .run),
            IntervalSegment(title: "Chuze", durationSeconds: walkSeconds, cueRole: .walk)
        ]
        self.repeatMode = .fixedRounds
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

    private func syncIdlePreviewState() {
        guard !isWorkoutActive else { return }
        currentSegmentIndex = 0
        currentRound = 1
        secondsRemaining = segments.first?.durationSeconds ?? 0
    }
}

private struct SavedWorkoutConfig: Codable {
    var segments: [IntervalSegment]
    var rounds: Int
    var repeatMode: RepeatMode
    var audioMode: AudioMode
    var announcementType: AnnouncementType
    var announcementLanguage: AnnouncementLanguage
    var voiceIdentifier: String?

    private enum CodingKeys: String, CodingKey {
        case segments
        case rounds
        case repeatMode
        case audioMode
        case announcementType
        case announcementLanguage
        case voiceIdentifier
        case enableVoice
        case enableSound
    }

    init(
        segments: [IntervalSegment],
        rounds: Int,
        repeatMode: RepeatMode,
        audioMode: AudioMode,
        announcementType: AnnouncementType,
        announcementLanguage: AnnouncementLanguage,
        voiceIdentifier: String?
    ) {
        self.segments = segments
        self.rounds = rounds
        self.repeatMode = repeatMode
        self.audioMode = audioMode
        self.announcementType = announcementType
        self.announcementLanguage = announcementLanguage
        self.voiceIdentifier = voiceIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        segments = try container.decodeIfPresent([IntervalSegment].self, forKey: .segments) ?? []
        rounds = try container.decodeIfPresent(Int.self, forKey: .rounds) ?? 6
        repeatMode = try container.decodeIfPresent(RepeatMode.self, forKey: .repeatMode) ?? .unlimited
        audioMode = try container.decodeIfPresent(AudioMode.self, forKey: .audioMode) ?? .duck
        announcementLanguage = try container.decodeIfPresent(AnnouncementLanguage.self, forKey: .announcementLanguage) ?? .czech
        voiceIdentifier = try container.decodeIfPresent(String.self, forKey: .voiceIdentifier)

        if let savedAnnouncementType = try container.decodeIfPresent(AnnouncementType.self, forKey: .announcementType) {
            announcementType = savedAnnouncementType
        } else {
            let oldVoice = try container.decodeIfPresent(Bool.self, forKey: .enableVoice) ?? true
            let oldSound = try container.decodeIfPresent(Bool.self, forKey: .enableSound) ?? true

            switch (oldVoice, oldSound) {
            case (true, true):
                announcementType = .voiceAndSound
            case (true, false):
                announcementType = .voice
            case (false, true):
                announcementType = .sound
            case (false, false):
                announcementType = .off
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(segments, forKey: .segments)
        try container.encode(rounds, forKey: .rounds)
        try container.encode(repeatMode, forKey: .repeatMode)
        try container.encode(audioMode, forKey: .audioMode)
        try container.encode(announcementType, forKey: .announcementType)
        try container.encode(announcementLanguage, forKey: .announcementLanguage)
        try container.encodeIfPresent(voiceIdentifier, forKey: .voiceIdentifier)
    }
}
