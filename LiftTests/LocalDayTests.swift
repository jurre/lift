import Foundation
import Testing
@testable import Lift

@Suite("LocalDay")
struct LocalDayTests {
    @Test("local day id respects time zone boundaries")
    func localDayRespectsTimeZoneBoundaries() throws {
        let date = try #require(iso8601.date(from: "2024-12-31T23:30:00Z"))

        #expect(LocalDay.id(for: date, in: try #require(TimeZone(identifier: "America/Los_Angeles"))) == "2024-12-31")
        #expect(LocalDay.id(for: date, in: try #require(TimeZone(identifier: "Pacific/Auckland"))) == "2025-01-01")
    }

    @Test("dst transition days still format correctly")
    func dstTransitionDay() throws {
        let date = try #require(iso8601.date(from: "2024-03-10T10:30:00Z"))

        #expect(LocalDay.id(for: date, in: try #require(TimeZone(identifier: "America/Los_Angeles"))) == "2024-03-10")
    }

    private var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
