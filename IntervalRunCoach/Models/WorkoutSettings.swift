import Foundation

enum RepeatMode: String, Codable, CaseIterable, Identifiable {
    case unlimited
    case fixedRounds

    var id: String { rawValue }

    func title(in text: AppText) -> String {
        switch self {
        case .unlimited:
            return text.repeatUnlimited
        case .fixedRounds:
            return text.repeatFixedRounds
        }
    }
}

enum AudioMode: String, Codable, CaseIterable, Identifiable {
    case duck
    case mix
    case interrupt

    var id: String { rawValue }

    func title(in text: AppText) -> String {
        switch self {
        case .duck:
            return text.audioDuck
        case .mix:
            return text.audioMix
        case .interrupt:
            return text.audioInterrupt
        }
    }
}

enum AnnouncementType: String, Codable, CaseIterable, Identifiable {
    case voice
    case sound
    case voiceAndSound
    case off

    var id: String { rawValue }

    func title(in text: AppText) -> String {
        switch self {
        case .voice:
            return text.announcementVoice
        case .sound:
            return text.announcementSound
        case .voiceAndSound:
            return text.announcementVoiceAndSound
        case .off:
            return text.announcementOff
        }
    }

    var includesVoice: Bool {
        self == .voice || self == .voiceAndSound
    }

    var includesSound: Bool {
        self == .sound || self == .voiceAndSound
    }
}

enum AppLanguageSetting: String, Codable, CaseIterable, Identifiable {
    case system
    case czech
    case english
    case slovak

    var id: String { rawValue }

    func title(in text: AppText) -> String {
        switch self {
        case .system:
            return text.languageSystem
        case .czech:
            return text.languageCzech
        case .english:
            return "English"
        case .slovak:
            return text.languageSlovak
        }
    }

    var resolved: ResolvedAppLanguage {
        switch self {
        case .system:
            return ResolvedAppLanguage.systemDefault
        case .czech:
            return .czech
        case .english:
            return .english
        case .slovak:
            return .slovak
        }
    }
}

enum ResolvedAppLanguage {
    case czech
    case english
    case slovak

    static var systemDefault: ResolvedAppLanguage {
        let identifier = Locale.preferredLanguages.first?.lowercased() ?? ""

        if identifier.hasPrefix("cs") {
            return .czech
        }

        if identifier.hasPrefix("sk") {
            return .slovak
        }

        return .english
    }
}

enum VoiceLanguage: String, Codable, CaseIterable, Identifiable {
    case english

    var id: String { rawValue }

    var title: String {
        return "English"
    }

