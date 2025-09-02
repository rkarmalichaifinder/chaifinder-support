import SwiftUI

struct BadgeCollectionView: View {
    @ObservedObject var gamificationService: GamificationService
    @State private var selectedBadge: Badge?
    @State private var showingBadgeDetail = false
    @State private var selectedCategory: Badge.BadgeCategory? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Badges")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(gamificationService.userBadges.count)/\(GamificationService.availableBadges.count)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach(Badge.BadgeCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.rawValue,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .iPadOptimized()
            
            // Badges grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(filteredBadges, id: \.id) { badge in
                        BadgeCard(
                            badge: badge,
                            isUnlocked: gamificationService.userBadges.contains { $0.id == badge.id },
                            onTap: {
                                selectedBadge = badge
                                showingBadgeDetail = true
                            }
                        )
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
        }
        .sheet(isPresented: $showingBadgeDetail) {
            if let badge = selectedBadge {
                BadgeDetailView(badge: badge, isUnlocked: gamificationService.userBadges.contains { $0.id == badge.id })
            }
        }
    }
    
    private var filteredBadges: [Badge] {
        if let category = selectedCategory {
            return GamificationService.availableBadges.filter { $0.category == category }
        }
        return GamificationService.availableBadges
    }
}

// MARK: - Badge Color Helper
extension Badge {
    func backgroundColor(for isUnlocked: Bool) -> Color {
        if isUnlocked {
            switch rarity {
            case .common: return .yellow
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .yellow
            }
        } else {
            return Color(.systemGray5)
        }
    }
}

// 🎖️ Badge Card Component
struct BadgeCard: View {
    let badge: Badge
    let isUnlocked: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Badge Icon
                ZStack {
                    Circle()
                        .fill(badgeBackgroundColor)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: badge.iconName)
                        .font(.system(size: 30))
                        .foregroundColor(isUnlocked ? .white : .gray)
                    
                    // Checkmark overlay for earned badges
                    if isUnlocked {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .frame(width: 60, height: 60)
                    }
                }
                
                // Badge Info
                VStack(spacing: 4) {
                    Text(badge.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(badge.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(badgeBorderColor, lineWidth: isUnlocked ? 2 : 1)
            )
            .shadow(
                color: isUnlocked ? badgeBackgroundColor.opacity(0.3) : Color.black.opacity(0.05),
                radius: isUnlocked ? 4 : 2,
                x: 0,
                y: isUnlocked ? 2 : 1
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var badgeBackgroundColor: Color {
        return badge.backgroundColor(for: isUnlocked)
    }
    
    private var badgeBorderColor: Color {
        if isUnlocked {
            return badgeBackgroundColor.opacity(0.8)
        } else {
            return Color(.systemGray4)
        }
    }
}

// 🎖️ Badge Detail View
struct BadgeDetailView: View {
    let badge: Badge
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Badge Icon
            ZStack {
                Circle()
                    .fill(badgeBackgroundColor)
                    .frame(width: 120, height: 120)
                
                Image(systemName: badge.iconName)
                    .font(.system(size: 60))
                    .foregroundColor(isUnlocked ? .white : .gray)
                
                // Checkmark overlay for earned badges
                if isUnlocked {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .frame(width: 120, height: 120)
                }
            }
            
            // Badge Info
            VStack(spacing: 12) {
                Text(badge.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(badge.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if isUnlocked {
                    Text("Unlocked!")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(20)
                } else {
                    Text("Requirement: \(badge.requirement)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(.systemBackground))
    }
    
    private var badgeBackgroundColor: Color {
        return badge.backgroundColor(for: isUnlocked)
    }
}

#Preview {
    BadgeCollectionView(gamificationService: GamificationService())
}
