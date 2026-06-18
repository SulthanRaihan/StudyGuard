//
//  BreakView.swift
//  StudyGuard
//

import SwiftUI

/// Break screen: camera is off, Guri keeps the user company with matched stretches,
/// a countdown, and a quick AI chat. Opened mid-session from the pause menu.
struct BreakView: View {
    let result: SessionResult
    /// `true` when opened from a paused session (button reads "Resume Studying").
    var isMidSession: Bool = false
    /// When set, the break is logged to Firestore on finish.
    var userId: String? = nil
    let onDone: () -> Void

    @State private var exercises: [BreakExercise] = []
    @State private var doneIDs: Set<String> = []
    @State private var remaining: Int
    @State private var showChat = false
    @State private var showScan = false
    @State private var detailExercise: BreakExercise?
    @State private var timer: Timer?

    init(result: SessionResult, isMidSession: Bool = false, userId: String? = nil,
         onDone: @escaping () -> Void) {
        self.result = result
        self.isMidSession = isMidSession
        self.userId = userId
        self.onDone = onDone
        _remaining = State(initialValue: result.breakMinutes * 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                guriHeader
                countdown

                VStack(alignment: .leading, spacing: 12) {
                    Text("Stretches for you").font(.headline).foregroundStyle(Theme.navy)
                    ForEach(exercises) { exercise in
                        ExerciseCardView(
                            exercise: exercise,
                            isDone: doneIDs.contains(exercise.id),
                            onToggle: { toggle(exercise) },
                            onTap: { detailExercise = exercise }
                        )
                    }
                }

                HStack(spacing: 12) {
                    Button { showChat = true } label: {
                        Label("Ask Guri", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .buttonStyle(.sgSecondary)

                    Button { showScan = true } label: {
                        Label("Scan & Solve", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(.sgSecondary)
                }

                Button(isMidSession ? "Resume Studying" : "Done", action: finish)
                    .buttonStyle(.sgPrimary)

                Color.clear.frame(height: 8)
            }
            .padding(24)
        }
        .background(Theme.cream.ignoresSafeArea())
        .task {
            await loadExercises()
            await NotificationService.shared.requestAuthorization()
            NotificationService.shared.scheduleBreakEnd(after: Double(result.breakMinutes * 60))
        }
        .onAppear(perform: startTimer)
        .onDisappear {
            timer?.invalidate()
            NotificationService.shared.cancelBreakEnd()
        }
        .sheet(isPresented: $showChat) {
            BreakChatView(subject: result.subject)
        }
        .fullScreenCover(isPresented: $showScan) {
            ScanView()
        }
        .sheet(item: $detailExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }

    private var guriHeader: some View {
        VStack(spacing: 8) {
            BrandImage(name: "GuriBreak", fallbackSystemName: "cup.and.saucer.fill")
                .frame(height: 130)
            Text("Break time!")
                .font(.title2.bold()).foregroundStyle(Theme.navy)
            Text("Rest your eyes and stretch — your brain will thank you.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var countdown: some View {
        VStack(spacing: 4) {
            Text("Break timer").font(.caption).foregroundStyle(Theme.muted)
            Text(timeString)
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(remaining == 0 ? Theme.green : Theme.navy)
            if remaining == 0 {
                Text("Break's over — ready to get back to it!")
                    .font(.caption).foregroundStyle(Theme.green)
            }
        }
        .frame(maxWidth: .infinity)
        .sgCard()
    }

    private var timeString: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func toggle(_ exercise: BreakExercise) {
        if doneIDs.contains(exercise.id) { doneIDs.remove(exercise.id) }
        else { doneIDs.insert(exercise.id) }
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
        if let userId {
            let logged = exercises.map { e -> BreakExercise in
                var copy = e; copy.completed = doneIDs.contains(e.id); return copy
            }
            FirebaseService.shared.recordBreak(
                userId: userId, sessionId: result.sessionId, reason: "pause",
                exercises: logged, completed: !doneIDs.isEmpty
            )
        }
        onDone()
    }
}

struct BreakView_Previews: PreviewProvider {
    static var previews: some View {
        BreakView(
            result: SessionResult(subject: "Physics", totalSeconds: 1500, targetMinutes: 25,
                                  avgPosture: 80, avgFocus: 70, postureAlertCount: 2,
                                  dominantIssue: .tll, focusTimeline: [80, 75], startedAt: Date()),
            onDone: {}
        )
    }
}
