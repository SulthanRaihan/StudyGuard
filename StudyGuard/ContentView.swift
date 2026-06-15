//
//  ContentView.swift
//  StudyGuard
//
//  Created by 20 on 2026/6/12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // Milestone 1: launch straight into the live posture session for testing.
        // Real navigation (Auth -> Home -> PreSession -> Session) arrives in later milestones.
        SessionView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
