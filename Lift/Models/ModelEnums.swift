import Foundation

enum SessionStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case completed
    case endedNoProgression
    case abandoned
}

enum SetKind: String, Codable, CaseIterable, Sendable {
    case warmup
    case working
}

enum ProgressionReason: String, Codable, CaseIterable, Sendable {
    case success
    case manualDeload
    case manualEdit
    case reset
}

enum ProgramModelError: Error, Equatable, LocalizedError, Sendable {
    case duplicateExerciseInDay(programDayName: String, exerciseKey: String)

    var errorDescription: String? {
        switch self {
        case let .duplicateExerciseInDay(programDayName, exerciseKey):
            "Exercise \(exerciseKey) already exists in \(programDayName)."
        }
    }
}
