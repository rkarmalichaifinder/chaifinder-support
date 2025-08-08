import SwiftUI
import FirebaseAuth

struct EditNameView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var displayName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Edit Name")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .padding(.top, DesignSystem.Spacing.lg)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Display Name")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(DesignSystem.Typography.bodyMedium)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.searchBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(DesignSystem.Typography.bodySmall)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                }

                Button(action: {
                    Task {
                        await saveDisplayName()
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
                .disabled(isLoading || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .iPadOptimized()
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                displayName = sessionStore.userProfile?.displayName ?? ""
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func saveDisplayName() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            await MainActor.run {
                errorMessage = "Name cannot be empty"
            }
            return
        }
        
        guard trimmedName.count <= 50 else {
            await MainActor.run {
                errorMessage = "Name must be 50 characters or less"
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            await sessionStore.updateDisplayName(to: trimmedName)
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to update name. Please try again."
            }
        }
    }
} 