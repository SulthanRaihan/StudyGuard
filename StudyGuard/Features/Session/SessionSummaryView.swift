//
//  SessionSummaryView.swift
//  StudyGuard
//

import SwiftUI

/// Post-session results: stats + a Groq-generated personal narrative. A finished
/// session is finished — the break lives in the in-session pause menu, not here.
struct SessionSummaryView: View {
    let result: SessionResult
    let onDone: () -> Void

    @State private var summary: String?
    @State private var summaryError: String?
    @State private var isLoading = true
    @State private var agentAnalysis: AgentAnalysis?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    BrandImage(name: "GuriCelebrate", fallbackSystemName: "checkmark.seal.fill")
                        .frame(height: 150)
                    Text("\(result.subject) session done!")
                        .font(.title2.bold()).foregroundStyle(Theme.navy)
                        .multilineTextAlignment(.center)
                    Text("Great work — Guri is proud of you! 🎉")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                .padding(.top, 12)

                HStack(spacing: 12) {
                    stat("Duration", "\(result.durationMinutes)m", "clock.fill", Theme.navy)
                    stat("Posture", "\(Int(result.avgPosture))%", "figure.stand", Theme.green)
                    stat("Focus", "\(Int(result.avgFocus))%", "eye.fill", Theme.orange)
                }

                groqCard

                if let agentAnalysis {
                    coachCard(agentAnalysis)
                }

                Button("Done", action: onDone)
                    .buttonStyle(.sgPrimary)
                    .padding(.top, 4)

                Color.clear.frame(height: 8)
            }
            .padding(24)
        }
        .background(Theme.cream.ignoresSafeArea())
        .task { await loadSummary() }
    }

    private var groqCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI Insight", systemImage: "sparkles")
                .font(.headline).foregroundStyle(Theme.orange)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Analyzing your session…").foregroundStyle(Theme.muted)
                }
            } else if let summary {
                Text(summary).font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Theme.navy)
            } else {
                Text(summaryError ?? "Insight unavailable.")
                    .font(.callout).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private func coachCard(_ analysis: AgentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Coach Analysis", systemImage: "person.2.badge.gearshape.fill")
                .font(.headline).foregroundStyle(Theme.green)

            Text(analysis.posture.patterns)
                .font(.callout).foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)

            if !analysis.focus.dropMinutes.isEmpty {
                Text("Focus dipped around minute \(analysis.focus.dropMinutes.prefix(5).map(String.init).joined(separator: ", "))")
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            if !analysis.exercises.isEmpty {
                Divider()
                Text("Suggested stretches").font(.subheadline.bold()).foregroundStyle(Theme.navy)
                ForEach(analysis.exercises) { exercise in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "figure.cooldown").foregroundStyle(Theme.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(exercise.name).font(.subheadline).foregroundStyle(Theme.navy)
                            Text(exercise.instructions).font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private func stat(_ label: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.title3.bold()).foregroundStyle(Theme.navy)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .sgCard(padding: 14)
    }

    private func loadSummary() async {
        // Kick off the optional agent analysis in parallel; it only appears if
        // a backend is configured and reachable.
        async let agents = AgentService.shared.analyze(result)
        do {
            summary = try await GroqService.shared.sessionSummary(for: result)
        } catch {
            summaryError = error.localizedDescription
        }
        isLoading = false
        agentAnalysis = await agents
    }
}

struct SessionSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SessionSummaryView(
            result: SessionResult(subject: "Mathematics", totalSeconds: 1500, targetMinutes: 25,
                                  avgPosture: 82, avgFocus: 74, postureAlertCount: 3,
                                  dominantIssue: .tlf, focusTimeline: [90, 85, 80, 70, 60],
                                  startedAt: Date()),
            onDone: {}
        )
    }
}
