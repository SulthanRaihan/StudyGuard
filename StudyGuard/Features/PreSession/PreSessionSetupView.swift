//
//  PreSessionSetupView.swift
//  StudyGuard
//

import SwiftUI

/// Quick pre-session setup: pick a subject and a duration, then start.
struct PreSessionSetupView: View {
    /// Called with the chosen subject and target duration (minutes).
    let onStart: (String, Int) -> Void

    private let subjects = [
        "Mathematics", "Physics", "Chemistry", "Biology",
        "Programming", "Design", "English",
        "Economics", "History", "Other..."
    ]
    private let durations = [25, 50, 75]

    @State private var selectedSubject = "Mathematics"
    @State private var selectedDuration = 25

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What are you studying?")
                    .font(.largeTitle.bold())
                Text("Pick a subject and your session length.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(subjects, id: \.self) { subject in
                    chip(subject, isSelected: subject == selectedSubject) {
                        selectedSubject = subject
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Duration")
                    .font(.headline)
                HStack(spacing: 12) {
                    ForEach(durations, id: \.self) { minutes in
                        durationButton(minutes)
                    }
                }
            }

            Spacer()

            Button {
                onStart(selectedSubject, selectedDuration)
            } label: {
                Label("Start Now", systemImage: "play.fill")
            }
            .buttonStyle(.sgPrimary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func durationButton(_ minutes: Int) -> some View {
        let isSelected = minutes == selectedDuration
        return Button {
            selectedDuration = minutes
        } label: {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.title2.bold())
                Text("min")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct PreSessionSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PreSessionSetupView { _, _ in }
    }
}
