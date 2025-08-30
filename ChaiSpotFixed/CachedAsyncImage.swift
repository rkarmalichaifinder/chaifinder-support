import SwiftUI
import UIKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var photoCacheService = PhotoCacheService()
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError = false
    
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else if loadError {
                placeholder()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, !url.isEmpty else {
            image = nil
            return
        }
        
        // Check cache first
        if let cachedImage = photoCacheService.getImage(for: url) {
            image = cachedImage
            return
        }
        
        // Load from network
        isLoading = true
        loadError = false
        
        guard let imageURL = URL(string: url) else {
            isLoading = false
            loadError = true
            return
        }
        
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("❌ Failed to load image from \(url): \(error.localizedDescription)")
                    loadError = true
                    return
                }
                
                guard let data = data, let loadedImage = UIImage(data: data) else {
                    print("❌ Invalid image data from \(url)")
                    loadError = true
                    return
                }
                
                // Store in cache
                photoCacheService.storeImage(loadedImage, for: url)
                
                // Update UI
                image = loadedImage
            }
        }.resume()
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == AnyView, Placeholder == AnyView {
    init(url: String?) {
        self.init(url: url) { image in
            AnyView(image)
        } placeholder: {
            AnyView(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            )
        }
    }
    
    init(url: String?, cornerRadius: CGFloat = 8) {
        self.init(url: url) { image in
            AnyView(
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .cornerRadius(cornerRadius)
            )
        } placeholder: {
            AnyView(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            )
        }
    }
}

// MARK: - Preview
struct CachedAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CachedAsyncImage(url: "https://picsum.photos/200/200")
                .frame(width: 200, height: 200)
            
            CachedAsyncImage(url: "https://picsum.photos/300/200", cornerRadius: 16)
                .frame(width: 300, height: 200)
        }
        .padding()
    }
}
