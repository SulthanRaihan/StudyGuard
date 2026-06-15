//
//  BreakView.swift
//  StudyGuard
//

import SwiftUI

/// Break screen: camera is off, the user does matched stretches with a countdown,
/// and can open a quick AI chat. Finishing returns to Home.
struct BreakView: View {
    let result: SessionResult
    let onDone: () -> Void

    @State private var exercises: [BreakExercise] = []
    @State private var doneIDs: Set<String> = []
    @State private var remaining: Int
    @State private var showChat = false
    @State private var timer: Timer?

    init(result: SessionResult, onDone: @escaping () -> Void) {
        self.result = result
        self.onDone = onDone
        _remaining = State(initialValue: result.breakMinutes * 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                countdown

                VStack(alignment: .leading, spacing: 12) {
                    Text("Peregangan untukmu")
                        .font(.headline)
                    ForEach(exercises) { exercise in
                        ExerciseCardView(exercise: exercise, isDone: doneIDs.contains(exercise.id)) {
                            toggle(exercise)
                        }
                    }
                }

                Button {
                    showChat = true
                } label: {
                    Label("Tanya AI", systemImage: "bubble.left.and.bubble.right.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Selesai Istirahat", action: finish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(24)
        }
        .task { await loadExercises() }
        .onAppear(perform: startTimer)
        .onDisappear { timer?.invalidate() }
        .sheet(isPresented: $showChat) {
            BreakChatView(subject: result.subject)
        }
    }

    private var countdown: some View {
        VStack(spacing: 6) {
            Text("Waktu istirahat")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(timeString)
                .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(remaining == 0 ? .green : .primary)
            if remaining == 0 {
                Text("Istirahat selesai — siap lanjut belajar!")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.top, 12)
    }

    private var timeString: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func toggle(_ exercise: BreakExercise) {
        if doneIDs.contains(exercise.id) {
            doneIDs.remove(exercise.id)
        } else {
            doneIDs.insert(exercise.id)
        }
    }

    private func loadExercises() async {
        exercises = await ExerciseAPIService.shared.routine(
            for: result.dominantIssue, breakMinutes: result.breakMinutes
        )
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            if remaining > 0 { remaining -= 1 }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func finish() {
        timer?.invalidate()
        onDone()
    }
}

struct BreakView_Previews: PreviewProvider {
    static var previews: some View {
        BreakView(
            result: SessionResult(subject: "Fisika", totalSeconds: 1500, targetMinutes: 25,
                                  avgPosture: 80, avgFocus: 70, postureAlertCount: 2,
                                  dominantIssue: .tll, focusTimeline: [80, 75], startedAt: Date()),
            onDone: {}
        )
    }
}
