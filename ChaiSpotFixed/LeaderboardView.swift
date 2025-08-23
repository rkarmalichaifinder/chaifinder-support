import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedTimeframe: LeaderboardTimeframe = .month
    @State private var selectedCategory: LeaderboardCategory = .overall
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("Leaderboard")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.refreshLeaderboard()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(DesignSystem.Colors.primary)
                                .font(.system(size: 16))
                        }
                        .disabled(viewModel.isLoading)
                    }
                    
                    // Timeframe selector
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(LeaderboardTimeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.displayName).tag(timeframe)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedTimeframe) { newValue in
                        viewModel.switchTimeframe(to: newValue)
                    }
                    
                    // Category selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(LeaderboardCategory.allCases, id: \.self) { category in
                                CategoryFilterButton(
                                    title: category.displayName,
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
                
                // Leaderboard content
                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading leaderboard...")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.leaderboardEntries.isEmpty {
                    EmptyLeaderboardView()
                } else {
                    LeaderboardList(
                        entries: filteredLeaderboardEntries,
                        currentUserId: viewModel.currentUserId ?? ""
                    )
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.loadLeaderboard()
        }
    }
    
    private var filteredLeaderboardEntries: [LeaderboardEntry] {
        viewModel.leaderboardEntries.filter { entry in
            switch selectedCategory {
            case .overall:
                return true
            case .reviews:
                return entry.reviewCount > 0
            case .photos:
                return entry.photoCount > 0
            case .streaks:
                return entry.currentStreak > 0
            case .badges:
                return entry.badgeCount > 0
            }
        }
    }
}

// 🏆 Leaderboard Entry Model
struct LeaderboardEntry: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let photoURL: String?
    let totalScore: Int
    let reviewCount: Int
    let photoCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let badgeCount: Int
    let rank: Int
    
    // Computed properties for different scoring categories
    var reviewScore: Int { reviewCount * 10 }
    var photoScore: Int { photoCount * 15 }
    var streakScore: Int { currentStreak * 5 }
    var badgeScore: Int { badgeCount * 20 }
    
    var overallScore: Int {
        totalScore + reviewScore + photoScore + streakScore + badgeScore
    }
}

// 🕐 Leaderboard Timeframe
enum LeaderboardTimeframe: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    case allTime = "allTime"
    
    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

// 🎯 Leaderboard Category
enum LeaderboardCategory: String, CaseIterable {
    case overall = "overall"
    case reviews = "reviews"
    case photos = "photos"
    case streaks = "streaks"
    case badges = "badges"
    
    var displayName: String {
        switch self {
        case .overall: return "Overall"
        case .reviews: return "Reviews"
        case .photos: return "Photos"
        case .streaks: return "Streaks"
        case .badges: return "Badges"
        }
    }
}

// 🏷️ Category Filter Button
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.bodySmall)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.orange : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 🏆 Leaderboard List
struct LeaderboardList: View {
    let entries: [LeaderboardEntry]
    let currentUserId: String
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(entries) { entry in
                    LeaderboardEntryRow(
                        entry: entry,
                        isCurrentUser: entry.userId == currentUserId
                    )
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

// 🥇 Leaderboard Entry Row
struct LeaderboardEntryRow: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                Text("\(entry.rank)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Profile photo
            if let photoURL = entry.photoURL {
                AsyncImage(url: URL(string: photoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
            } else {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(entry.username.prefix(1)).uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    )
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.username)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUser ? .orange : .primary)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }
                
                // Stats
                HStack(spacing: 12) {
                    StatBadge(icon: "star.fill", value: entry.reviewCount, color: .blue)
                    StatBadge(icon: "camera.fill", value: entry.photoCount, color: .green)
                    StatBadge(icon: "flame.fill", value: entry.currentStreak, color: .orange)
                    StatBadge(icon: "medal.fill", value: entry.badgeCount, color: .purple)
                }
            }
            
            Spacer()
            
            // Score
            VStack(spacing: 4) {
                Text("\(entry.totalScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color.orange.opacity(0.05) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentUser ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .blue
        }
    }
}

// 📊 Stat Badge
struct StatBadge: View {
    let icon: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            Text("\(value)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// 🎯 Empty Leaderboard View
struct EmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Leaderboard Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start reviewing chai spots to appear on the leaderboard!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Rate a Spot") {
                // This would navigate to the rating flow
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// 🔧 Leaderboard ViewModel
class LeaderboardViewModel: ObservableObject {
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var currentTimeframe: LeaderboardTimeframe = .month
    
    let currentUserId = Auth.auth().currentUser?.uid
    private let db = Firestore.firestore()
    
    func loadLeaderboard() {
        isLoading = true
        
        // Load friends and their gamification data
        loadFriendsLeaderboard()
    }
    
    func refreshLeaderboard() {
        loadLeaderboard()
    }
    
    func switchTimeframe(to timeframe: LeaderboardTimeframe) {
        currentTimeframe = timeframe
        loadLeaderboard()
    }
    
    private func loadFriendsLeaderboard() {
        guard let userId = currentUserId else {
            isLoading = false
            return
        }
        
        // Get current user's friends
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self,
                  let document = document,
                  let data = document.data(),
                  let friends = data["friends"] as? [String] else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            // Add current user to the list
            var allUserIds = friends
            allUserIds.append(userId)
            
            // Load gamification data for all users
            self.loadUsersGamificationData(userIds: allUserIds)
        }
    }
    
    private func loadUsersGamificationData(userIds: [String]) {
        var entries: [LeaderboardEntry] = []
        let group = DispatchGroup()
        
        for userId in userIds {
            group.enter()
            
            db.collection("users").document(userId).getDocument { document, error in
                defer { group.leave() }
                
                if let document = document,
                   let data = document.data() {
                    let entry = LeaderboardEntry(
                        id: userId,
                        userId: userId,
                        username: data["displayName"] as? String ?? "Unknown User",
                        photoURL: data["photoURL"] as? String,
                        totalScore: data["totalScore"] as? Int ?? 0,
                        reviewCount: data["totalReviews"] as? Int ?? 0,
                        photoCount: 0, // Will be calculated from ratings
                        currentStreak: data["currentStreak"] as? Int ?? 0,
                        longestStreak: data["longestStreak"] as? Int ?? 0,
                        badgeCount: (data["badges"] as? [String])?.count ?? 0,
                        rank: 0 // Will be calculated after sorting
                    )
                    
                    entries.append(entry)
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            // Sort by total score and assign ranks
            let sortedEntries = entries.sorted { $0.totalScore > $1.totalScore }
            
            var rankedEntries: [LeaderboardEntry] = []
            for (index, entry) in sortedEntries.enumerated() {
                let rankedEntry = LeaderboardEntry(
                    id: entry.id,
                    userId: entry.userId,
                    username: entry.username,
                    photoURL: entry.photoURL,
                    totalScore: entry.totalScore,
                    reviewCount: entry.reviewCount,
                    photoCount: entry.photoCount,
                    currentStreak: entry.currentStreak,
                    longestStreak: entry.longestStreak,
                    badgeCount: entry.badgeCount,
                    rank: index + 1
                )
                rankedEntries.append(rankedEntry)
            }
            
            self?.leaderboardEntries = rankedEntries
            self?.isLoading = false
        }
    }
}

#Preview {
    LeaderboardView()
}
