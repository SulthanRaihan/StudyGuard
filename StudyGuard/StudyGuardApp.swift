//
//  StudyGuardApp.swift
//  StudyGuard
//
//  Created by 20 on 2026/6/12.
//

import SwiftUI
import FirebaseCore

@main
struct StudyGuardApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
