import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChaiJourneyView: View {
    @StateObject private var viewModel = ChaiJourneyViewModel()
    @State private var selectedTimeframe: JourneyTimeframe = .allTime
    @State private var showingSpotDetail = false
    @State private var selectedSpot: ChaiSpot?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("Your Chai Journey")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.refreshJourney()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(DesignSystem.Colors.primary)
                                .font(.system(size: 16))
                        }
                        .disabled(viewModel.isLoading)
                    }
                    
                    // Timeframe selector
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(JourneyTimeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.displayName).tag(timeframe)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedTimeframe) { newValue in
                        viewModel.switchTimeframe(to: newValue)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.background)
                
                // Journey content
                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your journey...")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.journeyEntries.isEmpty {
                    EmptyJourneyView()
                } else {
                    JourneyContent(
                        entries: viewModel.journeyEntries,
                        onSpotTap: { spot in
                            selectedSpot = spot
                            showingSpotDetail = true
                        }
                    )
                }
            }
            .navigationTitle("Chai Journey")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingSpotDetail) {
            if let spot = selectedSpot {
                SpotDetailView(spot: spot)
            }
        }
        .onAppear {
            viewModel.loadJourney()
        }
    }
}

// 🕐 Journey Timeframe
enum JourneyTimeframe: String, CaseIterable {
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

// 🗺️ Journey Entry
struct JourneyEntry: Identifiable {
    let id: String
    let spot: ChaiSpot
    let rating: Rating
    let timestamp: Date
    let isFirstVisit: Bool
    let isPhotoIncluded: Bool
    let gamificationScore: Int
    let badgesEarned: [String]
    let achievementsEarned: [String]
    
    // Computed properties
    var dayOfYear: Int {
        let calendar = Calendar.current
        return calendar.ordinality(of: .day, in: .year, for: timestamp) ?? 0
    }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: timestamp)
    }
    
    var year: Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: timestamp)
    }
}

// 🎯 Journey Content
struct JourneyContent: View {
    let entries: [JourneyEntry]
    let onSpotTap: (ChaiSpot) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Journey summary
                JourneySummaryView(entries: entries)
                
                // Timeline
                JourneyTimelineView(entries: entries, onSpotTap: onSpotTap)
                
                // Stats and insights
                JourneyInsightsView(entries: entries)
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

// 📊 Journey Summary
struct JourneySummaryView: View {
    let entries: [JourneyEntry]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Journey Summary")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                SummaryCard(
                    title: "Spots Visited",
                    value: "\(entries.count)",
                    icon: "map.fill",
                    color: .blue
                )
                
                SummaryCard(
                    title: "Photos Shared",
                    value: "\(entries.filter { $0.isPhotoIncluded }.count)",
                    icon: "camera.fill",
                    color: .green
                )
                
                SummaryCard(
                    title: "Total Score",
                    value: "\(entries.reduce(0) { $0 + $1.gamificationScore })",
                    icon: "star.fill",
                    color: .orange
                )
                
                SummaryCard(
                    title: "New Spots",
                    value: "\(entries.filter { $0.isFirstVisit }.count)",
                    icon: "sparkles",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// 📊 Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// 🕐 Journey Timeline
struct JourneyTimelineView: View {
    let entries: [JourneyEntry]
    let onSpotTap: (ChaiSpot) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Journey Timeline")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVStack(spacing: 16) {
                ForEach(entries.sorted { $0.timestamp > $1.timestamp }) { entry in
                    TimelineEntryView(entry: entry, onSpotTap: onSpotTap)
                }
            }
        }
    }
}

