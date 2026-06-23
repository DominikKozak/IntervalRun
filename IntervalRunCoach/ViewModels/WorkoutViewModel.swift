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
    @Published var appLanguage: AppLanguageSetting = .system
    @Published var voiceLanguage: VoiceLanguage = .english
    @Published var voiceIdentifier: String?
    @Published private(set) var notificationPermissionStatus: NotificationPermissionStatus = .unknown

    private let saveKey = "savedWorkoutConfig"
    private let maxScheduledNotifications = 64
    private let notificationCenter = UNUserNotificationCenter.current()
    private let audioCueManager = AudioCueManager()
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var timer: Timer?

    var isWorkoutActive: Bool {
        isRunning || isPaused || countdownToStart > 0
    }

    var resolvedAppLanguage: ResolvedAppLanguage {
        appLanguage.resolved
    }

    var text: AppText {
        AppText(language: resolvedAppLanguage)
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
            return "\(text.round) \(currentRound)"
        case .fixedRounds:
            return "\(text.round) \(currentRound)/\(rounds)"
        }
    }

    var remainingSummaryText: String {
        switch repeatMode {
        case .unlimited:
            return text.unlimited
        case .fixedRounds:
            return format(seconds: totalRemainingSeconds)
        }
    }

    var notificationPermissionText: String {
        switch notificationPermissionStatus {
        case .allowed:
            return text.permissionAllowed
        case .denied:
            return text.permissionDenied
        case .unknown:
            return text.permissionUnknown
        }
    }

    func addSegment() {
        segments.append(IntervalSegment(title: text.newIntervalTitle, durationSeconds: 60))
        syncIdlePreviewState()
        save()
    }

    func removeSegments(at offsets: IndexSet) {
        segments.remove(atOffsets: offsets)
        if segments.isEmpty {
            segments = .starterIntervals(for: resolvedAppLanguage)
        }
        syncIdlePreviewState()
        save()
    }

    func moveSegments(from source: IndexSet, to destination: Int) {
        segments.move(fromOffsets: source, toOffset: destination)
        syncIdlePreviewState()
        save()
    }

    func moveSegment(draggedID: UUID, over targetID: UUID) {
        guard !isWorkoutActive,
              draggedID != targetID,
              let sourceIndex = segments.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = segments.firstIndex(where: { $0.id == targetID }) else { return }

        let segment = segments.remove(at: sourceIndex)
        segments.insert(segment, at: targetIndex)
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
            repeatMode = saved.repeatMode
            rounds = max(1, saved.rounds)
            audioMode = saved.audioMode
            announcementType = saved.announcementType
            appLanguage = saved.appLanguage
            voiceLanguage = saved.voiceLanguage
            voiceIdentifier = saved.voiceIdentifier
            segments = saved.segments.isEmpty ? .starterIntervals(for: resolvedAppLanguage) : saved.segments
        } else {
            repeatMode = .unlimited
            appLanguage = .system
            voiceLanguage = .english
            segments = .starterIntervals(for: resolvedAppLanguage)
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
            appLanguage: appLanguage,
            voiceLanguage: voiceLanguage,
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
                    voiceLanguage: voiceLanguage,
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
            voiceLanguage: voiceLanguage,
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
            voiceLanguage: voiceLanguage,
            voiceIdentifier: voiceIdentifier
        )
    }

    private var finishPhrase: String {
        return "Done. Workout finished."
    }

    private func announcementPhrase(prefix: String, segment: IntervalSegment) -> String {
        let englishPrefix = prefix == "Start" ? "Start" : "Now"
        let spokenTitle = englishCueTitle(for: segment)
        return "\(englishPrefix) \(spokenTitle)"
    }

    private func englishCueTitle(for segment: IntervalSegment) -> String {
        switch segment.cueRole {
        case .run:
            return "run"
        case .walk:
            return "walk"
        case .finish:
            return "finish"
        case .neutral:
            return segment.displayTitle.lowercased()
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
                    content.title = notificationFinishedTitle
                    content.body = notificationFinishedBody
                } else {
                    let nextTitle = nextTitleAfter(round: roundIndex, segment: segmentIndex)
                    content.title = notificationChangeTitle
                    content.body = "\(text.next) \(nextTitle.lowercased())."
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
            return segments.first?.displayTitle ?? text.intervals
        }

        return text.finish
    }

    private var notificationFinishedTitle: String {
        switch resolvedAppLanguage {
        case .czech:
            return "Trenink dokoncen"
        case .english:
            return "Workout complete"
        case .slovak:
            return "Trening dokonceny"
        }
    }

    private var notificationFinishedBody: String {
        switch resolvedAppLanguage {
        case .czech:
            return "Hotovo. Skvela prace."
        case .english:
            return "Done. Great work."
        case .slovak:
            return "Hotovo. Skvela praca."
        }
    }

    private var notificationChangeTitle: String {
        switch resolvedAppLanguage {
        case .czech:
            return "Zmena intervalu"
        case .english:
            return "Interval change"
        case .slovak:
            return "Zmena intervalu"
        }
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
            IntervalSegment(title: text.runIntervalTitle, durationSeconds: runSeconds, cueRole: .run),
            IntervalSegment(title: text.walkIntervalTitle, durationSeconds: walkSeconds, cueRole: .walk)
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
            notificationPermissionStatus = .allowed
        case .denied:
            notificationPermissionStatus = .denied
        case .notDetermined:
            notificationPermissionStatus = .unknown
        @unknown default:
            notificationPermissionStatus = .unknown
        }
    }

    private func syncIdlePreviewState() {
        guard !isWorkoutActive else { return }
        currentSegmentIndex = 0
        currentRound = 1
        secondsRemaining = segments.first?.durationSeconds ?? 0
    }
}

