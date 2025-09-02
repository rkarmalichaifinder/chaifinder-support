import SwiftUI
import Firebase
import FirebaseFirestore
import Combine

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var searchText = ""
    @State private var showingAddReview = false
    @State private var showingSearchSuggestions = false
    @State private var isReapplyingSearch = false
    @State private var persistSearchAcrossFeeds = true
    @FocusState private var isSearchFocused: Bool
    
    @EnvironmentObject var sessionStore: SessionStore
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Content
                    if viewModel.isLoading && viewModel.reviews.isEmpty {
                        LoadingView("Loading your feed...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.error, !viewModel.isLoading {
                        EmptyStateView(
                            icon: "exclamationmark.triangle.fill",
                            title: "Error",
                            message: error,
                            actionTitle: "Try Again",
                            action: { viewModel.refreshFeed() }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.reviews.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            icon: "cup.and.saucer.fill",
                            title: "No reviews yet",
                            message: viewModel.currentFeedType == .friends 
                                ? "When your friends start reviewing chai spots, they'll appear here."
                                : "Be the first to review a chai spot in your area!",
                            actionTitle: "Add a review",
                            action: { showingAddReview = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        feedContent
                    }
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                viewModel.refreshFeed()
            }
            .searchBarKeyboardDismissible()
            .onAppear {
                // Start listening for comprehensive notifications
                viewModel.startListeningForNotifications()
                
                if viewModel.feedItems.isEmpty && viewModel.reviews.isEmpty {
                    viewModel.refreshFeed()
                }
            }
            .onDisappear {
                // Stop listening for notifications when view disappears
                viewModel.stopListeningForNotifications()
                // 🆕 Cleanup search debouncing
                viewModel.cleanup()
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingAddReview) {
            // Add review sheet would go here
            Text("Add Review")
                .font(DesignSystem.Typography.titleLarge)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) { // Reduced spacing for more compact design
            HStack {
                // Brand title - consistent with other pages
                Text("chai finder")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .accessibilityLabel("App title: chai finder")
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    withAnimation(DesignSystem.Animation.standard) {
                        viewModel.refreshFeed()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(DesignSystem.Colors.primary)
                        .font(.system(size: 16))
                        .frame(width: 32, height: 32)
                }
                .frame(width: 32, height: 32)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Refresh feed")
                .accessibilityHint("Double tap to refresh the feed")
            }
            
            // Feed Type Toggle - more compact
            VStack(alignment: .leading, spacing: 2) { // Reduced from 4 to 2
                Text("Feed Type")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .accessibilityLabel("Feed type selector")
                
                Picker("Feed Type", selection: $viewModel.currentFeedType) {
                    Text("Friends")
                        .tag(FeedType.friends)
                        .accessibilityLabel("Show friends' reviews")
                    Text("Community")
                        .tag(FeedType.community)
                        .accessibilityLabel("Show community reviews")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: viewModel.currentFeedType) { newValue in
                    withAnimation(DesignSystem.Animation.standard) {
                        let previousFeedType = viewModel.currentFeedType
                        viewModel.switchFeedType(to: newValue)
                        
                        if persistSearchAcrossFeeds && !searchText.isEmpty {
                            // Handle search persistence when switching feed types
                            viewModel.handleFeedTypeChange(
                                previousFeedType: previousFeedType,
                                newFeedType: newValue,
                                currentSearchText: searchText
                            )
                            
                            // Show visual indicator if there's active search
                            isReapplyingSearch = true
                            // Hide indicator after search is complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isReapplyingSearch = false
                            }
                        } else if !persistSearchAcrossFeeds && !searchText.isEmpty {
                            // Clear search when switching feeds if persistence is disabled
                            searchText = ""
                            viewModel.filterReviews("")
                        }
                    }
                }
            }
            
            // Search Bar
            searchBarSection
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .iPadOptimized()
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: 14))
                    .accessibilityHidden(true)
                
                TextField("Search reviews, locations, cities, users...", text: $searchText)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search reviews")
                    .accessibilityHint("Type to search through reviews, locations, cities, and reviewers")
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        // 🆕 Use debounced search instead of immediate filtering
                        viewModel.filterReviews(newValue)
                    }
                    .onTapGesture {
                        isSearchFocused = true
                    }
                    .onSubmit {
                        // Keep focus when submitting to allow continued typing
                        // Don't dismiss keyboard
                    }
                    .submitLabel(.search)
                    .keyboardType(.default)
                    .textContentType(.none)

                
                if !searchText.isEmpty {
                    Button(action: { 
                        withAnimation(DesignSystem.Animation.quick) {
                            searchText = ""
                            viewModel.filterReviews("")
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Double tap to clear search text")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.searchBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(
                color: Color.black.opacity(0.04), // Very subtle shadow
                radius: 2,
                x: 0,
                y: 1
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1) // Reduced from 0.3 opacity and 0.5 lineWidth
            )
            
            // Search feedback
            if !searchText.isEmpty {
                searchFeedbackView
            }
            
            // Debug info (only show in development)
            #if DEBUG
            if !searchText.isEmpty {
                debugSearchInfoView
            }
            #endif
            
            // Debug search text info (always show for troubleshooting)

            

            
            // Search suggestions (temporarily disabled to test focus issue)
            // if showingSearchSuggestions && searchText.isEmpty {
            //     searchSuggestionsView
            // }
        }
    }
    
    // MARK: - Search Feedback View
    private var searchFeedbackView: some View {
        HStack {
            // 🆕 Enhanced search feedback with icons
            let feedback = viewModel.getSearchFeedback(for: searchText)
            
            Image(systemName: getSearchIcon(for: feedback.searchType))
                .foregroundColor(getSearchColor(for: feedback.searchType))
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(feedback.message)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if isReapplyingSearch {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Updating for \(viewModel.currentFeedType == .friends ? "Friends" : "Community") feed...")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
                
                if !searchText.isEmpty {
                    Text("Searching through \(viewModel.reviews.count) total reviews")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            if viewModel.filteredReviews.count > 0 {
                Text("Tap to clear")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.quick) {
                            searchText = ""
                            viewModel.filterReviews("")
                        }
                    }
                }
            }
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // 🆕 Helper functions for search feedback styling
    private func getSearchIcon(for searchType: SearchType) -> String {
        switch searchType {
        case .none:
            return "info.circle.fill"
        case .flavorNotes:
            return "leaf.fill"
        case .location:
            return "mappin.circle.fill"
        case .user:
            return "person.circle.fill"
        case .general:
            return "magnifyingglass.circle.fill"
        }
    }
    
    private func getSearchColor(for searchType: SearchType) -> Color {
        switch searchType {
        case .none:
            return DesignSystem.Colors.primary
        case .flavorNotes:
            return DesignSystem.Colors.flavorNotesRating
        case .location:
            return Color.blue
        case .user:
            return Color.green
        case .general:
            return DesignSystem.Colors.primary
        }
    }
    
    // MARK: - Debug Search Info View (Development Only)
    #if DEBUG
    private var debugSearchInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            let stats = viewModel.getSearchStats()
            
            Text("🔍 Debug Info")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, 4)
            
            Text("Total: \(stats["totalReviews"] as? Int ?? 0) | Loaded: \(stats["loadedReviews"] as? Int ?? 0) | Loading: \(stats["loadingReviews"] as? Int ?? 0)")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 4)
            
            Text("Cache: \(stats["cacheSize"] as? Int ?? 0) | Search Ready: \(stats["searchReady"] as? Bool ?? false ? "Yes" : "No")")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 4)
            
            if !(stats["searchReady"] as? Bool ?? false) {
                Button("🔄 Force Refresh Spot Details") {
                    viewModel.forceRefreshSpotDetails()
                }
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, 4)
            }
            
            // Debug search state
            Button("🔍 Debug Search State") {
                let stats = viewModel.getSearchStats()
                print("🔍 DEBUG: Total reviews: \(stats["totalReviews"] ?? 0)")
                print("🔍 DEBUG: Filtered reviews: \(stats["filteredReviewsCount"] ?? 0)")
                print("🔍 DEBUG: Reviews IDs: \(stats["reviewsArrayIds"] ?? [])")
                print("🔍 DEBUG: Filtered IDs: \(stats["filteredReviewsArrayIds"] ?? [])")
                print("🔍 DEBUG: Current searchText: '\(searchText)'")
                print("🔍 DEBUG: searchText.isEmpty: \(searchText.isEmpty)")
            }
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, 4)
            
            // Test search functionality
            Button("🧪 Test Search") {
                viewModel.testSearch()
            }
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, 4)
            
            // Test UI update
            Button("🧪 Test UI Update") {
                viewModel.testUIUpdate()
            }
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, 4)
            
            // Test manual search
            Button("🔍 Test Search 'KGF'") {
                searchText = "KGF"
                viewModel.filterReviews("KGF")
            }
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, 4)
            
            // Search persistence toggle
            HStack {
                Text("Persist search across feeds:")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Toggle("", isOn: $persistSearchAcrossFeeds)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    #endif
    
    // MARK: - Search Suggestions
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search by category")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 12)
            
            // Location-based suggestions
            VStack(alignment: .leading, spacing: 6) {
                Text("📍 Locations & Cities")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 6) {
                    ForEach(["San Francisco", "Downtown", "Mission", "North Beach"], id: \.self) { suggestion in
                        Button(action: {
                            searchText = suggestion
                            viewModel.filterReviews(suggestion)
                            showingSearchSuggestions = false
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .font(.system(size: 12))
                                Text(suggestion)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.searchBackground)
                            .cornerRadius(8)
                            .shadow(
                                color: Color.black.opacity(0.03),
                                radius: 1,
                                x: 0,
                                y: 0.5
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Chai type suggestions
            VStack(alignment: .leading, spacing: 6) {
                Text("☕ Chai Types")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                    ForEach(["Masala Chai", "Karak", "Cardamom", "Ginger", "Saffron"], id: \.self) { suggestion in
                        Button(action: {
                            searchText = suggestion
                            viewModel.filterReviews(suggestion)
                            showingSearchSuggestions = false
                        }) {
                            Text(suggestion)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DesignSystem.Colors.searchBackground)
                                .cornerRadius(8)
                                .shadow(
                                    color: Color.black.opacity(0.03),
                                    radius: 1,
                                    x: 0,
                                    y: 0.5
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Search tips
            VStack(alignment: .leading, spacing: 4) {
                Text("💡 Search tips")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 12)
                
                Text("• Try searching by city name (e.g., 'San Francisco')")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 12)
                
                Text("• Search by neighborhood (e.g., 'Mission', 'Downtown')")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 12)
                
                Text("• Find reviews by reviewer name")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // 🆕 Show comprehensive feed items first
                ForEach(Array(viewModel.filteredFeedItems.enumerated()), id: \.element.id) { _, item in
                    FeedItemCardView(item: item) {
                        handleFeedItemTap(item)
                    }
                    .iPadCardStyle()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Use filteredReviews when searching, otherwise use all reviews
                let reviewsToShow = searchText.isEmpty ? viewModel.reviews : viewModel.filteredReviews
                
                // Debug header (development only)
                #if DEBUG
                if !searchText.isEmpty {
                    HStack {
                        Text("🔍 Search Results")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                        
                        Spacer()
                        
                        Text("\(reviewsToShow.count) results")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                #endif
                
                if reviewsToShow.isEmpty && !searchText.isEmpty {
                    // No search results found
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("No results found")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Try adjusting your search terms or browse all reviews")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Clear Search") {
                            withAnimation(DesignSystem.Animation.quick) {
                                searchText = ""
                                viewModel.filterReviews("")
                            }
                        }
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Show reviews
                    ForEach(reviewsToShow) { review in
                        ReviewCardView(review: review)
                            .iPadCardStyle()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .environmentObject(sessionStore)
                    }
                }
                
                // Load more indicator (only show when not searching)
                if viewModel.isLoading && !viewModel.reviews.isEmpty && searchText.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, 2) // Reduced from 8 to 2
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Feed Item Tap Handler
    private func handleFeedItemTap(_ item: any FeedItem) {
        // Note: We can't modify item.isRead directly since it's a let constant
        // The read status should be handled by the view model when processing the tap
        
        // Handle different item types
        switch item.type {
        case .review:
            if let reviewItem = item as? ReviewFeedItem {
                // TODO: Navigate to review detail
                print("📱 Tapped review: \(reviewItem.spotName)")
            }
        case .newUser:
            if let userItem = item as? NewUserFeedItem {
                // TODO: Navigate to user profile or show add friend option
                print("📱 Tapped new user: \(userItem.username)")
            }
        case .newSpot:
            if let spotItem = item as? NewSpotFeedItem {
                // TODO: Navigate to spot detail
                print("📱 Tapped new spot: \(spotItem.spotName)")
            }
        case .achievement:
            if let achievementItem = item as? AchievementFeedItem {
                // TODO: Navigate to achievement detail
                print("📱 Tapped achievement: \(achievementItem.achievementName)")
            }
        case .friendActivity:
            if let activityItem = item as? FriendActivityFeedItem {
                // TODO: Navigate to activity detail
                print("📱 Tapped friend activity: \(activityItem.activityDescription)")
            }
        case .weeklyChallenge:
            if let challengeItem = item as? WeeklyChallengeFeedItem {
                // TODO: Navigate to challenge detail
                print("📱 Tapped weekly challenge: \(challengeItem.challengeName)")
            }
        case .weeklyRanking:
            if let rankingItem = item as? WeeklyRankingFeedItem {
                // TODO: Navigate to ranking detail
                print("📱 Tapped weekly ranking")
            }
        }
    }
}

// MARK: - Preview
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
            .environmentObject(SessionStore())
    }
} 