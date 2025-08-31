import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FriendDetailView: View {
    let friend: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var friendFriends: [UserProfile] = []
    @State private var friendRatings: [Rating] = []
    @State private var loadingFriends = true
    @State private var loadingRatings = true
    @State private var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Profile Header
                        profileHeader
                        
                        // Bio Section
                        if let bio = friend.bio, !bio.isEmpty {
                            bioSection(bio)
                        } else {
                            // Show placeholder when bio is missing
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Bio")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text("No bio available")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(DesignSystem.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignSystem.Colors.secondary.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.small)
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
                        
                        // Friends Section
                        friendsSection
                        
                        // Rated Places Section
                        ratedPlacesSection
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadFriendData()
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Profile Image
            let initials = friend.displayName
                .split(separator: " ")
                .compactMap { $0.first }
                .prefix(2)
                .map { String($0) }
                .joined()
            
            Text(initials.uppercased())
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(DesignSystem.Colors.primary)
                .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(friend.displayName)
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(friend.email)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
    
    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Bio")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(bio)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.secondary.opacity(0.05))
                .cornerRadius(DesignSystem.CornerRadius.small)
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
    
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Friends")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if loadingFriends {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(friendFriends.count)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            if loadingFriends {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(DesignSystem.Spacing.lg)
            } else if friendFriends.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "person.2")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Text("No friends yet")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.lg)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(friendFriends.prefix(5)) { friend in
                        friendRow(friend)
                    }
                    
                    if friendFriends.count > 5 {
                        Text("And \(friendFriends.count - 5) more...")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.top, DesignSystem.Spacing.sm)
                    }
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
    
    private func friendRow(_ friend: UserProfile) -> some View {
        HStack {
            // Profile Image
            let initials = friend.displayName
                .split(separator: " ")
                .compactMap { $0.first }
                .prefix(2)
                .map { String($0) }
                .joined()
            
            Text(initials.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(DesignSystem.Colors.primary)
                .clipShape(Circle())
            
            Text(friend.displayName)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    private var ratedPlacesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Rated Places")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if loadingRatings {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(friendRatings.count)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            if loadingRatings {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(DesignSystem.Spacing.lg)
            } else if friendRatings.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "star")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Text("No ratings yet")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.lg)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(friendRatings.prefix(5)) { rating in
                        ratingRow(rating)
                    }
                    
                    if friendRatings.count > 5 {
                        Text("And \(friendRatings.count - 5) more...")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.top, DesignSystem.Spacing.sm)
                    }
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
    
    private func ratingRow(_ rating: Rating) -> some View {
        HStack {
            // Rating display
            Text("\(rating.value)★")
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignSystem.Colors.ratingGreen)
                .cornerRadius(DesignSystem.CornerRadius.small)
            
            VStack(alignment: .leading, spacing: 2) {
                if let spotName = rating.spotName, !spotName.isEmpty {
                    Text(spotName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                } else {
                    HStack(spacing: 4) {
                        Text("Chai Spot")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("#\(rating.spotId.prefix(6))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                if let comment = rating.comment, !comment.isEmpty {
                    Text(comment)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    private func loadFriendData() {
        loadFriendFriends()
        loadFriendRatings()
    }
    
    private func loadFriendFriends() {
        guard let friendIds = friend.friends, !friendIds.isEmpty else {
            DispatchQueue.main.async {
                self.friendFriends = []
                self.loadingFriends = false
            }
            return
        }
        
        let group = DispatchGroup()
        var loadedFriends: [UserProfile] = []
        
        for friendId in friendIds {
            group.enter()
            db.collection("users").document(friendId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error loading friend's friend \(friendId): \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("❌ No data found for friend's friend \(friendId)")
                    return
                }
                
                let friendProfile = UserProfile(
                    id: snapshot?.documentID,
                    uid: data["uid"] as? String ?? friendId,
                    displayName: data["displayName"] as? String ?? "Unknown User",
                    email: data["email"] as? String ?? "unknown",
                    photoURL: data["photoURL"] as? String,
                    friends: data["friends"] as? [String] ?? [],
                    incomingRequests: data["incomingRequests"] as? [String] ?? [],
                    outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                    bio: data["bio"] as? String
                )
                
                loadedFriends.append(friendProfile)
            }
        }
        
        group.notify(queue: .main) {
            self.friendFriends = loadedFriends.sorted { $0.displayName < $1.displayName }
            self.loadingFriends = false
            print("✅ Loaded \(self.friendFriends.count) friends for \(self.friend.displayName)")
        }
    }
    
    private func loadFriendRatings() {
        db.collection("ratings")
            .whereField("userId", isEqualTo: friend.uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading friend's ratings: \(error.localizedDescription)")
                        self.friendRatings = []
                        self.loadingRatings = false
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.friendRatings = []
                        self.loadingRatings = false
                        return
                    }
                    
                    let ratings = documents.compactMap { doc -> Rating? in
                        let data = doc.data()
                        let spotId = data["spotId"] as? String ?? ""
                        let userId = data["userId"] as? String ?? ""
                        let username = data["username"] as? String ?? data["userName"] as? String
                        let spotName = data["spotName"] as? String
                        let ratingValue = data["rating"] as? Int ?? 0
                        let comment = data["comment"] as? String
                        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
                        let likes = data["likes"] as? Int ?? 0
                        let dislikes = data["dislikes"] as? Int ?? 0
                        let creaminessRating = data["creaminessRating"] as? Int
                        let chaiStrengthRating = data["chaiStrengthRating"] as? Int
                        let flavorNotes = data["flavorNotes"] as? [String]
                        
                        if let storedName = spotName {
                            print("✅ FriendDetailView: Rating for spot \(spotId) has stored name: \(storedName)")
                        } else {
                            print("⚠️ FriendDetailView: Rating for spot \(spotId) missing stored name")
                        }
                        
                        return Rating(
                            id: doc.documentID,
                            spotId: spotId,
                            userId: userId,
                            username: username,
                            spotName: spotName,
                            value: ratingValue,
                            comment: comment,
                            timestamp: timestamp,
                            likes: likes,
                            dislikes: dislikes,
                            creaminessRating: creaminessRating,
                            chaiStrengthRating: chaiStrengthRating,
                            flavorNotes: flavorNotes
                        )
                    }
                    
                    self.friendRatings = ratings
                    self.loadingRatings = false
                    print("✅ Loaded \(self.friendRatings.count) ratings for \(self.friend.displayName)")
                    
                    // Now fetch the actual chai spot names for ratings that don't have them
                    self.fetchMissingChaiSpotNames()
                }
            }
    }
    
    private func fetchMissingChaiSpotNames() {
        let ratingsWithoutNames = friendRatings.filter { $0.spotName == nil }
        
        if ratingsWithoutNames.isEmpty {
            print("✅ All ratings already have spot names")
            return
        }
        
        print("🔍 Fetching missing chai spot names for \(ratingsWithoutNames.count) ratings")
        
        let group = DispatchGroup()
        var updatedRatings = friendRatings
        
        for (index, rating) in ratingsWithoutNames.enumerated() {
            group.enter()
            
            db.collection("chaiFinder").document(rating.spotId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error fetching chai spot \(rating.spotId): \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let spotName = data["name"] as? String else {
                    print("⚠️ No name found for chai spot \(rating.spotId)")
                    return
                }
                
                print("✅ Found chai spot name: \(spotName) for ID: \(rating.spotId)")
                
                // Update the rating with the actual spot name
                updatedRatings[index].spotName = spotName
            }
        }
        
        group.notify(queue: .main) {
            self.friendRatings = updatedRatings
            print("✅ Updated \(self.friendRatings.count) ratings with actual chai spot names")
        }
    }
} 