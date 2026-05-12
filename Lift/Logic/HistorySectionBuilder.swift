import Foundation

/// A month-grouping of completed/abandoned/endedNoProgression workout sessions for display in History.
struct HistorySection: Identifiable {
    let monthKey: String
    let title: String
    let sessions: [WorkoutSession]

    var id: String { monthKey }
}

enum HistorySectionBuilder {
    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter
    }()

    private static let monthKeyParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static func sections(from sessions: [WorkoutSession]) -> [HistorySection] {
        let groups = Dictionary(grouping: sessions) { String($0.workoutDayID.prefix(7)) }
        let monthKeys = groups.keys.sorted(by: >)
        return monthKeys.map { monthKey in
            let ordered = (groups[monthKey] ?? []).sorted { $0.startedAt > $1.startedAt }
            return HistorySection(
                monthKey: monthKey,
                title: title(forMonthKey: monthKey),
                sessions: ordered
            )
        }
    }

    static func title(forMonthKey monthKey: String) -> String {
        guard let date = monthKeyParser.date(from: monthKey) else { return monthKey }
        return titleFormatter.string(from: date)
    }
}
