//
//  StudyGuardApp.swift
//  StudyGuard
//
//  Created by 20 on 2026/6/12.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct StudyGuardApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
