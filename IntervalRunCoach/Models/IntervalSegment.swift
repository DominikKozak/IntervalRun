import Foundation

struct IntervalSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var durationSeconds: Int
    var cueRole: IntervalCueRole

    init(id: UUID = UUID(), title: String, durationSeconds: Int, cueRole: IntervalCueRole? = nil) {
        self.id = id
        self.title = title
        self.durationSeconds = max(5, durationSeconds)
        self.cueRole = cueRole ?? IntervalCueRole.inferred(from: title)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case durationSeconds
        case cueRole
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        durationSeconds = max(5, try container.decode(Int.self, forKey: .durationSeconds))
        cueRole = try container.decodeIfPresent(IntervalCueRole.self, forKey: .cueRole)
            ?? IntervalCueRole.inferred(from: title)
    }

    var durationDescription: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Interval" : trimmedTitle
    }
}

extension Array where Element == IntervalSegment {
    static let starterIntervals: [IntervalSegment] = [
        IntervalSegment(title: "Beh", durationSeconds: 60, cueRole: .run),
        IntervalSegment(title: "Chuze", durationSeconds: 180, cueRole: .walk)
    ]

    static func starterIntervals(for language: ResolvedAppLanguage) -> [IntervalSegment] {
        let text = AppText(language: language)
        return [
            IntervalSegment(title: text.runIntervalTitle, durationSeconds: 60, cueRole: .run),
            IntervalSegment(title: text.walkIntervalTitle, durationSeconds: 180, cueRole: .walk)
        ]
    }
}
