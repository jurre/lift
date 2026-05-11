import Foundation
import SwiftData

struct LiftSeeder {
    func seedIfNeeded(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Exercise>()) == 0 else {
            return
        }

        let user = User(displayName: "", barWeightKg: 20, defaultIncrementKg: 1.25)
        context.insert(user)

        let exercises = [
            ("squat", "Squat"),
            ("bench", "Bench"),
            ("row", "Row"),
            ("ohp", "OHP"),
            ("deadlift", "Deadlift")
        ].reduce(into: [String: Exercise]()) { result, item in
            let exercise = Exercise(key: item.0, name: item.1)
            context.insert(exercise)
            result[item.0] = exercise
        }

        let progressions = try [
            makeProgression(for: "squat", exercises: exercises, user: user, restSeconds: 180, sets: 3, reps: 5),
            makeProgression(for: "bench", exercises: exercises, user: user, restSeconds: 120, sets: 3, reps: 5),
            makeProgression(for: "row", exercises: exercises, user: user, restSeconds: 120, sets: 3, reps: 5),
            makeProgression(for: "ohp", exercises: exercises, user: user, restSeconds: 120, sets: 3, reps: 5),
            makeProgression(for: "deadlift", exercises: exercises, user: user, restSeconds: 180, sets: 1, reps: 5)
        ].reduce(into: [String: ExerciseProgression]()) { result, item in
            context.insert(item)
            if let key = item.exercise?.key {
                result[key] = item
            }
        }

        for weight in [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25] {
            let plate = PlateInventoryItem(weightKg: weight, countTotal: 2, user: user)
            context.insert(plate)
            user.plates.append(plate)
        }

        let workoutA = ProgramDay(name: "Workout A", orderInRotation: 0)
        let workoutB = ProgramDay(name: "Workout B", orderInRotation: 1)
        context.insert(workoutA)
        context.insert(workoutB)

        try workoutA.addSlot(exerciseProgression: requiredProgression("squat", from: progressions), order: 0)
        try workoutA.addSlot(exerciseProgression: requiredProgression("bench", from: progressions), order: 1)
        try workoutA.addSlot(exerciseProgression: requiredProgression("row", from: progressions), order: 2)

        try workoutB.addSlot(exerciseProgression: requiredProgression("squat", from: progressions), order: 0)
        try workoutB.addSlot(exerciseProgression: requiredProgression("ohp", from: progressions), order: 1)
        try workoutB.addSlot(exerciseProgression: requiredProgression("deadlift", from: progressions), order: 2)

        try context.save()
    }

    private func makeProgression(
        for key: String,
        exercises: [String: Exercise],
        user: User,
        restSeconds: Int,
        sets: Int,
        reps: Int
    ) throws -> ExerciseProgression {
        ExerciseProgression(
            exercise: try requiredExercise(key, from: exercises),
            currentWeightKg: user.barWeightKg,
            incrementKg: user.defaultIncrementKg,
            restSeconds: restSeconds,
            workingSets: sets,
            workingReps: reps
        )
    }

    private func requiredExercise(_ key: String, from exercises: [String: Exercise]) throws -> Exercise {
        guard let exercise = exercises[key] else {
            throw SeederError.missingExercise(key)
        }
        return exercise
    }

    private func requiredProgression(_ key: String, from progressions: [String: ExerciseProgression]) throws -> ExerciseProgression {
        guard let progression = progressions[key] else {
            throw SeederError.missingProgression(key)
        }
        return progression
    }
}

private enum SeederError: Error {
    case missingExercise(String)
    case missingProgression(String)
}
