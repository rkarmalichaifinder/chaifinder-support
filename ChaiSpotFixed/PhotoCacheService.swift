import Foundation
import UIKit

class PhotoCacheService: ObservableObject {
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        // Set cache limits
        cache.countLimit = 100 // Max 100 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        // Get cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("PhotoCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Memory Cache
    
    /// Gets image from memory cache
    func getImageFromMemory(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    /// Stores image in memory cache
    func storeImageInMemory(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
    
    // MARK: - Disk Cache
    
    /// Gets image from disk cache
    func getImageFromDisk(for url: String) -> UIImage? {
        let filename = getFilename(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Also store in memory cache for faster access
        storeImageInMemory(image, for: url)
        return image
    }
    
    /// Stores image on disk
    func storeImageOnDisk(_ image: UIImage, for url: String) {
        let filename = getFilename(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        try? data.write(to: fileURL)
    }
    
    /// Generates filename from URL
    private func getFilename(for url: String) -> String {
        return url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? url
    }
    
    // MARK: - Public Interface
    
    /// Gets image from cache (memory first, then disk)
    func getImage(for url: String) -> UIImage? {
        // Try memory cache first
        if let image = getImageFromMemory(for: url) {
            return image
        }
        
        // Try disk cache
        if let image = getImageFromDisk(for: url) {
            return image
        }
        
        return nil
    }
    
    /// Stores image in both memory and disk cache
    func storeImage(_ image: UIImage, for url: String) {
        storeImageInMemory(image, for: url)
        storeImageOnDisk(image, for: url)
    }
    
    /// Clears all caches
    func clearAllCaches() {
        cache.removeAllObjects()
        
        // Clear disk cache
        let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        contents?.forEach { url in
            try? fileManager.removeItem(at: url)
        }
    }
    
    /// Gets cache size in bytes
    func getCacheSize() -> Int64 {
        let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        
        var totalSize: Int64 = 0
        contents?.forEach { url in
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes?[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    /// Formats cache size for display
    func getFormattedCacheSize() -> String {
        let size = getCacheSize()
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        
        return formatter.string(fromByteCount: size)
    }
}