enum NotificationPermissionStatus {
    case allowed
    case denied
    case unknown
}

private struct SavedWorkoutConfig: Codable {
    var segments: [IntervalSegment]
    var rounds: Int
    var repeatMode: RepeatMode
    var audioMode: AudioMode
    var announcementType: AnnouncementType
    var appLanguage: AppLanguageSetting
    var voiceLanguage: VoiceLanguage
    var voiceIdentifier: String?

    private enum CodingKeys: String, CodingKey {
        case segments
        case rounds
        case repeatMode
        case audioMode
        case announcementType
        case appLanguage
        case voiceLanguage
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
        appLanguage: AppLanguageSetting,
        voiceLanguage: VoiceLanguage,
        voiceIdentifier: String?
    ) {
        self.segments = segments
        self.rounds = rounds
        self.repeatMode = repeatMode
        self.audioMode = audioMode
        self.announcementType = announcementType
        self.appLanguage = appLanguage
        self.voiceLanguage = voiceLanguage
        self.voiceIdentifier = voiceIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        segments = try container.decodeIfPresent([IntervalSegment].self, forKey: .segments) ?? []
        rounds = try container.decodeIfPresent(Int.self, forKey: .rounds) ?? 6
        repeatMode = try container.decodeIfPresent(RepeatMode.self, forKey: .repeatMode) ?? .unlimited
        audioMode = try container.decodeIfPresent(AudioMode.self, forKey: .audioMode) ?? .duck
        voiceLanguage = try container.decodeIfPresent(VoiceLanguage.self, forKey: .voiceLanguage) ?? .english
        voiceIdentifier = try container.decodeIfPresent(String.self, forKey: .voiceIdentifier)

        if let savedAppLanguage = try container.decodeIfPresent(AppLanguageSetting.self, forKey: .appLanguage) {
            appLanguage = savedAppLanguage
        } else if let oldAnnouncementLanguage = try container.decodeIfPresent(String.self, forKey: .announcementLanguage) {
            appLanguage = oldAnnouncementLanguage == "english" ? .english : .czech
        } else {
            appLanguage = .system
        }

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
        try container.encode(appLanguage, forKey: .appLanguage)
        try container.encode(voiceLanguage, forKey: .voiceLanguage)
        try container.encodeIfPresent(voiceIdentifier, forKey: .voiceIdentifier)
    }
}
