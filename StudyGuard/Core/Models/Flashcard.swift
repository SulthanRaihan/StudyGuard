//
//  Flashcard.swift
//  StudyGuard
//

import Foundation

/// A question/answer flashcard generated from scanned or typed study material.
struct Flashcard: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}
