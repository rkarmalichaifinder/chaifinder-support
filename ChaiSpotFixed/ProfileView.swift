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
    @State private var savedSpotsCount = 0
    @State private var showingSavedSpots = false

    // New for deletion
    @State private var showDeleteAlert = false
    @State private var deleteError: String?
    @State private var isDeleting = false
    @State private var accountDeleted = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if loading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading profile...")
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .padding(.top, DesignSystem.Spacing.md)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(DesignSystem.Spacing.xl)
                    } else if accountDeleted {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "person.crop.circle.badge.minus")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            
                            Text("Account Deleted")
                                .font(DesignSystem.Typography.titleMedium)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text("Your account has been successfully deleted.")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(DesignSystem.Spacing.xl)
                    } else if let user = user {
                        // Profile Header
                        profileHeaderSection
                        
                        // My List Section
                        myListSection
                        
                        // Profile Actions
                        profileActionsSection
                        
                        // Delete Account
                        deleteAccountSection
                        
                        Spacer(minLength: 100)
                    } else {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text("No User Data")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Unable to load your profile information.")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(DesignSystem.Spacing.xl)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if user != nil && !accountDeleted {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveChanges()
                            }
                            isEditing.toggle()
                        }
                        .foregroundColor(DesignSystem.Colors.primary)
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
                loadSavedSpotsCount()
            }
            .sheet(isPresented: $showNamePrompt) {
                NavigationStack {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Text("Update Your Name")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        TextField("Full Name", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(DesignSystem.Typography.bodyMedium)
                        
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Button("Cancel") {
                                showNamePrompt = false
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button("Save") {
                                updateDisplayName(newName)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .navigationTitle("Update Name")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showingSavedSpots) {
                SavedSpotsView()
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

    // MARK: - View Components
    
    private var profileHeaderSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Profile Image
            if let urlString = user?.photoURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(DesignSystem.Colors.textSecondary)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.primary, lineWidth: 3)
                )
            } else {
                Circle()
                    .fill(DesignSystem.Colors.textSecondary)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.primary, lineWidth: 3)
                    )
            }
            
            // Name Prompt Button
            if shouldPromptForName(user?.displayName ?? "") {
                Button("Set Your Name") {
                    newName = displayName
                    showNamePrompt = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private var myListSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("My List")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("\(savedSpotsCount) saved spots")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button("View All") {
                    showingSavedSpots = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private var profileActionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if isEditing {
                editableFields
            } else {
                profileFields
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private var deleteAccountSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                    Text("Delete My Account")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(Color.red)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }

    private var editableFields: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Display Name")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                TextField("Enter your name", text: $displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(DesignSystem.Typography.bodyMedium)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Email")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(DesignSystem.Typography.bodyMedium)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Bio")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                TextField("Tell us about yourself", text: $bio)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(DesignSystem.Typography.bodyMedium)
            }
        }
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Name")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Text(user?.displayName ?? "Not set")
                    .font(DesignSystem.Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Email")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Text(user?.email ?? "Not set")
                    .font(DesignSystem.Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            if let bio = user?.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Bio")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(bio)
                        .font(DesignSystem.Typography.bodyLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .italic()
                }
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
            DispatchQueue.main.async {
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
    }
    
    private func loadSavedSpotsCount() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let db = Firestore.firestore()
        print("🔄 Loading saved spots count for user: \(userId)")
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading saved spots count: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("❌ No user data found for saved spots count")
                    self.savedSpotsCount = 0
                    return
                }
                
                print("📄 User document for count: \(data)")
                
                guard let savedSpotIds = data["savedSpots"] as? [String] else {
                    print("❌ No savedSpots field found in user document for count")
                    self.savedSpotsCount = 0
                    return
                }
                
                print("📄 Found \(savedSpotIds.count) saved spots for count")
                self.savedSpotsCount = savedSpotIds.count
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
            DispatchQueue.main.async {
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
                DispatchQueue.main.async {
                    self.isDeleting = false
                    if let error = error {
                        print("❌ Firebase delete failed: \(error.localizedDescription)")
                    } else {
                        self.accountDeleted = true
                        self.user = nil
                    }
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
