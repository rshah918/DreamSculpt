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
    @State private var clearCanvasAction: (() -> Void)?
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

                    // Canvas container with rounded top corners - extends to bottom.
                    // PromptBar + tap-catcher live inside the split view's `content`
                    // closure so the camera panel slides OVER them rather than
                    // pulsing underneath the prompt bar in z-order.
                    CanvasCameraSplitView(
                        isSplitOpen: $appState.isSplitOpen,
                        onImagePicked: { image, source in appState.setBaseImage(image, source: source) }
                    ) {
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
                                clearAction: $clearCanvasAction,
                                resignFocus: $resignCanvasFocus,
                                canvasReady: canvasReady,
                                pencilOnlyMode: appState.pencilOnlyMode,
                                symmetryMode: appState.symmetryMode
                            )

                            // Tap-outside catcher — collapses the prompt bar when expanded.
                            // Sits behind the prompt bar so taps inside the bar still reach it.
                            if isPromptBarExpanded {
                                Color.black.opacity(0.001)
                                    .ignoresSafeArea()
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isPromptBarExpanded = false
                                    }
                                    .transition(.opacity)
                            }

                            // Prompt bar — stays visible; the camera panel slides over it
                            VStack(spacing: 0) {
                                Spacer()
                                PromptBar(
                                    isExpanded: $isPromptBarExpanded,
                                    hasDrawing: hasCanvasDrawing,
                                    hasBaseImage: appState.baseImage != nil,
                                    onGenerate: {
                                        if GenerationLimitManager.shared.canGenerate() {
                                            generateAction?()
                                            return
                                        }
                                        Task {
                                            // Force a fresh fetch (with retry) if products
                                            // aren't ready — handles TestFlight first-launch
                                            // where the initial fetch may have failed.
                                            if StoreManager.shared.products.isEmpty {
                                                await StoreManager.shared.fetchProducts()
                                            }
                                            if let smallPack = StoreManager.shared.products.first(where: { $0.id == "com.DreamSculpt.generations.10" }) {
                                                await StoreManager.shared.purchase(smallPack)
                                                if GenerationLimitManager.shared.canGenerate() {
                                                    generateAction?()
                                                }
                                            } else {
                                                appState.showLimitReachedOverlay = true
                                            }
                                        }
                                    },
                                    onCollapse: { requestCanvasFocus?() },
                                    onUndo: { undoAction?() },
                                    onClear: { clearCanvasAction?() }
                                )
                                .padding(20)
                            }
                        }
                    }
                    .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
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
                        // Also persist the untouched original when the base photo
                        // came from the camera — that capture isn't in the user's
                        // library yet, and they likely want both side by side.
                        if appState.baseImageSource == .camera, let original = appState.baseImage {
                            UIImageWriteToSavedPhotosAlbum(original, nil, nil, nil)
                        }
                        HapticManager.shared.lightTap()
                    },
                    hideForCameraPanel: appState.isSplitOpen
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
