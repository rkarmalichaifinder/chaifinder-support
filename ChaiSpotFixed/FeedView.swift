import SwiftUI
import Firebase
import FirebaseFirestore

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var searchText = ""
    @State private var showingAddReview = false
    @State private var showingSearchSuggestions = false
    
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
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingAddReview) {
            // Add review sheet would go here
            Text("Add Review")
                .font(DesignSystem.Typography.titleLarge)
        }
        .onAppear {
            if viewModel.reviews.isEmpty {
                viewModel.refreshFeed()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Header with refresh button
            HStack {
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
                        .frame(width: 44, height: 44)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Refresh feed")
                .accessibilityHint("Double tap to refresh the feed")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Brand title
            Text("chai finder")
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("App title: chai finder")
            
            // Feed Type Toggle
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
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
                        viewModel.switchFeedType(to: newValue)
                    }
                }
            }
            
            // Search Bar
            searchBarSection
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.xs)
        .padding(.bottom, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.background)
        .iPadOptimized()
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 14))
                    .accessibilityHidden(true)
                
                TextField("Search friends' reviews & community posts...", text: $searchText)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .accessibilityLabel("Search reviews")
                    .accessibilityHint("Type to search through reviews")
                    .onChange(of: searchText) { newValue in
                        // Debounced search
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            await MainActor.run {
                                if searchText == newValue {
                                    viewModel.filterReviews(searchText)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        showingSearchSuggestions = true
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        withAnimation(DesignSystem.Animation.quick) {
                            searchText = ""
                            viewModel.filterReviews("")
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 14))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Double tap to clear search text")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.searchBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 0.5)
            )
            
            // Search suggestions
            if showingSearchSuggestions && searchText.isEmpty {
                searchSuggestionsView
            }
        }
    }
    
    // MARK: - Search Suggestions
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Popular searches")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.xs) {
                ForEach(["Masala Chai", "Cardamom", "Ginger", "Karak"], id: \.self) { suggestion in
                    Button(action: {
                        searchText = suggestion
                        viewModel.filterReviews(suggestion)
                        showingSearchSuggestions = false
                    }) {
                        Text(suggestion)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.primary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                    }
                    .accessibilityLabel("Search for \(suggestion)")
                }
            }
        }
        .padding(DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(color: DesignSystem.Shadows.small.color, radius: DesignSystem.Shadows.small.radius, x: DesignSystem.Shadows.small.x, y: DesignSystem.Shadows.small.y)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .zIndex(1) // Ensure suggestions appear above other content
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(viewModel.reviews) { review in
                    ReviewCardView(review: review)
                        .iPadCardStyle()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Load more indicator
                if viewModel.isLoading && !viewModel.reviews.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                }
                
                // End of feed indicator
                if !viewModel.reviews.isEmpty && !viewModel.isLoading {
                    HStack {
                        Text("You've reached the end")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.xs)
            .iPadOptimized()
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Preview
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
            .environmentObject(SessionStore())
    }
} 