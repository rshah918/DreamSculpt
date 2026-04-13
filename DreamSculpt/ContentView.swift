//
//  ContentView.swift
//  DreamSculpt
//

import SwiftUI

struct ContentView: View {
    var canvasReady: Bool = true
    @EnvironmentObject var appState: AppState
    @State private var previewOffset: CGSize = .zero
    @State private var isExpanded: Bool = false
    @State private var isPromptBarExpanded: Bool = false
    @State private var hasCanvasDrawing: Bool = false
    @State private var generateAction: (() -> Void)?
    @State private var requestCanvasFocus: (() -> Void)?
    @State private var undoAction: (() -> Void)?
    @State private var resignCanvasFocus: (() -> Void)?

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
                            sessionId: appState.sessionId,
                            customPrompt: appState.customPrompt,
                            generationSettings: appState.generationSettings,
                            onGenerationComplete: { sketch, result in
                                appState.addToHistory(sketch: sketch, result: result)
                                GenerationLimitManager.shared.incrementCount()
                                appState.refreshGenerationCount()
                            },
                            triggerGeneration: $generateAction,
                            onDrawingChanged: { hasDrawing in
                                hasCanvasDrawing = hasDrawing
                            },
                            requestFocus: $requestCanvasFocus,
                            undoAction: $undoAction,
                            resignFocus: $resignCanvasFocus,
                            canvasReady: canvasReady
                        )
                        .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                        .shadow(color: .black.opacity(0.3), radius: 12, y: -4)

                        // Prompt bar overlay at bottom
                        VStack {
                            Spacer()
                            PromptBar(
                                isExpanded: $isPromptBarExpanded,
                                hasDrawing: hasCanvasDrawing,
                                hasBaseImage: appState.baseImage != nil,
                                onGenerate: {
                                if GenerationLimitManager.shared.canGenerate() {
                                    generateAction?()
                                } else {
                                    // Auto-trigger purchase of 10-pack, then generate
                                    if let smallPack = StoreManager.shared.products.first(where: { $0.id == "com.DreamSculpt.generations.10" }) {
                                        Task {
                                            await StoreManager.shared.purchase(smallPack)
                                            if GenerationLimitManager.shared.canGenerate() {
                                                generateAction?()
                                            }
                                        }
                                    } else {
                                        appState.showLimitReachedOverlay = true
                                    }
                                }
                            },
                                onCollapse: { requestCanvasFocus?() },
                                onUndo: { undoAction?() }
                            )
                            .padding(20)
                
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                // Generation counter - top right
                VStack {
                    HStack {
                        Spacer()
                        generationCounter
                            .padding(.trailing, 16)
                            .padding(.top, 68)
                    }
                    Spacer()
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
                    ),
                    onLoadToCanvas: { image in
                        appState.setBaseImage(image)
                        isExpanded = false
                    },
                    onSaveToPhotos: { image in
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        HapticManager.shared.lightTap()
                    }
                )

                // History Drawer overlay
                HistoryDrawer(
                    isOpen: $appState.isDrawerOpen,
                    onSelectRecord: { record in
                        if let image = record.resultImage {
                            appState.setBaseImage(image)
                            appState.currentPreviewImage = image
                            appState.sessionImages.append(image)
                            appState.sessionIndex = appState.sessionImages.count - 1
                        }
                    }
                )

                // Generation limit overlay
                if appState.showLimitReachedOverlay {
                    LimitReachedView(isPresented: $appState.showLimitReachedOverlay)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: appState.isDrawerOpen) { _, isOpen in
            if isOpen {
                resignCanvasFocus?()
            } else {
                requestCanvasFocus?()
            }
        }
    }

    private var generationCounter: some View {
        let remaining = appState.generationsRemaining
        let color: Color = {
            switch remaining {
            case 7...10000: return .green
            case 4...6: return .yellow
            case 1...3: return .orange
            default: return .red
            }
        }()

        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(remaining)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
