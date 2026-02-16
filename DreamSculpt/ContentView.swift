//
//  ContentView.swift
//  DreamSculpt
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var previewOffset: CGSize = .zero
    @State private var isExpanded: Bool = false
    @State private var isPromptBarExpanded: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background color (visible in gaps/behind header)
                Color(hex: "0F0F23")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Aurora Header (compact, premium look)
                    AuroraHeader()

                    // Canvas container with rounded top corners - extends to bottom
                    ZStack {
                        CanvasView(
                            generatedImage: $appState.currentPreviewImage,
                            isLoading: $appState.isLoading,
                            baseImage: appState.baseImage,
                            showPaperTexture: appState.showPaperTexture,
                            sessionId: appState.sessionId,
                            customPrompt: appState.customPrompt,
                            generationSettings: appState.generationSettings,
                            onGenerationComplete: { sketch, result in
                                appState.addToHistory(sketch: sketch, result: result)
                            }
                        )
                        .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                        .shadow(color: .black.opacity(0.3), radius: 12, y: -4)

                        // Prompt bar overlay at bottom
                        VStack {
                            Spacer()
                            PromptBar(isExpanded: $isPromptBarExpanded)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                // AI Preview Panel - passes session history for slider
                AIPreviewPanel(
                    image: appState.currentPreviewImage,
                    isLoading: appState.isLoading,
                    isExpanded: $isExpanded,
                    offset: $previewOffset,
                    sessionImages: appState.sessionImages,
                    sessionIndex: Binding(
                        get: { appState.sessionIndex },
                        set: { appState.setSessionIndex($0) }
                    )
                )

                // History Drawer overlay
                HistoryDrawer(
                    isOpen: $appState.isDrawerOpen,
                    onSelectRecord: { record in
                        if let image = record.resultImage {
                            appState.setBaseImage(image)
                        }
                    }
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
