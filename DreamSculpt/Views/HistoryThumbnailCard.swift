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

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteBackground

            cardContent
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .frame(height: 100)
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
            if let image = record.resultImage {
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
        DragGesture()
            .onChanged { value in
                if value.translation.width < 0 {
                    offset = max(value.translation.width, -70)
                }
            }
            .onEnded { value in
                withAnimation(.spring()) {
                    if value.translation.width < -50 {
                        offset = -70
                    } else {
                        offset = 0
                    }
                }
            }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: record.timestamp)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: record.timestamp)
    }
}
