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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52)).foregroundStyle(Theme.green)
                    Text("\(result.subject) session done")
                        .font(.title2.bold()).foregroundStyle(Theme.navy)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                HStack(spacing: 12) {
                    stat("Duration", "\(result.durationMinutes)m", "clock.fill", Theme.navy)
                    stat("Posture", "\(Int(result.avgPosture))%", "figure.stand", Theme.green)
                    stat("Focus", "\(Int(result.avgFocus))%", "eye.fill", Theme.orange)
                }

                groqCard

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
        do {
            summary = try await GroqService.shared.sessionSummary(for: result)
        } catch {
            summaryError = error.localizedDescription
        }
        isLoading = false
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
