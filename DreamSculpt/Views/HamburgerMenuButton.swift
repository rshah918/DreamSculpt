//
//  HamburgerMenuButton.swift
//  DreamSculpt
//

import SwiftUI

struct HamburgerMenuButton: View {
    @Binding var isOpen: Bool

    private let lineWidth: CGFloat = 20
    private let lineHeight: CGFloat = 2
    private let spacing: CGFloat = 5

    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isOpen.toggle()
            }
        } label: {
            VStack(spacing: spacing) {
                topLine
                middleLine
                bottomLine
            }
            .frame(width: 44, height: 44)
            .background(
                LinearGradient(
                    colors: [ColorPalette.primary.opacity(0.9), ColorPalette.accent.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ColorPalette.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var topLine: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: lineWidth, height: lineHeight)
            .cornerRadius(1)
            .rotationEffect(.degrees(isOpen ? 45 : 0), anchor: .center)
            .offset(y: isOpen ? spacing + lineHeight : 0)
    }

    private var middleLine: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: lineWidth, height: lineHeight)
            .cornerRadius(1)
            .scaleEffect(x: isOpen ? 0 : 1, anchor: .center)
            .opacity(isOpen ? 0 : 1)
    }

    private var bottomLine: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: lineWidth, height: lineHeight)
            .cornerRadius(1)
            .rotationEffect(.degrees(isOpen ? -45 : 0), anchor: .center)
            .offset(y: isOpen ? -(spacing + lineHeight) : 0)
    }
}
