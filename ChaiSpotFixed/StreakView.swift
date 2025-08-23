import SwiftUI

struct StreakView: View {
    let currentStreak: Int
    let longestStreak: Int
    let lastReviewDate: Date?
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Streak Header
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Chai Streak")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Current Streak Display
            HStack(spacing: 20) {
                // Current Streak
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.orange, lineWidth: 3)
                            )
                        
                        VStack(spacing: 2) {
                            Text("\(currentStreak)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                            
                            Text("days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text("Current")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                // Longest Streak
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.purple, lineWidth: 3)
                            )
                        
                        VStack(spacing: 2) {
                            Text("\(longestStreak)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                            
                            Text("days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Longest")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Streak Status
            VStack(spacing: 12) {
                if currentStreak > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        
                        Text(streakStatusText)
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        Text("Start your streak today!")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
                }
                
                // Last Review Info
                if let lastReview = lastReviewDate {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("Last review: \(lastReview.formatted(.relative(presentation: .named)))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Streak Milestones
            if currentStreak > 0 {
                VStack(spacing: 12) {
                    HStack {
                        Text("Next Milestones")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(streakMilestones, id: \.self) { milestone in
                            MilestoneBadge(
                                milestone: milestone,
                                isAchieved: currentStreak >= milestone,
                                isNext: currentStreak < milestone && currentStreak >= milestone - 3
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            if currentStreak > 0 {
                isAnimating = true
            }
        }
    }
    
    private var streakStatusText: String {
        if currentStreak >= 30 {
            return "🔥 Month Master! Incredible dedication!"
        } else if currentStreak >= 21 {
            return "🔥 Three weeks strong! You're on fire!"
        } else if currentStreak >= 14 {
            return "🔥 Two weeks! Keep the momentum going!"
        } else if currentStreak >= 7 {
            return "🔥 Week warrior! Great consistency!"
        } else if currentStreak >= 3 {
            return "🔥 Getting started! Nice beginning!"
        } else {
            return "🔥 First day! Let's build this streak!"
        }
    }
    
    private var streakMilestones: [Int] {
        [3, 7, 14, 21, 30, 50, 100]
    }
}

// 🏆 Milestone Badge Component
struct MilestoneBadge: View {
    let milestone: Int
    let isAchieved: Bool
    let isNext: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 2)
                    )
                
                if isAchieved {
                    Image(systemName: "checkmark.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Text("\(milestone)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                }
            }
            
            Text("\(milestone)d")
                .font(.caption2)
                .foregroundColor(textColor)
        }
        .scaleEffect(isNext ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isNext)
    }
    
    private var badgeColor: Color {
        if isAchieved {
            return .green
        } else if isNext {
            return .orange
        }
        return .gray.opacity(0.3)
    }
    
    private var borderColor: Color {
        if isAchieved {
            return .green
        } else if isNext {
            return .orange
        }
        return .gray.opacity(0.5)
    }
    
    private var textColor: Color {
        if isAchieved {
            return .white
        } else if isNext {
            return .orange
        }
        return .secondary
    }
}

// 🔥 Streak Counter Component (for use in other views)
struct StreakCounter: View {
    let streak: Int
    let size: StreakSize
    
    enum StreakSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }
        
        var textSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 14
            case .large: return 16
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: size.iconSize))
                .foregroundColor(.orange)
            
            Text("\(streak)")
                .font(.system(size: size.textSize, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakView(currentStreak: 7, longestStreak: 15, lastReviewDate: Date())
        StreakView(currentStreak: 0, longestStreak: 0, lastReviewDate: nil)
        StreakCounter(streak: 7, size: .medium)
    }
    .padding()
}

