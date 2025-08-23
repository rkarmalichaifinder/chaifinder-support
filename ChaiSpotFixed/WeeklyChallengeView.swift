import SwiftUI

struct WeeklyChallengeView: View {
    @StateObject private var challengeService = WeeklyChallengeService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if let challenge = challengeService.currentChallenge {
                        // Challenge Header
                        challengeHeader(challenge)
                        
                        // Progress Section
                        progressSection(challenge)
                        
                        // Challenge Details
                        challengeDetails(challenge)
                        
                        // Rewards Section
                        rewardsSection(challenge)
                        
                        // Time Remaining
                        timeRemainingSection(challenge)
                        
                    } else {
                        // No Active Challenge
                        noChallengeSection
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Weekly Challenge")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Challenge Header
    private func challengeHeader(_ challenge: WeeklyChallengeService.WeeklyChallenge) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Challenge Icon
            Image(systemName: challenge.type.icon)
                .font(.system(size: 60))
                .foregroundColor(Color(challenge.type.color))
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            // Challenge Title
            Text(challenge.title)
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Challenge Description
            Text(challenge.description)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(Color(challenge.type.color).opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Progress Section
    private func progressSection(_ challenge: WeeklyChallengeService.WeeklyChallenge) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Progress")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(challengeService.userProgress[challenge.type.rawValue] ?? 0)/\(challenge.target)")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            // Progress Bar
            ProgressView(value: challengeService.getProgressPercentage())
                .progressViewStyle(LinearProgressViewStyle(tint: Color(challenge.type.color)))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Progress Percentage
            Text("\(Int(challengeService.getProgressPercentage() * 100))% Complete")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Challenge Details
    private func challengeDetails(_ challenge: WeeklyChallengeService.WeeklyChallenge) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Challenge Details")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                DetailRow(
                    icon: challenge.type.icon,
                    title: "Type",
                    value: challenge.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    color: Color(challenge.type.color)
                )
                
                DetailRow(
                    icon: "target",
                    title: "Target",
                    value: "\(challenge.target)",
                    color: .orange
                )
                
                DetailRow(
                    icon: "calendar",
                    title: "Duration",
                    value: "7 days",
                    color: .blue
                )
                
                DetailRow(
                    icon: "star.fill",
                    title: "Difficulty",
                    value: getDifficultyText(for: challenge.target),
                    color: .purple
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Rewards Section
    private func rewardsSection(_ challenge: WeeklyChallengeService.WeeklyChallenge) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Rewards")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Points Reward
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.yellow)
                    
                    Text("\(challenge.reward)")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                    
                    Text("Points")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                
                // Badge Reward
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                    
                    Text("Challenge")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                    
                    Text("Badge")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Time Remaining Section
    private func timeRemainingSection(_ challenge: WeeklyChallengeService.WeeklyChallenge) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Time Remaining")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Days
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\(challengeService.getDaysRemaining())")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("Days")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                
                // Hours (estimated)
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\(challengeService.getDaysRemaining() * 24)")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Hours")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Urgency Message
            if challengeService.getDaysRemaining() <= 2 {
                Text("⏰ Time is running out! Complete this challenge soon!")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - No Challenge Section
    private var noChallengeSection: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Active Challenge")
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
            
            Text("Check back next week for a new challenge!")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                challengeService.loadCurrentChallenge()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.Spacing.xl)
    }
    
    // MARK: - Helper Functions
    
    private func getDifficultyText(for target: Int) -> String {
        switch target {
        case 1...3:
            return "Easy"
        case 4...6:
            return "Medium"
        case 7...10:
            return "Hard"
        default:
            return "Expert"
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

#Preview {
    WeeklyChallengeView()
}
