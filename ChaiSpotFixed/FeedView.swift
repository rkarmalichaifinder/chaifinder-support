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
        VStack(spacing: 8) {
            // Header with refresh button - more compact
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
                        .frame(width: 40, height: 40)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Refresh feed")
                .accessibilityHint("Double tap to refresh the feed")
            }

            // Brand title - more compact
            Text("chai finder")
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("App title: chai finder")
            
            // Feed Type Toggle - more compact
            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, 4)
        .padding(.bottom, 8)
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
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
            )
            
            // Search suggestions
            if showingSearchSuggestions && searchText.isEmpty {
                searchSuggestionsView
            }
        }
    }
    
    // MARK: - Search Suggestions
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Popular searches")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 12)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                ForEach(["Masala Chai", "Cardamom", "Ginger", "Karak"], id: \.self) { suggestion in
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, 8)
            .padding(.bottom, 16)
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