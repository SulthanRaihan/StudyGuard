//
//  DashboardView.swift
//  StudyGuard
//

import SwiftUI
import Charts

/// Weekly stats: focus trend chart, summary tiles, per-subject breakdown, badges link.
struct DashboardView: View {
    @ObservedObject var auth: AuthService

    @State private var sessions: [FirebaseService.SessionRecord] = []
    @State private var profile: FirebaseService.Profile?
    @State private var isLoading = true
    @State private var report: String?
    @State private var reportLoading = false
    @State private var reportError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    tiles
                    weeklyChart
                    weeklyReportCard
                    recentSessions
                    subjectBreakdown
                    badgesLink
                    Color.clear.frame(height: 90) // clear the floating nav
                }
                .padding(20)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Statistics")
                .font(.subheadline).foregroundStyle(Theme.muted)
            Text("Learning Overview")
                .font(.largeTitle.bold()).foregroundStyle(Theme.navy)
        }
    }

    private var weeklyReportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weekly Report", systemImage: "doc.text.magnifyingglass")
                .font(.headline).foregroundStyle(Theme.orange)

            if let report {
                Text(report).font(.callout).foregroundStyle(Theme.navy)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let reportError {
                Text(reportError).font(.caption).foregroundStyle(.red)
            } else {
                Text("Get an AI summary of your week with tips for the next one.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            Button { Task { await generateReport() } } label: {
                if reportLoading { ProgressView().tint(.white) }
                else { Label(report == nil ? "Generate report" : "Regenerate", systemImage: "sparkles") }
            }
            .buttonStyle(.sgSecondary)
            .disabled(reportLoading || sessions.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private func generateReport() async {
        reportError = nil; reportLoading = true
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let week = sessions.filter { $0.endTime >= weekStart }
        let total = week.reduce(0) { $0 + $1.totalSeconds } / 60
        let avgF = week.isEmpty ? 0 : Int(week.map(\.focusScore).reduce(0, +) / Double(week.count))
        let avgP = week.isEmpty ? 0 : Int(week.map(\.postureScore).reduce(0, +) / Double(week.count))
        do {
            report = try await GroqService.shared.weeklyReport(
                sessions: week.count, totalMinutes: total, avgFocus: avgF, avgPosture: avgP,
                bestFocusHour: SessionStats.bestFocusHour(week),
                weakestSubject: SessionStats.weakestSubject(week)
            )
        } catch {
            reportError = error.localizedDescription
        }
        reportLoading = false
    }

    private var tiles: some View {
        HStack(spacing: 12) {
            tile("\(sessions.count)", "Sessions", "calendar", Theme.navy)
            tile("\(avg(\.focusScore))%", "Focus", "eye.fill", Theme.orange)
            tile("\(avg(\.postureScore))%", "Posture", "figure.stand", Theme.green)
        }
    }

    private func tile(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.title3.bold()).foregroundStyle(Theme.navy)
                .redacted(reason: isLoading ? .placeholder : [])
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .sgCard(padding: 14)
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus — Last 7 Days").font(.headline).foregroundStyle(Theme.navy)
            if weeklyData.allSatisfy({ $0.focus == 0 }) {
                Text("No session data this week yet.")
                    .font(.callout).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(weeklyData) { day in
                    BarMark(
                        x: .value("Hari", day.label),
                        y: .value("Fokus", day.focus)
                    )
                    .foregroundStyle(Theme.orange.gradient)
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private var subjectBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Subject").font(.headline).foregroundStyle(Theme.navy)
            if subjectCounts.isEmpty {
                Text("No sessions yet.").font(.callout).foregroundStyle(Theme.muted)
            } else {
                ForEach(subjectCounts, id: \.subject) { item in
                    HStack {
                        Text(item.subject).foregroundStyle(Theme.navy)
                        Spacer()
                        Text("\(item.count) sessions").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions").font(.headline).foregroundStyle(Theme.navy)
            if sessions.isEmpty {
                Text("No sessions yet — start studying!")
                    .font(.callout).foregroundStyle(Theme.muted)
            } else {
                ForEach(sessions.prefix(8)) { record in
                    NavigationLink {
                        SessionDetailView(record: record)
                    } label: {
                        sessionRow(record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private func sessionRow(_ record: FirebaseService.SessionRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill").foregroundStyle(Theme.orange).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.subject).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.navy)
                Text(record.endTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.totalSeconds / 60)m").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.navy)
                Text("Focus \(Int(record.focusScore))%").font(.caption2).foregroundStyle(Theme.muted)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 6)
    }

    private var badgesLink: some View {
        NavigationLink {
            BadgesView(sessions: sessions, currentStreak: profile?.currentStreak ?? 0,
                       userId: auth.currentUserId)
        } label: {
            HStack {
                Image(systemName: "rosette").foregroundStyle(Theme.orange)
                Text("View Badges").foregroundStyle(Theme.navy).font(.headline)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .sgCard()
        }
    }

    // MARK: - Aggregation

    private struct DayFocus: Identifiable {
        let id = UUID()
        let label: String
        let focus: Double
    }

    private var weeklyData: [DayFocus] {
        let calendar = Calendar.current
        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (0..<7).reversed().map { offset -> DayFocus in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let weekday = calendar.component(.weekday, from: date) - 1
            let daySessions = sessions.filter { calendar.isDate($0.endTime, inSameDayAs: date) }
            let focus = daySessions.isEmpty ? 0 :
                daySessions.map(\.focusScore).reduce(0, +) / Double(daySessions.count)
            return DayFocus(label: symbols[weekday], focus: focus)
        }
    }

    private var subjectCounts: [(subject: String, count: Int)] {
        Dictionary(grouping: sessions, by: \.subject)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    private func avg(_ keyPath: KeyPath<FirebaseService.SessionRecord, Double>) -> Int {
        guard !sessions.isEmpty else { return 0 }
        return Int(sessions.map { $0[keyPath: keyPath] }.reduce(0, +) / Double(sessions.count))
    }

    private func load() async {
        guard let uid = auth.currentUserId else { isLoading = false; return }
        async let s = try? await FirebaseService.shared.fetchRecentSessions(userId: uid)
        async let p = try? await FirebaseService.shared.fetchProfile(userId: uid)
        sessions = await s ?? []
        profile = await p
        isLoading = false
    }
}
