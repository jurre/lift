import Foundation
import SwiftData
import Testing
@testable import Lift

@MainActor
@Suite("SettingsViewModel — gating")
struct SettingsViewModelGatingTests {
    @Test("canEditProgression is true when no draft session exists")
    func canEditWithoutDraft() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()
        #expect(viewModel.hasActiveDraft == false)
    }

    @Test("canEditProgression is false when a draft session exists")
    func cannotEditWithDraft() throws {
        let fixture = try SettingsFixture()
        try fixture.makeDraftSession()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()
        #expect(viewModel.hasActiveDraft == true)
    }

    @Test("editing weight throws when a draft exists")
    func editWeightThrowsDuringDraft() throws {
        let fixture = try SettingsFixture()
        try fixture.makeDraftSession()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        #expect(throws: SettingsViewModelError.lockedDuringActiveDraft) {
            try viewModel.editCurrentWeight(progression: progression, newWeightKg: 100)
        }
    }

    @Test("editing increment throws when a draft exists")
    func editIncrementThrowsDuringDraft() throws {
        let fixture = try SettingsFixture()
        try fixture.makeDraftSession()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        #expect(throws: SettingsViewModelError.lockedDuringActiveDraft) {
            try viewModel.editIncrement(progression: progression, kg: 5.0)
        }
    }
}

@MainActor
@Suite("SettingsViewModel — manual weight edit")
struct SettingsViewModelEditWeightTests {
    @Test("snaps the new weight via WeightLoading and writes a manualEdit event")
    func snapsAndWritesEvent() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        let oldWeight = progression.currentWeightKg

        try viewModel.editCurrentWeight(progression: progression, newWeightKg: 62.0)

        #expect(progression.currentWeightKg == 62.5)
        let events = try fetchAll(ProgressionEvent.self, from: fixture.context)
        let event = try #require(events.first(where: { $0.exerciseProgression?.exercise?.key == "squat" }))
        #expect(event.reason == .manualEdit)
        #expect(event.oldWeightKg == oldWeight)
        #expect(event.newWeightKg == 62.5)
    }

    @Test("does not write an event when the snapped weight is unchanged")
    func noEventWhenUnchanged() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        progression.currentWeightKg = 60
        try fixture.context.save()

        try viewModel.editCurrentWeight(progression: progression, newWeightKg: 60)

        let events = try fetchAll(ProgressionEvent.self, from: fixture.context)
        #expect(events.contains(where: { $0.exerciseProgression?.exercise?.key == "squat" }) == false)
    }

    @Test("clears stalledCount when manually lowering the weight")
    func clearsStallOnLower() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        progression.currentWeightKg = 80
        progression.stalledCount = 3
        try fixture.context.save()

        try viewModel.editCurrentWeight(progression: progression, newWeightKg: 70)

        #expect(progression.currentWeightKg == 70)
        #expect(progression.stalledCount == 0)
    }

    @Test("preserves stalledCount when manually raising the weight")
    func preservesStallOnHigher() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        progression.currentWeightKg = 60
        progression.stalledCount = 2
        try fixture.context.save()

        try viewModel.editCurrentWeight(progression: progression, newWeightKg: 70)

        #expect(progression.currentWeightKg == 70)
        #expect(progression.stalledCount == 2)
    }
}

@MainActor
@Suite("SettingsViewModel — manual deload")
struct SettingsViewModelDeloadTests {
    @Test("uses Progression.deload, writes manualDeload event, clears stalledCount")
    func deloadSquat() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        progression.currentWeightKg = 100
        progression.stalledCount = 3
        try fixture.context.save()

        try viewModel.deload(progression: progression)

        // 100 * 0.9 = 90 → snap to 90 (loadable in default inventory)
        #expect(progression.currentWeightKg == 90)
        #expect(progression.stalledCount == 0)

        let events = try fetchAll(ProgressionEvent.self, from: fixture.context)
        let event = try #require(events.first(where: { $0.exerciseProgression?.exercise?.key == "squat" }))
        #expect(event.reason == .manualDeload)
    }

    @Test("never deloads below the bar weight")
    func deloadFloorAtBar() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        progression.currentWeightKg = 22.5
        try fixture.context.save()

        try viewModel.deload(progression: progression)

        let user = try #require(viewModel.user)
        #expect(progression.currentWeightKg == user.barWeightKg)
    }
}

