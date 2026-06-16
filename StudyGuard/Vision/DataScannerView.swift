//
//  DataScannerView.swift
//  StudyGuard
//

import SwiftUI
import VisionKit

/// Live on-device text recognition (VisionKit `DataScannerViewController`).
/// The image never leaves the device — only the recognized text is surfaced.
struct DataScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String

    /// Whether live scanning is available on this device (false on Simulator).
    @MainActor
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $recognizedText) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            update(allItems)
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            update(allItems)
        }

        private func update(_ items: [RecognizedItem]) {
            let lines = items.compactMap { item -> String? in
                if case let .text(text) = item { return text.transcript }
                return nil
            }
            text = lines.joined(separator: " ")
        }
    }
}
