//
//  HistoryThumbnailCard.swift
//  DreamSculpt
//

import SwiftUI

struct HistoryThumbnailCard: View {
    let record: GenerationRecord
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDeleteConfirm = false
    /// Cache the decoded thumbnail. Without this, every body recompute
    /// (e.g. swiping a sibling card) re-reads + decodes the PNG from disk
    /// because `record.resultImage` is a computed property.
    @State private var cachedImage: UIImage? = nil

    // Reuse one DateFormatter per format. `DateFormatter()` is expensive to
    // construct (locale + calendar lookup) and was previously rebuilt on
    // every body evaluation through `formattedDate` / `formattedTime`.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteBackground

            cardContent
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var deleteBackground: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.spring()) {
                    onDelete()
                }
            } label: {
                Image(systemName: "trash.fill")
                    .foregroundColor(.white)
                    .frame(width: 60, height: 100)
                    .background(ColorPalette.error)
            }
        }
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            Group {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorPalette.surfaceLight)
                        .frame(width: 80, height: 80)
                }
            }
            .task(id: record.id) {
                // Decode off the main thread so a long history list doesn't
                // stall scrolling. Once cached on the card, subsequent body
                // recomputes are free.
                let image = await Task.detached(priority: .userInitiated) {
                    record.resultImage
                }.value
                await MainActor.run { cachedImage = image }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)

                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(ColorPalette.textMuted)
                .font(.caption)
        }
        .padding(12)
        .background(ColorPalette.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorPalette.glassBorder, lineWidth: 0.5)
        )
        .onTapGesture {
            onTap()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .onChanged { value in
                // Only horizontal
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < 0 {
                    offset = max(value.translation.width, -70)
                }
            }
            .onEnded { value in
                withAnimation(.spring()) {
                    if value.translation.width < 0 {
                        offset = -70
                    } else {
                        offset = 0
                    }
                }
            }
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: record.timestamp)
    }

    private var formattedTime: String {
        Self.timeFormatter.string(from: record.timestamp)
    }
}
