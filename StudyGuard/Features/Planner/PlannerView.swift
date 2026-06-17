//
//  PlannerView.swift
//  StudyGuard
//

import SwiftUI

/// AI study planner: pick subjects + days + hours/day, and Groq generates an
/// adaptive plan (scheduled around the user's best focus hour).
struct PlannerView: View {
    @ObservedObject var auth: AuthService

    private let subjects = [
        "Mathematics", "Physics", "Chemistry", "Biology",
        "Programming", "Design", "English", "Economics", "History"
    ]
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    @State private var selected: Set<String> = []
    @State private var days = 3
    @State private var hoursPerDay = 2
    @State private var plan: [StudyPlanDay] = []
    @State private var bestFocusHour: Int?
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                subjectPicker
                steppers
                generateButton
                if let errorText { Text(errorText).font(.caption).foregroundStyle(.red) }
                planList
                Color.clear.frame(height: 90)
            }
            .padding(20)
        }
        .background(Theme.cream.ignoresSafeArea())
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AI Planner").font(.subheadline).foregroundStyle(Theme.muted)
            Text("Your Study Plan").font(.largeTitle.bold()).foregroundStyle(Theme.navy)
            if let hour = bestFocusHour {
                Label("You focus best around \(hour):00", systemImage: "bolt.fill")
                    .font(.caption).foregroundStyle(Theme.orange)
            }
        }
    }

    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subjects").font(.headline).foregroundStyle(Theme.navy)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(subjects, id: \.self) { subject in
                    let on = selected.contains(subject)
                    Button {
                        if on { selected.remove(subject) } else { selected.insert(subject) }
                    } label: {
                        Text(subject).font(.subheadline.weight(.medium)).lineLimit(1)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(on ? AnyShapeStyle(Theme.orange) : AnyShapeStyle(Color.white),
                                       in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(on ? .white : Theme.navy)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private var steppers: some View {
        VStack(spacing: 12) {
            Stepper("Days: \(days)", value: $days, in: 1...14)
            Divider()
            Stepper("Hours/day: \(hoursPerDay)", value: $hoursPerDay, in: 1...8)
        }
        .foregroundStyle(Theme.navy)
        .sgCard()
    }

    private var generateButton: some View {
        Button { Task { await generate() } } label: {
            if isLoading { ProgressView().tint(.white) }
            else { Label("Generate Plan", systemImage: "sparkles") }
        }
        .buttonStyle(.sgPrimary)
        .disabled(selected.isEmpty || isLoading)
    }

    @ViewBuilder
    private var planList: some View {
        if !plan.isEmpty {
            ForEach(plan) { day in
                VStack(alignment: .leading, spacing: 10) {
                    Text(day.day).font(.headline).foregroundStyle(Theme.orange)
                    ForEach(day.tasks) { task in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle").foregroundStyle(Theme.muted)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(task.subject) · \(task.minutes)m")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.navy)
                                Text(task.activity).font(.caption).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .sgCard()
            }
        }
    }

    // MARK: - Logic

    private func load() async {
        guard let uid = auth.currentUserId else { return }
        plan = await FirebaseService.shared.fetchStudyPlan(userId: uid)
        let sessions = (try? await FirebaseService.shared.fetchRecentSessions(userId: uid)) ?? []
        bestFocusHour = SessionStats.bestFocusHour(sessions)
    }

    private func generate() async {
        errorText = nil; isLoading = true
        do {
            let days = try await GroqService.shared.generateStudyPlan(
                subjects: Array(selected), days: days, hoursPerDay: hoursPerDay, bestFocusHour: bestFocusHour
            )
            if days.isEmpty {
                errorText = "Couldn't generate a plan — try again."
            } else {
                plan = days
                if let uid = auth.currentUserId {
                    await FirebaseService.shared.saveStudyPlan(userId: uid, days: days)
                }
            }
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}
