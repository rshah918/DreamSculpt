//
//  ContentView.swift
//  DreamSculpt
//
//  Created by Rahul Shah on 8/31/25.
//

import SwiftUI

struct ContentView: View {
    @State var image: UIImage? = nil
    @State private var previewOffset: CGSize = .zero
    @State private var isExpanded: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full canvas background
                CanvasView(image: $image)
                    .ignoresSafeArea()
                
                if let result = image {
                    Image(uiImage: result)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isExpanded ? min(geo.size.width, geo.size.height) : 120,
                               height: isExpanded ? min(geo.size.width, geo.size.height) : 120)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .offset(isExpanded ? .zero : previewOffset)
                         // top-right corner default, center + full-screen on tap
                        .position(x: isExpanded ? geo.size.width / 2 : UIScreen.main.bounds.width - 90,
                                  y: isExpanded ? geo.size.height / 2 : 100)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    previewOffset = value.translation
                                }
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isExpanded.toggle()
                            }
                        }
                        .animation(.easeInOut, value: isExpanded)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}



#Preview {
    ContentView()
}
