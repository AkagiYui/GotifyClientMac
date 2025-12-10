//
//  ApplicationIconView.swift
//  GotifyClient
//
//  应用图标视图组件
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 应用图标视图
struct ApplicationIconView: View {
    let application: GotifyApplication
    let size: CGFloat
    
    @State private var image: Image?
    @State private var isLoading = false
    
    init(application: GotifyApplication, size: CGFloat = 40) {
        self.application = application
        self.size = size
    }
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
                    .padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let imageUrl = application.imageUrl,
              let server = application.server,
              !isLoading else {
            return
        }
        
        isLoading = true
        
        if let platformImage = await ImageCacheManager.shared.getImage(imageUrl: imageUrl, from: server) {
            #if os(macOS)
            image = Image(nsImage: platformImage)
            #else
            image = Image(uiImage: platformImage)
            #endif
        }
        
        isLoading = false
    }
}

