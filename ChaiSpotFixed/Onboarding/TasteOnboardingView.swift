import SwiftUI

struct TasteOnboardingView: View {
    @EnvironmentObject var session: SessionStore
    let onDone: () -> Void

    @State private var creaminess: Double = 3
    @State private var strength: Double = 3
    @State private var topNotes: Set<String> = []
    @State private var currentStep = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingSkipConfirmation = false
    
    private let totalSteps = 3
    private let chaiTypeOptions = ["cardamom", "ginger", "fennel", "saffron", "karak", "adeni"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced progress indicator
                progressSection
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Step content with smooth transitions
                        stepContent
                        
                        // Navigation buttons
                        navigationButtons
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Set your taste")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(DesignSystem.Animation.standard) {
                                currentStep -= 1
                            }
                        }
                        .accessibilityLabel("Go back to previous step")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        showingSkipConfirmation = true
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .accessibilityLabel("Skip onboarding")
                    .accessibilityHint("Skip setting taste preferences")
                }
            }
        }
        .navigationViewStyle(.stack)
        .overlay(
            // Loading overlay
            Group {
                if isLoading {
                    LoadingView("Saving your preferences...")
                        .transition(.opacity)
                }
            }
        )
        .animation(DesignSystem.Animation.standard, value: currentStep)
        .animation(DesignSystem.Animation.standard, value: isLoading)
        .alert("Skip Onboarding?", isPresented: $showingSkipConfirmation) {
            Button("Continue Setup", role: .cancel) { }
            Button("Skip", role: .destructive) {
                onDone()
            }
        } message: {
            Text("You can always set your preferences later in your profile settings.")
        }
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Progress bar
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primary))
                .scaleEffect(y: 1.5)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .accessibilityLabel("Progress: step \(currentStep + 1) of \(totalSteps)")
            
            // Step indicator with labels
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(step <= currentStep ? DesignSystem.Colors.primary : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(step == currentStep ? DesignSystem.Colors.primary : Color.clear, lineWidth: 2)
                            )
                            .animation(DesignSystem.Animation.standard, value: currentStep)
                        
                        Text(stepLabel(for: step))
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(step <= currentStep ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
    
    // MARK: - Step Labels
    private func stepLabel(for step: Int) -> String {
        switch step {
        case 0: return "Taste"
        case 1: return "Flavors"
        case 2: return "Review"
        default: return ""
        }
    }
    
    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            tastePreferencesStep
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 1:
            flavorNotesStep
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 2:
            reviewStep
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        default:
            EmptyView()
        }
    }
    
    // MARK: - Taste Preferences Step
    private var tastePreferencesStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .accessibilityHidden(true)
                
                Text("How do you like your chai?")
                    .font(DesignSystem.Typography.titleMedium)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Question: How do you like your chai?")
                
                Text("Slide to set your preferences for the perfect cup")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Creaminess
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Creaminess")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(creaminessLabel)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Slider(value: $creaminess, in: 1...5, step: 1)
                        .accentColor(DesignSystem.Colors.creaminessRating)
                        .accessibilityLabel("Creaminess level: \(creaminessLabel)")
                        .accessibilityValue("\(Int(creaminess)) out of 5")
                }
                
                // Strength
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Chai Strength")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(strengthLabel)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Slider(value: $strength, in: 1...5, step: 1)
                        .accentColor(DesignSystem.Colors.chaiStrengthRating)
                        .accessibilityLabel("Chai strength level: \(strengthLabel)")
                        .accessibilityValue("\(Int(strength)) out of 5")
                }
                

            }
        }
    }
    
    // MARK: - Flavor Notes Step
    private var flavorNotesStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .accessibilityHidden(true)
                
                Text("What flavors do you love?")
                    .font(DesignSystem.Typography.titleMedium)
                    .multilineTextAlignment(.center)
                
                Text("Select all the flavors that make your chai special")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.md) {
                ForEach(chaiTypeOptions, id: \.self) { flavor in
                    Button(action: {
                        if topNotes.contains(flavor) {
                            topNotes.remove(flavor)
                        } else {
                            topNotes.insert(flavor)
                        }
                    }) {
                        HStack {
                            Text(flavor.capitalized)
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if topNotes.contains(flavor) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(topNotes.contains(flavor) ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(topNotes.contains(flavor) ? DesignSystem.Colors.primary : DesignSystem.Colors.border, lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("\(flavor) flavor")
                    .accessibilityValue(topNotes.contains(flavor) ? "Selected" : "Not selected")
                    .accessibilityAddTraits(topNotes.contains(flavor) ? .isSelected : [])
                }
            }
        }
    }
    

    
    // MARK: - Review Step
    private var reviewStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.success)
                    .accessibilityHidden(true)
                
                Text("Review Your Preferences")
                    .font(DesignSystem.Typography.titleMedium)
                    .multilineTextAlignment(.center)
                
                Text("Here's what we learned about your taste")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: DesignSystem.Spacing.md) {
                preferenceRow("Creaminess", creaminessLabel, DesignSystem.Colors.creaminessRating)
                preferenceRow("Strength", strengthLabel, DesignSystem.Colors.chaiStrengthRating)
                
                if !topNotes.isEmpty {
                    preferenceRow("Favorite Flavors", topNotes.joined(separator: ", "), DesignSystem.Colors.primary)
                }
            }
            
            // Add helpful message based on preferences
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Based on your preferences, we'll recommend:")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text(generateRecommendationMessage())
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .multilineTextAlignment(.center)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation(DesignSystem.Animation.standard) {
                        currentStep -= 1
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Go back to previous step")
            }
            
            Spacer()
            
            Button(currentStep == totalSteps - 1 ? "Complete" : "Next") {
                if currentStep == totalSteps - 1 {
                    completeOnboarding()
                } else {

                    withAnimation(DesignSystem.Animation.standard) {
                        currentStep += 1
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(currentStep == 1 && topNotes.isEmpty)
            .accessibilityLabel(currentStep == totalSteps - 1 ? "Complete setup" : "Continue to next step")
        }
    }
    
    // MARK: - Helper Views
    private func preferenceRow(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Helper Functions
    private var creaminessLabel: String {
        switch Int(creaminess) {
        case 1: return "Light"
        case 2: return "Mild"
        case 3: return "Medium"
        case 4: return "Rich"
        case 5: return "Very Rich"
        default: return "Medium"
        }
    }
    
    private var strengthLabel: String {
        switch Int(strength) {
        case 1: return "Mild"
        case 2: return "Light"
        case 3: return "Medium"
        case 4: return "Strong"
        case 5: return "Very Strong"
        default: return "Medium"
        }
    }
    
    private func generateRecommendationMessage() -> String {
        var messages: [String] = []
        
        // Creaminess-based recommendations
        if creaminess >= 4 {
            messages.append("spots with rich, creamy chai")
        } else if creaminess <= 2 {
            messages.append("spots with light, refreshing chai")
        } else {
            messages.append("spots with balanced creaminess")
        }
        
        // Strength-based recommendations
        if strength >= 4 {
            messages.append("bold, intense chai options")
        } else if strength <= 2 {
            messages.append("mild, gentle chai varieties")
        } else {
            messages.append("moderately strong chai")
        }
        
        // Flavor-based recommendations
        if !topNotes.isEmpty {
            if topNotes.contains("cardamom") || topNotes.contains("ginger") {
                messages.append("traditional masala chai")
            }
            if topNotes.contains("saffron") {
                messages.append("premium saffron chai")
            }
            if topNotes.contains("karak") || topNotes.contains("adeni") {
                messages.append("authentic Middle Eastern chai")
            }
        }
        
        return messages.joined(separator: ", ")
    }
    
    private func completeOnboarding() {
        print("🔄 Starting taste onboarding completion...")
        isLoading = true
        
        // Save preferences to user profile
        Task {
            do {
                let success = await session.saveTasteProfile(
                    creaminess: Int(creaminess),
                    strength: Int(strength),
                    flavorNotes: Array(topNotes)
                )
                
                await MainActor.run {
                    isLoading = false
                    if success {
                        print("✅ Taste profile saved successfully, calling onDone")
                        onDone()
                    } else {
                        print("❌ Failed to save taste profile")
                        errorMessage = "Failed to save preferences. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ Error saving taste profile: \(error.localizedDescription)")
                    errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Preview
struct TasteOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        TasteOnboardingView(onDone: {})
            .environmentObject(SessionStore())
    }
}

