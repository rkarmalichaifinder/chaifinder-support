import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct PrivacySettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var privacyDefaults: PrivacyDefaults
    @State private var isLoading = false
    @State private var showingSaveConfirmation = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDataExport = false
    @State private var showingDeleteAccount = false
    @State private var showingLocationSettings = false
    
    init() {
        // Initialize with default values
        self._privacyDefaults = State(initialValue: PrivacyDefaults())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Review Visibility Section
                    reviewVisibilitySection
                    
                    // Social Privacy Section
                    socialPrivacySection
                    
                    // Data Collection Section
                    dataCollectionSection
                    
                    // Location Privacy Section
                    locationPrivacySection
                    
                    // Data Rights Section
                    dataRightsSection
                    
                    // Actions Section
                    actionsSection
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePrivacySettings()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadCurrentPrivacySettings()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") { }
            } message: {
                Text("Your privacy settings have been updated successfully.")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary)
            
            Text("Privacy & Data Control")
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Control how your data is shared and who can see your activity")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .iPadCardStyle()
    }
    
    // MARK: - Review Visibility Section
    private var reviewVisibilitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Review Visibility")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("Control who can see your chai spot reviews")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                PrivacyOptionRow(
                    title: "Public",
                    description: "Everyone can see your reviews",
                    icon: "globe",
                    isSelected: privacyDefaults.reviewsDefaultVisibility == "public",
                    action: { privacyDefaults.reviewsDefaultVisibility = "public" }
                )
                
                PrivacyOptionRow(
                    title: "Friends Only",
                    description: "Only your friends can see your reviews",
                    icon: "person.2.fill",
                    isSelected: privacyDefaults.reviewsDefaultVisibility == "friends",
                    action: { privacyDefaults.reviewsDefaultVisibility = "friends" }
                )
                
                PrivacyOptionRow(
                    title: "Private",
                    description: "Only you can see your reviews",
                    icon: "lock.fill",
                    isSelected: privacyDefaults.reviewsDefaultVisibility == "private",
                    action: { privacyDefaults.reviewsDefaultVisibility = "private" }
                )
            }
            
            Toggle("Allow friends to see all my reviews", isOn: $privacyDefaults.allowFriendsSeeAll)
                .font(DesignSystem.Typography.bodyMedium)
                .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .iPadCardStyle()
    }
    
    // MARK: - Social Privacy Section
    private var socialPrivacySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Text("Social Privacy")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("Control your social interactions and friend connections")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Toggle("Show my profile to other users", isOn: .constant(true))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Allow friend requests from strangers", isOn: .constant(true))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Show my activity to friends", isOn: .constant(true))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Show my location to friends", isOn: .constant(false))
                    .font(DesignSystem.Typography.bodyMedium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .iPadCardStyle()
    }
    
    // MARK: - Data Collection Section
    private var dataCollectionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(DesignSystem.Colors.info)
                
                Text("Data Collection")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("Control what data we collect and how it's used")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Toggle("Usage analytics and crash reports", isOn: .constant(true))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Personalized recommendations", isOn: .constant(true))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Marketing communications", isOn: .constant(false))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Third-party analytics", isOn: .constant(false))
                    .font(DesignSystem.Typography.bodyMedium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .iPadCardStyle()
    }
    
    // MARK: - Location Privacy Section
    private var locationPrivacySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(DesignSystem.Colors.accent)
                
                Text("Location Privacy")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Settings") {
                    showingLocationSettings = true
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            }
            
            Text("Control how your location data is used")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Toggle("Precise location for nearby spots", isOn: .constant(true))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Location history for recommendations", isOn: .constant(false))
                    .font(DesignSystem.Typography.bodyMedium)
                
                Toggle("Share location with friends", isOn: .constant(false))
                    .font(DesignSystem.Typography.bodyMedium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .iPadCardStyle()
    }
    
    // MARK: - Data Rights Section
    private var dataRightsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(DesignSystem.Colors.warning)
                
                Text("Your Data Rights")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("Exercise your rights over your personal data")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { showingDataExport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(DesignSystem.Colors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export My Data")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                            Text("Download a copy of your data")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showingDeleteAccount = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete My Account")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                            Text("Permanently remove all your data")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .iPadCardStyle()
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button("View Full Privacy Policy") {
                showingPrivacyPolicy = true
            }
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.primary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            
            Text("By using this app, you agree to our Privacy Policy and Terms of Service")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .iPadCardStyle()
    }
    
    // MARK: - Helper Methods
    private func loadCurrentPrivacySettings() {
        guard let userProfile = sessionStore.userProfile else { return }
        
        if let privacy = userProfile.privacyDefaults {
            privacyDefaults = privacy
        }
    }
    
    private func savePrivacySettings() {
        isLoading = true
        
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let privacyData: [String: Any] = [
            "privacyDefaults": [
                "reviewsDefaultVisibility": privacyDefaults.reviewsDefaultVisibility,
                "allowFriendsSeeAll": privacyDefaults.allowFriendsSeeAll
            ]
        ]
        
        Firestore.firestore().collection("users").document(uid).updateData(privacyData) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("❌ Failed to save privacy settings: \(error.localizedDescription)")
                } else {
                    // Update local user profile
                    if var userProfile = self.sessionStore.userProfile {
                        userProfile.privacyDefaults = self.privacyDefaults
                        self.sessionStore.userProfile = userProfile
                    }
                    
                    showingSaveConfirmation = true
                }
            }
        }
    }
}

// MARK: - Privacy Option Row
struct PrivacyOptionRow: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PrivacySettingsView()
        .environmentObject(SessionStore())
}
