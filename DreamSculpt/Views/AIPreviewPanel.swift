//
//  AIPreviewPanel.swift
//  DreamSculpt
//

import SwiftUI

struct AIPreviewPanel: View {
    let image: UIImage?
    let isLoading: Bool
    @Binding var isExpanded: Bool
    @Binding var offset: CGSize

    // Session history for slider
    let sessionImages: [UIImage]
    @Binding var sessionIndex: Int

    @State private var dragOffset: CGSize = .zero

    // Only show if we have at least one image or are loading
    var shouldShow: Bool {
        image != nil || isLoading
    }

    var body: some View {
        GeometryReader { geo in
            if shouldShow {
                ZStack {
                    if isExpanded {
                        expandedOverlay(geo: geo)
                    }

                    previewContent(geo: geo)
                }
            }
        }
    }

    private func expandedOverlay(geo: GeometryProxy) -> some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            }
    }

    private func previewContent(geo: GeometryProxy) -> some View {
        let previewSize: CGFloat = isExpanded ? min(geo.size.width - 40, geo.size.height - 200) : 130
        // Default position: bottom-right corner of canvas (below header, above toolbar)
        let position = isExpanded
            ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 - 40)
            : CGPoint(x: geo.size.width - 85, y: geo.size.height - 280)

        return VStack(spacing: 16) {
            ZStack {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }

                if isLoading {
                    loadingOverlay
                }
            }
            .frame(width: previewSize, height: previewSize)
            .glassmorphic(cornerRadius: isExpanded ? 20 : 16)
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 8)
            .overlay(
                expandButton,
                alignment: .topTrailing
            )

            // History slider - only show when expanded and have multiple images
            if isExpanded && sessionImages.count > 1 {
                historySlider(width: previewSize)
            }
        }
        .offset(isExpanded ? .zero : CGSize(width: offset.width + dragOffset.width, height: offset.height + dragOffset.height))
        .position(position)
        .gesture(
            isExpanded ? nil : dragGesture
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    private func historySlider(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Session History")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text("\(sessionIndex + 1) / \(sessionImages.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Slider(
                value: Binding(
                    get: { Double(sessionIndex) },
                    set: { sessionIndex = Int($0) }
                ),
                in: 0...Double(max(0, sessionImages.count - 1)),
                step: 1
            )
            .tint(ColorPalette.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: width)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .cornerRadius(isExpanded ? 20 : 16)

            VStack(spacing: 8) {
                LoadingIndicator(size: 32, lineWidth: 3)

                Text("Generating...")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }

    private var expandButton: some View {
        Group {
            if !isExpanded && image != nil {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .padding(8)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                offset = CGSize(
                    width: offset.width + value.translation.width,
                    height: offset.height + value.translation.height
                )
                dragOffset = .zero
            }
    }
}