    var localeIdentifier: String {
        return "en-US"
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

struct AppText {
    let language: ResolvedAppLanguage

    var appTitle: String { "Interval" }
    var appSubtitle: String { "Run Coach" }

    var settingsTitle: String {
        switch language {
        case .czech: return "Nastaveni"
        case .english: return "Settings"
        case .slovak: return "Nastavenia"
        }
    }

    var settingsButtonLabel: String {
        switch language {
        case .czech: return "Otevrit nastaveni"
        case .english: return "Open settings"
        case .slovak: return "Otvorit nastavenia"
        }
    }

    var preparing: String {
        switch language {
        case .czech: return "Priprava"
        case .english: return "Get ready"
        case .slovak: return "Priprava"
        }
    }

    var ready: String {
        switch language {
        case .czech: return "Pripraveno"
        case .english: return "Ready"
        case .slovak: return "Pripravene"
        }
    }

    var round: String {
        switch language {
        case .czech: return "Kolo"
        case .english: return "Round"
        case .slovak: return "Kolo"
        }
    }

    var remaining: String {
        switch language {
        case .czech: return "Zbyva"
        case .english: return "Left"
        case .slovak: return "Zostava"
        }
    }

    var unlimited: String {
        switch language {
        case .czech: return "Neomezene"
        case .english: return "Unlimited"
        case .slovak: return "Neobmedzene"
        }
    }

    var next: String {
        switch language {
        case .czech: return "Dalsi"
        case .english: return "Next"
        case .slovak: return "Dalsi"
        }
    }

    var prepare: String {
        switch language {
        case .czech: return "Priprav se"
        case .english: return "Get ready"
        case .slovak: return "Priprav sa"
        }
    }

    var start: String {
        switch language {
        case .czech, .english, .slovak: return "Start"
        }
    }

    var finish: String {
        switch language {
        case .czech, .english, .slovak: return "Finish"
        }
    }

    var pause: String {
        switch language {
        case .czech: return "Pauza"
        case .english: return "Pause"
        case .slovak: return "Pauza"
        }
    }

    var resume: String {
        switch language {
        case .czech: return "Pokracovat"
        case .english: return "Resume"
        case .slovak: return "Pokracovat"
        }
    }

    var resetWithoutFinish: String {
        switch language {
        case .czech: return "Reset bez dokonceni"
        case .english: return "Reset without finish"
        case .slovak: return "Reset bez dokoncenia"
        }
    }

    var resetHint: String {
        switch language {
        case .czech: return "Zrusi trenink bez finish zvuku"
        case .english: return "Cancels the workout without the finish sound"
        case .slovak: return "Zrusi trening bez finish zvuku"
        }
    }

    var quickPresets: String {
        switch language {
        case .czech: return "Rychle presety"
        case .english: return "Quick presets"
        case .slovak: return "Rychle presety"
        }
    }

    var roundsShort: String {
        switch language {
        case .czech: return "kol"
        case .english: return "rounds"
        case .slovak: return "kol"
        }
    }

    var repeatTitle: String {
        switch language {
        case .czech: return "Opakovani"
        case .english: return "Repeats"
        case .slovak: return "Opakovanie"
        }
    }

    var repeatUnlimited: String {
        switch language {
        case .czech: return "Neomezene"
        case .english: return "Unlimited"
        case .slovak: return "Neobmedzene"
        }
    }

    var repeatFixedRounds: String {
        switch language {
        case .czech: return "Pocet kol"
        case .english: return "Round count"
        case .slovak: return "Pocet kol"
        }
    }

    func roundsCount(_ rounds: Int) -> String {
        switch language {
        case .czech: return "Pocet kol: \(rounds)"
        case .english: return "Rounds: \(rounds)"
        case .slovak: return "Pocet kol: \(rounds)"
        }
    }

    var music: String {
        switch language {
        case .czech: return "Hudba"
        case .english: return "Music"
        case .slovak: return "Hudba"
        }
    }

    var audioDuck: String {
        switch language {
        case .czech: return "Lehce ztisit hudbu"
        case .english: return "Gently lower music"
        case .slovak: return "Jemne stisit hudbu"
        }
    }

    var audioMix: String {
        switch language {
        case .czech: return "Hlas pres hudbu"
        case .english: return "Voice over music"
        case .slovak: return "Hlas cez hudbu"
        }
    }

    var audioInterrupt: String {
        switch language {
        case .czech: return "Prerusit hudbu"
        case .english: return "Interrupt music"
        case .slovak: return "Prerusit hudbu"
        }
    }

    var announcements: String {
        switch language {
        case .czech: return "Hlaseni"
        case .english: return "Announcements"
        case .slovak: return "Hlasenia"
        }
    }

    var announcementVoice: String {
        switch language {
        case .czech: return "Hlas"
        case .english: return "Voice"
        case .slovak: return "Hlas"
        }
    }

    var announcementSound: String {
        switch language {
        case .czech: return "Zvuk"
        case .english: return "Sound"
        case .slovak: return "Zvuk"
        }
    }

    var announcementVoiceAndSound: String {
        switch language {
        case .czech: return "Hlas + zvuk"
        case .english: return "Voice + sound"
        case .slovak: return "Hlas + zvuk"
        }
    }

    var announcementOff: String {
        switch language {
        case .czech: return "Vypnuto"
        case .english: return "Off"
        case .slovak: return "Vypnute"
        }
    }

    var appLanguage: String {
        switch language {
        case .czech: return "Jazyk aplikace"
        case .english: return "App language"
        case .slovak: return "Jazyk aplikacie"
        }
    }

    var voiceLanguage: String {
        switch language {
        case .czech: return "Jazyk hlasu"
        case .english: return "Voice language"
        case .slovak: return "Jazyk hlasu"
        }
    }

    var voiceLanguageNote: String {
        switch language {
        case .czech: return "Cesky a slovensky hlas pridame pozdeji."
        case .english: return "Czech and Slovak voices can be added later."
        case .slovak: return "Cesky a slovensky hlas pridame neskor."
        }
    }

    var languageSystem: String {
        switch language {
        case .czech: return "Podle systemu"
        case .english: return "System"
        case .slovak: return "Podla systemu"
        }
    }

    var languageCzech: String {
        switch language {
        case .czech: return "Cestina"
        case .english: return "Czech"
        case .slovak: return "Cestina"
        }
    }

    var languageSlovak: String {
        switch language {
        case .czech: return "Slovencina"
        case .english: return "Slovak"
        case .slovak: return "Slovencina"
        }
    }

    var notifications: String {
        switch language {
        case .czech: return "Notifikace"
        case .english: return "Notifications"
        case .slovak: return "Notifikacie"
        }
    }

    var allow: String {
        switch language {
        case .czech: return "Povolit"
        case .english: return "Allow"
        case .slovak: return "Povolit"
        }
    }

    var active: String {
        switch language {
        case .czech: return "Aktivni"
        case .english: return "Active"
        case .slovak: return "Aktivne"
        }
    }

    var permissionAllowed: String {
        switch language {
        case .czech: return "Povoleno"
        case .english: return "Allowed"
        case .slovak: return "Povolene"
        }
    }

    var permissionDenied: String {
        switch language {
        case .czech: return "Zakazano"
        case .english: return "Denied"
        case .slovak: return "Zakazane"
        }
    }

    var permissionUnknown: String {
        switch language {
        case .czech: return "Nezjisteno"
        case .english: return "Unknown"
        case .slovak: return "Nezistene"
        }
    }

    var intervals: String {
        switch language {
        case .czech: return "Intervaly"
        case .english: return "Intervals"
        case .slovak: return "Intervaly"
        }
    }

    var dragToReorder: String {
        switch language {
        case .czech: return "Podrz a presun"
        case .english: return "Hold and drag"
        case .slovak: return "Podrz a presun"
        }
    }

    var addInterval: String {
        switch language {
        case .czech: return "Pridat interval"
        case .english: return "Add interval"
        case .slovak: return "Pridat interval"
        }
    }

    var newIntervalTitle: String {
        switch language {
        case .czech: return "Novy interval"
        case .english: return "New interval"
        case .slovak: return "Novy interval"
        }
    }

    var runIntervalTitle: String {
        switch language {
        case .czech: return "Beh"
        case .english: return "Run"
        case .slovak: return "Beh"
        }
    }

    var walkIntervalTitle: String {
        switch language {
        case .czech: return "Chuze"
        case .english: return "Walk"
        case .slovak: return "Chodza"
        }
    }

    var intervalNamePlaceholder: String {
        switch language {
        case .czech: return "Nazev intervalu"
        case .english: return "Interval name"
        case .slovak: return "Nazov intervalu"
        }
    }

    var deleteInterval: String {
        switch language {
        case .czech: return "Smazat interval"
        case .english: return "Delete interval"
        case .slovak: return "Zmazat interval"
        }
    }

    var minutes: String {
        switch language {
        case .czech: return "Minuty"
        case .english: return "Minutes"
        case .slovak: return "Minuty"
        }
    }

    var seconds: String {
        switch language {
        case .czech: return "Sekundy"
        case .english: return "Seconds"
        case .slovak: return "Sekundy"
        }
    }

    var duration: String {
        switch language {
        case .czech: return "Delka"
        case .english: return "Duration"
        case .slovak: return "Dlzka"
        }
    }

    var remainingTimeAccessibility: String {
        switch language {
        case .czech: return "Zbyvajici cas"
        case .english: return "Remaining time"
        case .slovak: return "Zostavajuci cas"
        }
    }

    var progressAccessibility: String {
        switch language {
        case .czech: return "Prubeh treninku"
        case .english: return "Workout progress"
        case .slovak: return "Priebeh treningu"
        }
    }

    func progressValue(_ progress: Double) -> String {
        let percent = Int(progress * 100)
        switch language {
        case .czech: return "\(percent) procent"
        case .english: return "\(percent) percent"
        case .slovak: return "\(percent) percent"
        }
    }
}
