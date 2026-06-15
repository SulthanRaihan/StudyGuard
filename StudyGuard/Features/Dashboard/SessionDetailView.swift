//
//  SessionDetailView.swift
//  StudyGuard
//

import SwiftUI
import Charts

/// Detail of one past session: stats + the per-minute focus timeline.
struct SessionDetailView: View {
    let record: FirebaseService.SessionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 12) {
                    tile("\(record.totalSeconds / 60)m", "Duration", "clock.fill", Theme.navy)
                    tile("\(Int(record.focusScore))%", "Focus", "eye.fill", Theme.orange)
                    tile("\(Int(record.postureScore))%", "Posture", "figure.stand", Theme.green)
                }

                HStack(spacing: 12) {
                    tile("\(record.postureAlertCount)", "Posture alerts", "exclamationmark.bubble.fill", Theme.orange)
                    tile("\(record.distractionCount)", "Distractions", "eye.slash.fill", Theme.navy)
                }

                focusChart
            }
            .padding(20)
        }
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle(record.subject)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.subject).font(.title.bold()).foregroundStyle(Theme.navy)
            Text(record.endTime.formatted(date: .complete, time: .shortened))
                .font(.subheadline).foregroundStyle(Theme.muted)
        }
    }

    private var focusChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Over Time").font(.headline).foregroundStyle(Theme.navy)
            if record.focusTimeline.isEmpty {
                Text("No minute-by-minute data for this session.")
                    .font(.callout).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(Array(record.focusTimeline.enumerated()), id: \.offset) { item in
                    LineMark(
                        x: .value("Minute", item.offset + 1),
                        y: .value("Focus", item.element)
                    )
                    .foregroundStyle(Theme.orange)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Minute", item.offset + 1),
                        y: .value("Focus", item.element)
                    )
                    .foregroundStyle(Theme.orange.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private func tile(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.title3.bold()).foregroundStyle(Theme.navy)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .sgCard(padding: 14)
    }
}
