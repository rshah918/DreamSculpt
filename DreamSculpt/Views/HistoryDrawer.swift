//
//  HistoryDrawer.swift
//  DreamSculpt
//

import SwiftUI

struct HistoryDrawer: View {
    @EnvironmentObject var appState: AppState
    @Binding var isOpen: Bool
    var onSelectRecord: (GenerationRecord) -> Void

    @State private var selectedRecord: GenerationRecord? = nil
    @State private var showPreview = false
    @State private var showSettings = false

    private let drawerWidth: CGFloat = 320

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if isOpen {
                    dimmedBackground
                }

                drawerContent
                    .frame(width: drawerWidth)
                    .offset(x: isOpen ? 0 : -drawerWidth)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
        }
        .sheet(isPresented: $showPreview) {
            if let record = selectedRecord {
                HistoryPreviewSheet(record: record) {
                    onSelectRecord(record)
                    showPreview = false
                    isOpen = false
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsPanel()
        }
    }

    private var dimmedBackground: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation {
                    isOpen = false
                }
            }
    }

    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            drawerHeader

            if appState.history.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .background(ColorPalette.background.opacity(0.95))
        .background(.ultraThinMaterial)
    }

    private var drawerHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.textPrimary)

                Text("\(appState.history.count) generations")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Spacer()

            // Settings button
            Button {
                HapticManager.shared.lightTap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }

            if !appState.history.isEmpty {
                Button {
                    HapticManager.shared.lightTap()
                    // Clear all history
                    HistoryManager.shared.clearAllHistory()
                    appState.history = []
                } label: {
                    Text("Clear")
                        .font(.subheadline)
                        .foregroundColor(ColorPalette.error)
                }
            }
        }
        .padding()
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(ColorPalette.textMuted)

            Text("No generations yet")
                .font(.headline)
                .foregroundColor(ColorPalette.textSecondary)

            Text("Start drawing to create\nyour first AI generation")
                .font(.subheadline)
                .foregroundColor(ColorPalette.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(appState.history) { record in
                    HistoryThumbnailCard(
                        record: record,
                        onTap: {
                            selectedRecord = record
                            showPreview = true
                        },
                        onDelete: {
                            appState.deleteFromHistory(record)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

struct HistoryPreviewSheet: View {
    let record: GenerationRecord
    let onLoadToCanvas: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                ColorPalette.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    if let image = record.resultImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(16)
                            .padding()
                    }

                    HStack(spacing: 16) {
                        Button {
                            onLoadToCanvas()
                        } label: {
                            Label("Load to Canvas", systemImage: "square.and.arrow.down")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ColorPalette.gradientPrimary)
                                .cornerRadius(12)
                        }

                        if let image = record.resultImage {
                            ShareLink(item: Image(uiImage: image), preview: SharePreview("DreamSculpt Generation", image: Image(uiImage: image))) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .glassmorphic(cornerRadius: 12)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Generation Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ColorPalette.primary)
                }
            }
        }
    }
}
