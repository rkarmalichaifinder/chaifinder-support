import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

struct UploadProfilePhotoView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var croppedImage: UIImage? = nil
    @State private var isCropping = false
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            if let cropped = croppedImage {
                Image(uiImage: cropped)
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.gray)
            }

            PhotosPicker("Choose Photo", selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            self.selectedImage = image
                            self.isCropping = true
                        }
                    }
                }

            if croppedImage != nil {
                Button("Upload") {
                    uploadProfilePhoto()
                }
                .disabled(isUploading)
                .buttonStyle(.borderedProminent)
            }

            if isUploading {
                ProgressView("Uploading...")
            }

            if uploadSuccess {
                Text("✅ Photo uploaded!")
                    .foregroundColor(.green)
            }

            if let error = errorMessage {
                Text("⚠️ \(error)")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .navigationTitle("Profile Photo")
        .sheet(isPresented: $isCropping) {
            if let image = selectedImage {
                CropImageView(originalImage: image) { cropped in
                    self.croppedImage = cropped
                    self.isCropping = false
                }
            }
        }
    }

    private func uploadProfilePhoto() {
        guard let uid = Auth.auth().currentUser?.uid,
              let imageData = croppedImage?.jpegData(compressionQuality: 0.8) else { return }

        isUploading = true
        let storageRef = Storage.storage().reference().child("profilePhotos/\(uid).jpg")

        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isUploading = false
                return
            }

            storageRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    self.errorMessage = "Failed to get download URL"
                    self.isUploading = false
                    return
                }

                Firestore.firestore().collection("users").document(uid).updateData([
                    "photoURL": downloadURL.absoluteString
                ]) { error in
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.uploadSuccess = true
                    }
                    self.isUploading = false
                }
            }
        }
    }
}
import SwiftUI

struct CropImageView: View {
    let originalImage: UIImage
    let onCrop: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack {
            Spacer()
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()

                    Image(uiImage: originalImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                        .scaleEffect(zoom)
                        .offset(offset)
                        .gesture(
                            DragGesture().onChanged { value in
                                offset = value.translation
                            }
                        )
                        .gesture(
                            MagnificationGesture().onChanged { value in
                                zoom = value
                            }
                        )
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: geo.size.width, height: geo.size.width)
                        )
                }
            }
            .frame(height: UIScreen.main.bounds.width)

            Button("Crop & Save") {
                let cropped = cropToSquare(image: originalImage)
                onCrop(cropped)
                dismiss()
            }
            .padding()
        }
    }

    func cropToSquare(image: UIImage) -> UIImage {
        let cgImage = image.cgImage!
        let contextImage = UIImage(cgImage: cgImage)
        let contextSize = contextImage.size

        let side = min(contextSize.width, contextSize.height)
        let posX = (contextSize.width - side) / 2
        let posY = (contextSize.height - side) / 2

        let rect = CGRect(x: posX, y: posY, width: side, height: side)

        guard let imageRef = cgImage.cropping(to: rect) else {
            return image
        }

        return UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
    }
}
