import Foundation
import UIKit
import FirebaseStorage
import FirebaseAuth

class PhotoStorageService: ObservableObject {
    private let storage = Storage.storage()
    
    // MARK: - Review Photo Upload
    
    /// Uploads a review photo and returns the download URL
    func uploadReviewPhoto(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(PhotoStorageError.userNotAuthenticated))
            return
        }
        
        // Compress and resize image
        guard let compressedImageData = compressImageForReview(image) else {
            completion(.failure(PhotoStorageError.imageCompressionFailed))
            return
        }
        
        // Generate unique filename
        let photoId = UUID().uuidString
        let photoPath = "review-photos/\(userId)/\(photoId).jpg"
        let photoRef = storage.reference().child(photoPath)
        
        // Upload metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000" // Cache for 1 year
        
        // Upload the image
        photoRef.putData(compressedImageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ Photo upload failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Get download URL
            photoRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Failed to get download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(PhotoStorageError.downloadURLFailed))
                    return
                }
                
                print("✅ Photo uploaded successfully: \(downloadURL.absoluteString)")
                completion(.success(downloadURL.absoluteString))
            }
        }
    }
    
    /// Uploads a profile photo and returns the download URL
    func uploadProfilePhoto(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(PhotoStorageError.userNotAuthenticated))
            return
        }
        
        // Compress and resize image for profile
        guard let compressedImageData = compressImageForProfile(image) else {
            completion(.failure(PhotoStorageError.imageCompressionFailed))
            return
        }
        
        // Profile photos use userId as filename (one per user)
        let photoPath = "profile-photos/\(userId).jpg"
        let photoRef = storage.reference().child(photoPath)
        
        // Upload metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000" // Cache for 1 year
        
        // Upload the image
        photoRef.putData(compressedImageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ Profile photo upload failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Get download URL
            photoRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Failed to get profile photo download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(PhotoStorageError.downloadURLFailed))
                    return
                }
                
                print("✅ Profile photo uploaded successfully: \(downloadURL.absoluteString)")
                completion(.success(downloadURL.absoluteString))
            }
        }
    }
    
    /// Deletes a review photo
    func deleteReviewPhoto(photoURL: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: photoURL) else {
            completion(.failure(PhotoStorageError.invalidURL))
            return
        }
        
        // Extract the path from the URL
        let pathComponents = url.pathComponents
        guard pathComponents.count >= 4 else {
            completion(.failure(PhotoStorageError.invalidURL))
            return
        }
        
        // Reconstruct the storage path
        let storagePath = "\(pathComponents[pathComponents.count - 3])/\(pathComponents[pathComponents.count - 2])/\(pathComponents[pathComponents.count - 1])"
        let photoRef = storage.reference().child(storagePath)
        
        photoRef.delete { error in
            if let error = error {
                print("❌ Failed to delete photo: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Photo deleted successfully")
            completion(.success(()))
        }
    }
    
    // MARK: - Image Processing
    
    /// Compresses and resizes image for review photos
    private func compressImageForReview(_ image: UIImage) -> Data? {
        // Resize to max 1200x1200 for reviews
        let maxDimension: CGFloat = 1200
        let resizedImage = resizeImage(image, maxDimension: maxDimension)
        
        // Compress with quality 0.8 (good balance of quality and size)
        return resizedImage.jpegData(compressionQuality: 0.8)
    }
    
    /// Compresses and resizes image for profile photos
    private func compressImageForProfile(_ image: UIImage) -> Data? {
        // Resize to max 400x400 for profile photos
        let maxDimension: CGFloat = 400
        let resizedImage = resizeImage(image, maxDimension: maxDimension)
        
        // Compress with quality 0.9 for profile photos
        return resizedImage.jpegData(compressionQuality: 0.9)
    }
    
    /// Resizes image maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Calculate new size maintaining aspect ratio
        let widthRatio = maxDimension / size.width
        let heightRatio = maxDimension / size.height
        let ratio = min(widthRatio, heightRatio)
        
        // If image is already smaller, don't resize
        if ratio >= 1.0 {
            return image
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    // MARK: - Error Types
    
    enum PhotoStorageError: LocalizedError {
        case userNotAuthenticated
        case imageCompressionFailed
        case downloadURLFailed
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .userNotAuthenticated:
                return "User not authenticated"
            case .imageCompressionFailed:
                return "Failed to compress image"
            case .downloadURLFailed:
                return "Failed to get download URL"
            case .invalidURL:
                return "Invalid photo URL"
            }
        }
    }
}
