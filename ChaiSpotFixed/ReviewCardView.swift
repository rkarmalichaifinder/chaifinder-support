import SwiftUI

struct ReviewCardView: View {
    let review: ReviewFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                // Profile Icon
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(review.username.prefix(1)).uppercased())
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(review.username)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(review.timestamp, style: .relative)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Rating
                Text("\(review.rating)★")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.ratingGreen)
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }
            
            // Spot Information
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(review.spotName)
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(review.spotAddress)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Chai Type
            if let chaiType = review.chaiType, !chaiType.isEmpty {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .font(.caption)
                    
                    Text(chaiType)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            // Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.secondary.opacity(0.05))
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }
            
            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    // Like action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption)
                        Text("Like")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Button(action: {
                    // Comment action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.caption)
                        Text("Comment")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    // Share action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                        Text("Share")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
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
} 