import Foundation

enum RepeatMode: String, Codable, CaseIterable, Identifiable {
    case unlimited
    case fixedRounds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimited:
            return "Neomezene"
        case .fixedRounds:
            return "Pocet kol"
        }
    }
}

enum AudioMode: String, Codable, CaseIterable, Identifiable {
    case duck
    case mix
    case interrupt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duck:
            return "Lehce ztisit hudbu"
        case .mix:
            return "Hlas pres hudbu"
        case .interrupt:
            return "Prerusit hudbu"
        }
    }
}

enum AnnouncementType: String, Codable, CaseIterable, Identifiable {
    case voice
    case sound
    case voiceAndSound
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice:
            return "Hlas"
        case .sound:
            return "Zvuk"
        case .voiceAndSound:
            return "Hlas + zvuk"
        case .off:
            return "Vypnuto"
        }
    }

    var includesVoice: Bool {
        self == .voice || self == .voiceAndSound
    }

    var includesSound: Bool {
        self == .sound || self == .voiceAndSound
    }
}

enum AnnouncementLanguage: String, Codable, CaseIterable, Identifiable {
    case czech
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .czech:
            return "Cestina"
        case .english:
            return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .czech:
            return "cs-CZ"
        case .english:
            return "en-US"
        }
    }
}

enum IntervalCueRole: String, Codable, CaseIterable, Identifiable {
    case run
    case walk
    case neutral
    case finish

    var id: String { rawValue }

    var audioResourceName: String {
        switch self {
        case .run:
            return "cue-run"
        case .walk:
            return "cue-walk"
        case .finish:
            return "cue-finish"
        case .neutral:
            return "cue-run"
        }
    }

    static func inferred(from title: String) -> IntervalCueRole {
        let normalized = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("chuz") || normalized.contains("walk") {
            return .walk
        }

        if normalized.contains("beh") || normalized.contains("run") {
            return .run
        }

        return .neutral
    }
}
