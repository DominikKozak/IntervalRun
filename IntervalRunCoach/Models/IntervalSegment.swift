import Foundation

struct IntervalSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var durationSeconds: Int

    init(id: UUID = UUID(), title: String, durationSeconds: Int) {
        self.id = id
        self.title = title
        self.durationSeconds = max(5, durationSeconds)
    }

    var durationDescription: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Array where Element == IntervalSegment {
    static let starterIntervals: [IntervalSegment] = [
        IntervalSegment(title: "Beh", durationSeconds: 60),
        IntervalSegment(title: "Chuze", durationSeconds: 180)
    ]
}

