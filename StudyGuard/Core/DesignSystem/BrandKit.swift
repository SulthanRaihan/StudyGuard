//
//  BrandKit.swift
//  StudyGuard
//
//  Reusable branded components: Guri imagery (with SF Symbol fallback before the
//  PNGs are added to Assets), cards, and button styles.
//

import SwiftUI

/// Displays a brand image from the asset catalog, falling back to an SF Symbol
/// until the Guri PNGs are added. Add these image sets to Assets.xcassets:
///   GuriLogo, GuriHi, GuriBreak, GuriCelebrate
struct BrandImage: View {
    let name: String
    let fallbackSystemName: String

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name).resizable().scaledToFit()
        } else {
            Image(systemName: fallbackSystemName)
                .resizable().scaledToFit()
                .foregroundStyle(Theme.orange)
                .padding(8)
        }
    }
}

// MARK: - Card

private struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: Theme.navy.opacity(0.06), radius: 10, y: 4)
    }
}

extension View {
    /// Wraps the view in the standard white rounded card with soft shadow.
    func sgCard(padding: CGFloat = 18) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

// MARK: - Buttons

struct SGPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.orange, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SGSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.navy.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == SGPrimaryButtonStyle {
    static var sgPrimary: SGPrimaryButtonStyle { SGPrimaryButtonStyle() }
}
extension ButtonStyle where Self == SGSecondaryButtonStyle {
    static var sgSecondary: SGSecondaryButtonStyle { SGSecondaryButtonStyle() }
}
