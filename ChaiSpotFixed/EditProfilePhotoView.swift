import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import AVFoundation // Added for camera authorization

struct EditProfilePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    
    // Photo states (using the enhanced algorithm from UnifiedChaiForm)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data? = nil
    @State private var isUploadingPhoto = false
    @State private var showingPhotoOptions = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var hasProcessedPhoto = false
    
    // UI states
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var showingSuccess = false
    
    // Debounce mechanism to prevent multiple simultaneous profile refreshes
    @State private var isRefreshingProfile = false
    
    // Force refresh when profile changes
    @State private var profileRefreshTrigger = UUID()
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Current Profile Photo
                    currentPhotoSection
                    
                    // Photo Selection Options
                    photoSelectionSection
                    
                    // Upload Progress
                    if isUploadingPhoto {
                        uploadProgressSection
                    }
                    
                    // Error Display
                    if let errorMessage = errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    // Success Message
                    if showingSuccess {
                        successSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding(DesignSystem.Spacing.lg)
                .id(profileRefreshTrigger) // Force refresh when profile changes
                .onAppear {
                    print("🔄 EditProfilePhotoView body appeared with profileRefreshTrigger: \(profileRefreshTrigger)")
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Edit Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { newItem in
                print("🔄 selectedPhoto changed: \(newItem != nil ? "Has item" : "No item")")
                
                // Reset processing flag when photo selection changes
                hasProcessedPhoto = false
                
                // Only process if we have a new item
                guard let newItem = newItem else { return }
                
                // Prevent multiple simultaneous photo processing
                guard !isProcessing else {
                    print("🔄 Photo processing already in progress, skipping...")
                    return
                }
                
                Task {
                    isProcessing = true
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            print("✅ PhotosPicker: Photo loaded successfully, setting selectedPhotoData")
                            selectedPhotoData = data
                            isProcessing = false
                            // Don't call uploadProfilePhoto() here - let the onChange(of: selectedPhotoData) handle it
                        }
                    } else {
                        await MainActor.run {
                            print("❌ PhotosPicker: Failed to load photo data")
                            isProcessing = false
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoData) { newPhotoData in
                print("🔄 selectedPhotoData changed: \(newPhotoData != nil ? "Has data" : "No data")")
                if let photoData = newPhotoData {
                    print("🔄 selectedPhotoData size: \(photoData.count) bytes")
                }
                
                // Reset processing flag when photo data changes
                hasProcessedPhoto = false
                
                // Only process if we have new photo data
                guard let newPhotoData = newPhotoData else { 
                    print("🔄 No new photo data, skipping processing")
                    return 
                }
                
                // Prevent multiple simultaneous photo processing
                guard !isProcessing else {
                    print("🔄 Photo processing already in progress, skipping...")
                    return
                }
                
                print("✅ Starting photo processing...")
                isProcessing = true
                
                // Auto-upload the photo after a short delay to ensure UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Auto-uploading photo after delay...")
                    self.uploadProfilePhoto()
                    self.isProcessing = false
                }
            }
            .onChange(of: showingCamera) { newValue in
                print("🔄 showingCamera changed to: \(newValue)")
                if newValue {
                    print("📸 Camera sheet should be presented")
                } else {
                    print("📸 Camera sheet should be dismissed")
                }
            }
            .onAppear {
                print("🔄 EditProfilePhotoView appeared")
                // Reset state when view appears
                hasProcessedPhoto = false
                selectedPhoto = nil
                selectedPhotoData = nil
                isUploadingPhoto = false
                isProcessing = false
                isRefreshingProfile = false
                errorMessage = nil
                showingSuccess = false
                
                // Force refresh profile data on appear
                if let userId = Auth.auth().currentUser?.uid {
                    Task {
                        print("🔄 Force refreshing profile data on appear...")
                        await sessionStore.loadUserProfileAsync(uid: userId)
                        print("✅ Profile data refreshed on appear")
                        

                    }
                }
            }
            .onChange(of: sessionStore.userProfile?.photoURL) { newPhotoURL in
                // Force a refresh of the view
                profileRefreshTrigger = UUID()
            }
            .onReceive(sessionStore.objectWillChange) {
                // Force refresh when sessionStore changes
                profileRefreshTrigger = UUID()
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(selectedImage: $selectedPhotoData, showingCamera: $showingCamera)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "camera.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityHidden(true)
            
            Text("Update Your Profile Photo")
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Choose a photo that represents you best!")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: DesignSystem.Shadows.medium.color, radius: DesignSystem.Shadows.medium.radius, x: DesignSystem.Shadows.medium.x, y: DesignSystem.Shadows.medium.y)
    }
    
    // MARK: - Current Photo Section
    private var currentPhotoSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Current Profile Photo")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Current photo display
                if let photoURL = sessionStore.userProfile?.photoURL, !photoURL.isEmpty {
                    Group { // Added Group to apply frame modifiers correctly
                        if photoURL.hasPrefix("data:image") {
                            // Handle base64 data URL
                            if let data = Data(base64Encoded: photoURL.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)

                            } else {
                                // Fallback if base64 decoding fails
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .onAppear {
                                        print("❌ Failed to decode base64 current profile photo")
                                        print("❌ PhotoURL: \(photoURL)")
                                        print("❌ PhotoURL length: \(photoURL.count)")
                                        let base64Part = photoURL.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                                        print("❌ Base64 part length: \(base64Part.count)")
                                    }
                            }
                        } else {
                            // Handle regular URL
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .onAppear {
                                print("🔍 AsyncImage loading current photo from: \(photoURL)")
                            }
                        }
                    }
                    .frame(width: 80, height: 80) // Applied to Group
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                    )
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Current Photo")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                    
                    if let photoURL = sessionStore.userProfile?.photoURL,
                       !photoURL.isEmpty {
                        Text("Photo uploaded")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.success)
                    } else {
                        Text("No photo set")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                    }
                }
                
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Photo Selection Section
    private var photoSelectionSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Choose New Photo")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                if let photoData = selectedPhotoData,
                   let uiImage = UIImage(data: photoData) {
                    // Display selected photo
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .overlay(
                                                        Button(action: {
                            selectedPhotoData = nil
                            selectedPhoto = nil
                            hasProcessedPhoto = false
                        }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(8),
                                alignment: .topTrailing
                            )
                        
                        Text("Photo selected! Tap the X to remove or Save to upload.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Photo picker options
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // PhotosPicker for library
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                    .foregroundColor(DesignSystem.Colors.primary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Choose from Library")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.medium)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    
                                    Text("Select a photo from your photo library")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Camera option (if available)
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button(action: {
                                print("📸 Camera button tapped")
                                print("📸 Current showingCamera value: \(showingCamera)")
                                
                                // Check camera authorization status
                                let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
                                print("📸 Camera authorization status: \(authStatus.rawValue)")
                                
                                switch authStatus {
                                case .authorized:
                                    print("📸 Camera authorized, setting showingCamera = true")
                                    showingCamera = true
                                    print("📸 showingCamera set to: \(showingCamera)")
                                    print("📸 Camera button: State updated, sheet should appear")
                                case .denied, .restricted:
                                    print("📸 Camera access denied or restricted")
                                    // Show alert to user about camera access
                                    errorMessage = "Camera access is required. Please enable it in Settings."
                                case .notDetermined:
                                    print("📸 Camera access not determined, requesting...")
                                    AVCaptureDevice.requestAccess(for: .video) { granted in
                                        DispatchQueue.main.async {
                                            if granted {
                                                print("📸 Camera access granted, setting showingCamera = true")
                                                self.showingCamera = true
                                                print("📸 showingCamera set to: \(self.showingCamera)")
                                                print("📸 Camera button: State updated after permission request, sheet should appear")
                                            } else {
                                                print("📸 Camera access denied")
                                                self.errorMessage = "Camera access denied"
                                            }
                                        }
                                    }
                                @unknown default:
                                    print("📸 Unknown camera authorization status")
                                    errorMessage = "Unable to access camera"
                                }
                            }) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Take New Photo")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .fontWeight(.medium)
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                        
                                        Text("Use your camera to take a new photo")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.cardBackground)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Upload Progress Section
    private var uploadProgressSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Uploading photo...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.info.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }
    
    // MARK: - Error Section
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DesignSystem.Colors.error)
                
                Text("Error")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.error)
                
                Spacer()
            }
            
            Text(message)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.error.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Success Section
    private var successSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.success)
                
                Text("Photo Updated Successfully!")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.success)
                
                Spacer()
            }
            
            Text("Your profile photo has been updated. This screen will close automatically in a moment.")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.success.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Save Button
            if selectedPhotoData != nil {
                Button(action: {
                    // Prevent manual upload if auto-upload is already in progress
                    guard !isUploadingPhoto else {
                        print("🔄 Upload already in progress, manual upload blocked")
                        return
                    }
                    
                    uploadProfilePhoto()
                }) {
                    HStack {
                        if isUploadingPhoto {
                            ProgressView()
                                .scaleEffect(0.8)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .accessibilityHidden(true)
                        }
                        
                        Text(isUploadingPhoto ? "Uploading..." : "Save Photo")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DesignSystem.Layout.minTouchTarget)
                    .background(isUploadingPhoto ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.primary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .disabled(isUploadingPhoto)
                .accessibilityLabel("Save photo")
                .accessibilityHint("Double tap to save your profile photo")
            }
            
            // Remove Photo Button (only show if user has a photo)
            if let photoURL = sessionStore.userProfile?.photoURL,
               !photoURL.isEmpty {
                Button(action: {
                    removeProfilePhoto()
                }) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .accessibilityHidden(true)
                        
                        Text("Remove Photo")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(DesignSystem.Colors.error)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DesignSystem.Layout.minTouchTarget)
                    .background(DesignSystem.Colors.error.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .accessibilityLabel("Remove photo")
                .accessibilityHint("Double tap to remove your profile photo")
            }
            
            // Debug Reset Button (only show in debug builds)
            #if DEBUG
            Button(action: {
                // Reset all state
                hasProcessedPhoto = false
                selectedPhoto = nil
                selectedPhotoData = nil
                isUploadingPhoto = false
                isProcessing = false
                isRefreshingProfile = false
                errorMessage = nil
                showingSuccess = false
                print("🔄 Debug: Reset all state")
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .accessibilityHidden(true)
                    
                    Text("Reset State (Debug)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                }
                .foregroundColor(DesignSystem.Colors.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: DesignSystem.Layout.minTouchTarget)
                .background(DesignSystem.Colors.secondary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .accessibilityLabel("Reset state")
            .accessibilityHint("Double tap to reset all state (debug only)")
            #endif
        }
        .padding(DesignSystem.Spacing.lg)
    }
    
    // MARK: - Helper Functions
    private func loadCurrentProfilePhoto() {
        // Profile photo is already loaded in sessionStore
        // This function can be used for additional loading logic if needed
    }
    
    private func uploadProfilePhoto() {
        guard let photoData = selectedPhotoData else {
            errorMessage = "No photo selected"
            return
        }
        
        // Prevent multiple uploads of the same photo
        guard !isUploadingPhoto else {
            return
        }
        
        // Prevent multiple profile refreshes
        guard !isRefreshingProfile else {
            return
        }
        
        isUploadingPhoto = true
        errorMessage = nil
        
        Task {
            do {
                // Compress and resize the image to keep it under Firestore's 1MB limit
                let compressedImageData = await compressAndResizeImage(photoData)
                
                // Check if compressed image is still too large for Firestore
                let base64String = compressedImageData.base64EncodedString()
                let estimatedSize = base64String.count
                
                if estimatedSize > 1000000 { // 1MB limit with some buffer
                    await MainActor.run {
                        isUploadingPhoto = false
                        errorMessage = "Image is too large even after compression. Please try a smaller image."
                    }
                    return
                }
                
                let photoURL = "data:image/jpeg;base64,\(base64String)"
                
                await MainActor.run {
                    // Update the user profile with the compressed base64 photo data
                    updateUserProfilePhoto(photoURL)
                    
                    isUploadingPhoto = false
                    showingSuccess = true
                    
                    // Only set hasProcessedPhoto after successful upload
                    hasProcessedPhoto = true
                    
                    // Auto-dismiss after showing success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
                
            } catch {
                await MainActor.run {
                    isUploadingPhoto = false
                    hasProcessedPhoto = false
                    errorMessage = "Failed to process photo: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func compressAndResizeImage(_ imageData: Data) async -> Data {
        guard let image = UIImage(data: imageData) else { return imageData }
        
        // Calculate target size (max 600x600 pixels to ensure small file size)
        let maxDimension: CGFloat = 600
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // Start with high quality and reduce if needed
        var compressionQuality: CGFloat = 0.8
        var compressedData = resizedImage.jpegData(compressionQuality: compressionQuality)
        
        // If still too large, reduce quality further
        while let data = compressedData, data.count > 500000 && compressionQuality > 0.3 { // 500KB target
            compressionQuality -= 0.1
            compressedData = resizedImage.jpegData(compressionQuality: compressionQuality)
        }
        
        let finalData = compressedData ?? imageData
        print("📸 Image compressed: \(imageData.count) bytes -> \(finalData.count) bytes (quality: \(compressionQuality))")
        
        return finalData
    }
    
    private func updateUserProfilePhoto(_ photoURL: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).updateData([
            "photoURL": photoURL
        ]) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update profile: \(error.localizedDescription)"
                }
            } else {
                print("🔍 Debug: Updated photoURL to: \(photoURL)")
                
                // Verify the update by reading the document back
                self.db.collection("users").document(userId).getDocument { snapshot, error in
                    if let error = error {
                        print("❌ Debug: Failed to verify update: \(error.localizedDescription)")
                    } else if let data = snapshot?.data() {
                        let updatedPhotoURL = data["photoURL"] as? String
                        print("🔍 Debug: Firestore now contains photoURL: \(updatedPhotoURL ?? "nil")")
                        if let photoURL = updatedPhotoURL {
                            print("🔍 Debug: Firestore photoURL length: \(photoURL.count)")
                            if photoURL.hasPrefix("data:image") {
                                print("🔍 Debug: Firestore photoURL is base64 data URL")
                                print("🔍 Debug: Firestore photoURL starts with: \(String(photoURL.prefix(50)))")
                            } else {
                                print("🔍 Debug: Firestore photoURL is NOT base64 data URL")
                                print("🔍 Debug: Firestore photoURL starts with: \(String(photoURL.prefix(50)))")
                            }
                        }
                    }
                }
                
                // Refresh the user profile from Firestore to update the UI
                DispatchQueue.main.async {
                    Task {
                        // Add a small delay to ensure Firestore update has propagated
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        
                        // Prevent multiple simultaneous profile refreshes
                        guard !self.isRefreshingProfile else {
                            return
                        }
                        
                        self.isRefreshingProfile = true
                        await self.sessionStore.loadUserProfileAsync(uid: userId)
                        
                        // Simple UI refresh - no aggressive state manipulation
                        await MainActor.run {
                            self.sessionStore.objectWillChange.send()
                            
                            // Force a view refresh
                            self.profileRefreshTrigger = UUID()
                            
                            self.isRefreshingProfile = false
                        }
                    }
                }
            }
        }
    }
    
    private func removeProfilePhoto() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Remove from Firestore
        db.collection("users").document(userId).updateData([
            "photoURL": FieldValue.delete()
        ]) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to remove photo: \(error.localizedDescription)"
                }
            } else {
                // Refresh the user profile from Firestore to update the UI
                DispatchQueue.main.async {
                    Task {
                        // Prevent multiple simultaneous profile refreshes
                        guard !self.isRefreshingProfile else {
                            return
                        }
                        
                        self.isRefreshingProfile = true
                        await self.sessionStore.loadUserProfileAsync(uid: userId)
                        self.showingSuccess = true
                        
                        await MainActor.run {
                            self.isRefreshingProfile = false
                        }
                        
                        // Auto-dismiss after showing success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct EditProfilePhotoView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfilePhotoView()
            .environmentObject(SessionStore())
    }
}
