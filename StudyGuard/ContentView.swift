//
//  ContentView.swift
//  StudyGuard
//
//  Created by 20 on 2026/6/12.
//

import SwiftUI

struct ContentView: View {
    // Milestone 3: PreSession -> Session flow. Auth + Home arrive in later milestones.
    @State private var activeSession: SessionManager?

    var body: some View {
        if let session = activeSession {
            SessionView(session: session) {
                activeSession = nil
            }
            .id(ObjectIdentifier(session))
        } else {
            PreSessionSetupView { subject, duration in
                activeSession = SessionManager(subject: subject, targetDuration: duration)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
