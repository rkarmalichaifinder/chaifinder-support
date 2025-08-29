import SwiftUI
import FirebaseAuth

struct EditBioView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var bio: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Edit Bio")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .padding(.top, DesignSystem.Spacing.lg)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Bio")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Tell us about yourself...", text: $bio, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(DesignSystem.Typography.bodyMedium)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.searchBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                        .lineLimit(5...10)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(DesignSystem.Typography.bodySmall)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                }

                Button(action: {
                    Task {
                        await saveBio()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isLoading ? "Saving..." : "Save")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.lg)
                    .background(isLoading ? Color.gray : DesignSystem.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .disabled(isLoading)

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .iPadOptimized()
            .keyboardDismissible()
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                bio = sessionStore.userProfile?.bio ?? ""
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func saveBio() async {
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedBio.count <= 500 else {
            await MainActor.run {
                errorMessage = "Bio must be 500 characters or less"
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            await sessionStore.updateBio(to: trimmedBio)
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to update bio. Please try again."
            }
        }
    }
}
