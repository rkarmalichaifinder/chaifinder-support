import SwiftUI
import UIKit
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: Data?
    @Binding var showingCamera: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                if let imageData = editedImage.jpegData(compressionQuality: 0.8) {
                    parent.selectedImage = imageData
                }
            } else if let originalImage = info[.originalImage] as? UIImage {
                if let imageData = originalImage.jpegData(compressionQuality: 0.8) {
                    parent.selectedImage = imageData
                }
            }
            
            parent.showingCamera = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.showingCamera = false
        }
        
        func presentationControllerWillPresent(_ presentationController: UIPresentationController) {
            // Handle presentation if needed
        }
        
        func presentationControllerDidPresent(_ presentationController: UIPresentationController) {
            // Handle presentation if needed
        }
        
        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            // Handle dismissal if needed
        }
        
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // Handle dismissal if needed
        }
    }
}
