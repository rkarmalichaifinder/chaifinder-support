import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ProfileView: View {
    @State private var user: UserProfile?
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var bio: String = ""
    @State private var isEditing = false
    @State private var error: String?
    @State private var loading = true
    @State private var showNamePrompt = false
    @State private var newName = ""
    @State private var showSuccessAlert = false

    // New for deletion
    @State private var showDeleteAlert = false
    @State private var deleteError: String?
    @State private var isDeleting = false
    @State private var accountDeleted = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if loading {
                    ProgressView("Loading profile...")
                } else if accountDeleted {
                    Text("Your account has been deleted.")
                        .font(.title2)
                        .foregroundColor(.red)
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

                    // Delete account button
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Text("Delete My Account")
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
                    if user != nil && !accountDeleted {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveChanges()
                            }
                            isEditing.toggle()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if !accountDeleted {
                        Button("Log Out") {
                            logout()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                loadUserProfile()
            }
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
            .alert("Confirm Deletion", isPresented: $showDeleteAlert) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete your account? This cannot be undone.")
            }
        }
    }

    private var profileImageView: some View {
        VStack {
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

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        isDeleting = true

        // Step 1: Delete Firestore doc
        db.collection("users").document(user.uid).delete { error in
            if let error = error {
                print("❌ Firestore delete failed: \(error.localizedDescription)")
                return
            }

            // Step 2: Delete Firebase Auth account
            user.delete { error in
                isDeleting = false
                if let error = error {
                    print("❌ Firebase delete failed: \(error.localizedDescription)")
                } else {
                    accountDeleted = true
                    self.user = nil
                }
            }
        }
    }

    private func shouldPromptForName(_ name: String) -> Bool {
        return name.lowercased() == "anonymous"
            || name.lowercased().contains("privaterelay")
            || name.lowercased().contains("demo")
    }
}