@MainActor
@Suite("SettingsViewModel — reset progression")
struct SettingsViewModelResetProgressionTests {
    @Test("resets one progression to bar weight, clears state, writes reset event")
    func resetSquat() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        progression.currentWeightKg = 80
        progression.stalledCount = 5
        progression.lastProgressionAt = .now
        try fixture.context.save()

        try viewModel.resetProgression(progression)

        let user = try #require(viewModel.user)
        #expect(progression.currentWeightKg == user.barWeightKg)
        #expect(progression.stalledCount == 0)
        #expect(progression.lastProgressionAt == nil)

        let events = try fetchAll(ProgressionEvent.self, from: fixture.context)
        let event = try #require(events.first(where: { $0.exerciseProgression?.exercise?.key == "squat" }))
        #expect(event.reason == .reset)
        #expect(event.newWeightKg == user.barWeightKg)
    }
}

@MainActor
@Suite("SettingsViewModel — sets/reps/rest/increment edits")
struct SettingsViewModelMetadataEditTests {
    @Test("editing increment, rest, sets, reps does not write a ProgressionEvent")
    func editsDoNotWriteEvents() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "bench" }))
        try viewModel.editIncrement(progression: progression, kg: 2.5)
        try viewModel.editRestSeconds(progression: progression, seconds: 90)
        try viewModel.editWorkingSets(progression: progression, count: 5)
        try viewModel.editWorkingReps(progression: progression, reps: 10)

        #expect(progression.incrementKg == 2.5)
        #expect(progression.restSeconds == 90)
        #expect(progression.workingSets == 5)
        #expect(progression.workingReps == 10)

        let events = try fetchAll(ProgressionEvent.self, from: fixture.context)
        #expect(events.isEmpty)
    }

    @Test("clamps invalid values to safe minimums")
    func clampsToMinimums() throws {
        let fixture = try SettingsFixture()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "bench" }))
        try viewModel.editWorkingSets(progression: progression, count: 0)
        try viewModel.editWorkingReps(progression: progression, reps: 0)
        try viewModel.editIncrement(progression: progression, kg: -5)
        try viewModel.editRestSeconds(progression: progression, seconds: -10)

        #expect(progression.workingSets >= 1)
        #expect(progression.workingReps >= 1)
        #expect(progression.incrementKg > 0)
        #expect(progression.restSeconds >= 0)
    }
}

@MainActor
@Suite("SettingsViewModel — reset all data")
struct SettingsViewModelResetAllTests {
    @Test("resetAllData deletes everything and re-seeds the defaults")
    func resetAll() throws {
        let fixture = try SettingsFixture()
        try fixture.makeDraftSession()
        let viewModel = SettingsViewModel(modelContext: fixture.context)
        viewModel.refresh()

        let progression = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        progression.currentWeightKg = 100
        progression.stalledCount = 5
        try fixture.context.save()

        try viewModel.resetAllData()

        let sessions = try fetchAll(WorkoutSession.self, from: fixture.context)
        let events = try fetchAll(ProgressionEvent.self, from: fixture.context)
        #expect(sessions.isEmpty)
        #expect(events.isEmpty)

        viewModel.refresh()
        let user = try #require(viewModel.user)
        let resetSquat = try #require(viewModel.progressions.first(where: { $0.exercise?.key == "squat" }))
        #expect(resetSquat.currentWeightKg == user.barWeightKg)
        #expect(resetSquat.stalledCount == 0)
    }
}

// MARK: - Fixture

@MainActor
private struct SettingsFixture {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try makeInMemoryContainer()
        context = container.mainContext
        try LiftSeeder().seedIfNeeded(in: context)
    }

    func makeDraftSession() throws {
        let service = try DraftSessionService(modelContext: context)
        let dayDescriptor = FetchDescriptor<ProgramDay>(sortBy: [SortDescriptor(\ProgramDay.orderInRotation)])
        let day = try #require(try context.fetch(dayDescriptor).first)
        _ = try service.createDraft(for: day)
    }
}
