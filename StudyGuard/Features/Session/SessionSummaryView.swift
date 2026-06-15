//
//  SessionSummaryView.swift
//  StudyGuard
//

import SwiftUI

/// Post-session results: stats + a Groq-generated personal narrative, with
/// entry points to take a break or finish.
struct SessionSummaryView: View {
    let result: SessionResult
    let onStartBreak: () -> Void
    let onDone: () -> Void

    @State private var summary: String?
    @State private var summaryError: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                    Text("Sesi \(result.subject) selesai")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                HStack(spacing: 12) {
                    stat("Durasi", "\(result.durationMinutes)m", "clock.fill", .blue)
                    stat("Postur", "\(Int(result.avgPosture))%", "figure.stand", .green)
                    stat("Fokus", "\(Int(result.avgFocus))%", "eye.fill", .orange)
                }

                groqCard

                VStack(spacing: 12) {
                    Button(action: onStartBreak) {
                        Label("Mulai Istirahat", systemImage: "cup.and.saucer.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Selesai", action: onDone)
                        .controlSize(.large)
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .task { await loadSummary() }
    }

    private var groqCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Insight AI", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.tint)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Menganalisis sesimu…").foregroundStyle(.secondary)
                }
            } else if let summary {
                Text(summary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(summaryError ?? "Insight tidak tersedia.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ label: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
            result: SessionResult(subject: "Matematika", totalSeconds: 1500, targetMinutes: 25,
                                  avgPosture: 82, avgFocus: 74, postureAlertCount: 3,
                                  dominantIssue: .tlf, focusTimeline: [90, 85, 80, 70, 60],
                                  startedAt: Date()),
            onStartBreak: {}, onDone: {}
        )
    }
}