// 🕐 Timeline Entry
struct TimelineEntryView: View {
    let entry: JourneyEntry
    let onSpotTap: (ChaiSpot) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Timeline connector
            VStack(spacing: 0) {
                Circle()
                    .fill(timelineColor)
                    .frame(width: 12, height: 12)
                
                if entry.id != "last" { // Don't show line for last entry
                    Rectangle()
                        .fill(timelineColor.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }
            
            // Entry content
            VStack(spacing: 12) {
                // Date header
                HStack {
                    Text(entry.timestamp.formatted(.relative(presentation: .named)))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if entry.isFirstVisit {
                        Text("🆕 New Spot")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Spot info
                Button(action: {
                    onSpotTap(entry.spot)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.spot.name)
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(entry.spot.address)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(entry.rating.value)★")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                            
                            if entry.isPhotoIncluded {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Rating details
                if let comment = entry.rating.comment, !comment.isEmpty {
                    Text(comment)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Gamification info
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("+\(entry.gamificationScore) pts")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    
                    if !entry.badgesEarned.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "medal.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text("\(entry.badgesEarned.count) badge(s)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(timelineColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var timelineColor: Color {
        if entry.isFirstVisit {
            return .green
        } else if entry.isPhotoIncluded {
            return .blue
        } else {
            return .orange
        }
    }
}

// 💡 Journey Insights
struct JourneyInsightsView: View {
    let entries: [JourneyEntry]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Journey Insights")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                InsightRow(
                    icon: "calendar",
                    title: "Most Active Month",
                    value: mostActiveMonth,
                    color: .blue
                )
                
                InsightRow(
                    icon: "star.fill",
                    title: "Highest Rated Spot",
                    value: highestRatedSpot,
                    color: .orange
                )
                
                InsightRow(
                    icon: "camera.fill",
                    title: "Photo Enthusiast",
                    value: photoEnthusiasm,
                    color: .green
                )
                
                InsightRow(
                    icon: "sparkles",
                    title: "Exploration Level",
                    value: explorationLevel,
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // Computed insights
    private var mostActiveMonth: String {
        let monthCounts = Dictionary(grouping: entries, by: { $0.monthName })
        let mostActive = monthCounts.max(by: { $0.value.count < $1.value.count })
        return mostActive?.key ?? "N/A"
    }
    
    private var highestRatedSpot: String {
        let highest = entries.max(by: { $0.rating.value < $1.rating.value })
        return highest?.spot.name ?? "N/A"
    }
    
    private var photoEnthusiasm: String {
        let photoCount = entries.filter { $0.isPhotoIncluded }.count
        let percentage = Double(photoCount) / Double(entries.count) * 100
        return "\(Int(percentage))% of reviews"
    }
    
    private var explorationLevel: String {
        let newSpots = entries.filter { $0.isFirstVisit }.count
        let totalSpots = entries.count
        let percentage = Double(newSpots) / Double(totalSpots) * 100
        
        if percentage >= 80 {
            return "Adventurer"
        } else if percentage >= 60 {
            return "Explorer"
        } else if percentage >= 40 {
            return "Regular"
        } else {
            return "Homebody"
        }
    }
}

// 💡 Insight Row
struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// 🎯 Empty Journey View
struct EmptyJourneyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Journey Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start rating chai spots to begin your journey!")
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

// 🏪 Spot Detail View
struct SpotDetailView: View {
    let spot: ChaiSpot
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(spot.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(spot.address)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Spot Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 🔧 Journey ViewModel
class ChaiJourneyViewModel: ObservableObject {
    @Published var journeyEntries: [JourneyEntry] = []
    @Published var isLoading = false
    @Published var currentTimeframe: JourneyTimeframe = .allTime
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    func loadJourney() {
        guard let userId = auth.currentUser?.uid else { return }
        
        isLoading = true
        
        Task {
            let entries = await loadUserJourney(userId: userId)
            
            await MainActor.run {
                self.journeyEntries = entries
                self.isLoading = false
            }
        }
    }
    
    func refreshJourney() {
        loadJourney()
    }
    
    func switchTimeframe(to timeframe: JourneyTimeframe) {
        currentTimeframe = timeframe
        loadJourney()
    }
    
    private func loadUserJourney(userId: String) async -> [JourneyEntry] {
        var entries: [JourneyEntry] = []
        
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            for document in snapshot.documents {
                let data = document.data()
                guard let spotId = data["spotId"] as? String else { continue }
                
                // Extract rating data manually
                let userId = data["userId"] as? String ?? ""
                let username = data["username"] as? String ?? "Anonymous"
                let value = data["value"] as? Int ?? 0
                let comment = data["comment"] as? String
                let timestamp = data["timestamp"] as? Timestamp
                let chaiType = data["chaiType"] as? String
                let creaminessRating = data["creaminessRating"] as? Int
                let chaiStrengthRating = data["chaiStrengthRating"] as? Int
                let flavorNotes = data["flavorNotes"] as? [String]
                let photoURL = data["photoURL"] as? String
                let hasPhoto = data["hasPhoto"] as? Bool ?? false
                let gamificationScore = data["gamificationScore"] as? Int ?? 0
                let isFirstReview = data["isFirstReview"] as? Bool ?? false
                let isNewSpot = data["isNewSpot"] as? Bool ?? false
                
                let rating = Rating(
                    id: document.documentID,
                    spotId: spotId,
                    userId: userId,
                    username: username,
                    spotName: nil,
                    value: value,
                    comment: comment,
                    timestamp: timestamp?.dateValue(),
                    likes: nil,
                    dislikes: nil,
                    creaminessRating: creaminessRating,
                    chaiStrengthRating: chaiStrengthRating,
                    flavorNotes: flavorNotes,
                    chaiType: chaiType,
                    photoURL: photoURL,
                    hasPhoto: hasPhoto,
                    reactions: [:],
                    isStreakReview: false,
                    gamificationScore: gamificationScore,
                    isFirstReview: isFirstReview,
                    isNewSpot: isNewSpot
                )
                
                // Get spot details
                let spot = await getSpotDetails(spotId: spotId)
                
                if let spot = spot {
                    let entry = JourneyEntry(
                        id: document.documentID,
                        spot: spot,
                        rating: rating,
                        timestamp: rating.timestamp ?? Date(),
                        isFirstVisit: rating.isNewSpot,
                        isPhotoIncluded: rating.hasPhoto,
                        gamificationScore: rating.gamificationScore,
                        badgesEarned: [], // Would be populated from gamification service
                        achievementsEarned: [] // Would be populated from gamification service
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error loading journey: \(error)")
        }
        
        return entries
    }
    
    private func getSpotDetails(spotId: String) async -> ChaiSpot? {
        // Try both collections - chaiFinder and chaiSpots
        let collections = ["chaiFinder", "chaiSpots"]
        
        for collectionName in collections {
            do {
                let document = try await db.collection(collectionName).document(spotId).getDocument()
                guard let data = document.data() else { continue }
                
                let id = data["id"] as? String ?? spotId
                let name = data["name"] as? String ?? "Chai Spot #\(spotId.prefix(6))"
                let address = data["address"] as? String ?? "Unknown Address"
                let latitude = data["latitude"] as? Double ?? 0.0
                let longitude = data["longitude"] as? Double ?? 0.0
                let chaiTypes = data["chaiTypes"] as? [String] ?? []
                let averageRating = data["averageRating"] as? Double ?? 0.0
                let ratingCount = data["ratingCount"] as? Int ?? 0
                
                return ChaiSpot(
                    id: id,
                    name: name,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    chaiTypes: chaiTypes,
                    averageRating: averageRating,
                    ratingCount: ratingCount
                )
            } catch {
                print("Error fetching spot details from \(collectionName): \(error)")
                continue
            }
        }
        
        // If all collections failed, return a fallback spot
        return ChaiSpot(
            id: spotId,
            name: "Chai Spot #\(spotId.prefix(6))",
            address: "Location details unavailable",
            latitude: 0.0,
            longitude: 0.0,
            chaiTypes: [],
            averageRating: 0.0,
            ratingCount: 0
        )
    }
}

#Preview {
    ChaiJourneyView()
}
