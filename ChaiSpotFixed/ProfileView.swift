import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
// import FirebaseStorage  // Temporarily disabled
// import PhotosUI         // Temporarily disabled

struct ProfileView: View {
    @State private var user: UserProfile?
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var bio: String = ""
    @State private var isEditing = false
    @State private var error: String?
    @State private var loading = true
    // @State private var selectedItem: PhotosPickerItem? = nil
    // @State private var selectedImage: UIImage? = nil
    // @State private var uploadingImage = false
    @State private var showNamePrompt = false
    @State private var newName = ""
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if loading {
                    ProgressView("Loading profile...")
                } else if let user = user {
                    profileImageView

                    if isEditing {
                        editableFields
                    } else {
                        profileFields
                    }

                    if shouldPromptForName(user.displayName) {
                        Button("Set Your Name") {
                            newName = displayName
                            showNamePrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()
                } else {
                    Text("No user data found.")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .navigationTitle("My Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if user != nil {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveChanges()
                            }
                            isEditing.toggle()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Log Out") {
                        logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                loadUserProfile()
            }
            // .photosPicker(isPresented: $uploadingImage, selection: $selectedItem, matching: .images)
            // .onChange(of: selectedItem) { newItem in
            //     Task {
            //         if let data = try? await newItem?.loadTransferable(type: Data.self),
            //            let image = UIImage(data: data) {
            //             self.selectedImage = image
            //             await uploadProfileImage(image)
            //         }
            //     }
            // }
            .sheet(isPresented: $showNamePrompt) {
                NavigationStack {
                    Form {
                        Section(header: Text("Enter your name")) {
                            TextField("Full Name", text: $newName)
                        }
                        Section {
                            Button("Save") {
                                updateDisplayName(newName)
                            }
                        }
                    }
                    .navigationTitle("Update Name")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showNamePrompt = false
                            }
                        }
                    }
                }
            }
            .alert("Name Updated", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var profileImageView: some View {
        VStack {
            // if let image = selectedImage {
            //     Image(uiImage: image)
            //         .resizable()
            //         .scaledToFill()
            //         .frame(width: 120, height: 120)
            //         .clipShape(Circle())
            // }
            if let urlString = user?.photoURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.gray)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 120, height: 120)
            }
        }
        // .onTapGesture {
        //     uploadingImage = true
        // }
    }

    private var editableFields: some View {
        Group {
            TextField("Display Name", text: $displayName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Bio", text: $bio)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    private var profileFields: some View {
        Group {
            Text(user?.displayName ?? "")
                .font(.title)
            Text(user?.email ?? "")
                .foregroundColor(.gray)
            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .italic()
            }
        }
    }

    private func loadUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.error = "User not logged in"
            self.loading = false
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, err in
            self.loading = false
            if let err = err {
                self.error = err.localizedDescription
                return
            }

            guard let doc = snapshot, doc.exists else {
                self.error = "No user data found"
                return
            }

            do {
                let fetchedUser = try doc.data(as: UserProfile.self)
                self.user = fetchedUser
                self.displayName = fetchedUser.displayName
                self.email = fetchedUser.email
                self.bio = fetchedUser.bio ?? ""
            } catch {
                self.error = "Failed to decode user data"
                print("🧨 Decoding error: \(error)")
                print("🔥 Document data: \(doc.data() ?? [:])")
            }
        }
    }

    private func saveChanges() {
        guard let uid = Auth.auth().currentUser?.uid, var updatedUser = user else { return }

        updatedUser.displayName = displayName
        updatedUser.email = email
        updatedUser.bio = bio

        let db = Firestore.firestore()
        do {
            try db.collection("users").document(uid).setData(from: updatedUser)
            self.user = updatedUser
            print("✅ Profile updated.")
        } catch {
            print("❌ Failed to update: \(error.localizedDescription)")
        }
    }

    // Temporarily disabled
    // private func uploadProfileImage(_ image: UIImage) async {
    //     guard let uid = Auth.auth().currentUser?.uid else {
    //         print("❌ No current user found")
    //         return
    //     }
    //     guard let imageData = image.jpegData(compressionQuality: 0.8) else {
    //         print("❌ Failed to get JPEG data from image")
    //         return
    //     }
    //     let storage = Storage.storage()
    //     let storageRef = storage.reference().child("profileImages/\(uid).jpg")
    //     do {
    //         let _ = try await storageRef.putDataAsync(imageData, metadata: nil)
    //         let downloadURL = try await storageRef.downloadURL()
    //         self.user?.photoURL = downloadURL.absoluteString
    //         saveChanges()
    //         print("✅ Uploaded profile image and updated photoURL.")
    //     } catch {
    //         print("❌ Error uploading profile image: \(error.localizedDescription)")
    //     }
    // }

    private func updateDisplayName(_ newName: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData(["displayName": newName]) { error in
            if error == nil {
                self.displayName = newName
                self.user?.displayName = newName
                self.showNamePrompt = false
                self.showSuccessAlert = true
            } else {
                print("❌ Failed to update name:", error?.localizedDescription ?? "")
            }
        }
    }

    private func logout() {
        do {
            try Auth.auth().signOut()
            user = nil
            displayName = ""
            email = ""
            bio = ""
        } catch {
            print("❌ Failed to log out: \(error.localizedDescription)")
        }
    }

    private func shouldPromptForName(_ name: String) -> Bool {
        return name.lowercased() == "anonymous"
            || name.lowercased().contains("privaterelay")
            || name.lowercased().contains("demo")
    }
}
