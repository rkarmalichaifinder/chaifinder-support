import SwiftUI
import Firebase
import FirebaseFirestore

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var searchText = ""
    @State private var showingAddReview = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // Breadcrumb / subtitle
                        Text("Home Page")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Brand title
                        Text("chai finder")
                            .font(DesignSystem.Typography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Feed Type Toggle
                        Picker("Feed Type", selection: $viewModel.currentFeedType) {
                            Text("Friends")
                                .tag(FeedType.friends)
                            Text("Community")
                                .tag(FeedType.community)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: viewModel.currentFeedType) { newValue in
                            viewModel.switchFeedType(to: newValue)
                        }
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
                            
                            TextField("Search for a chai spot, member, etc...", text: $searchText)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .onChange(of: searchText) { newValue in
                                    // Use proper async handling to avoid state modification during view updates
                                    Task {
                                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                        await MainActor.run {
                                            if searchText == newValue {
                                                viewModel.filterReviews(searchText)
                                            }
                                        }
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: { 
                                    searchText = ""
                                    viewModel.filterReviews("")
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.searchBackground)
                        .cornerRadius(DesignSystem.CornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.background)
                    .iPadOptimized()

                    // Section title
                    Text("YOUR FEED")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.sm)
                    
                    // Feed Content
                    if viewModel.isLoading {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(UIDevice.current.userInterfaceIdiom == .pad ? 1.5 : 1.2)
                            Text("Loading feed...")
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text("This may take a few seconds")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .opacity(0.7)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.error {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Spacer()
                            Image(systemName: viewModel.currentFeedType == .friends ? "person.2.slash" : "exclamationmark.triangle")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Text(error)
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            
                            if viewModel.currentFeedType == .friends {
                                Button(action: {
                                    viewModel.switchFeedType(to: .community)
                                }) {
                                    Text("View Community Feed")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, DesignSystem.Spacing.lg)
                                        .padding(.vertical, DesignSystem.Spacing.md)
                                        .background(DesignSystem.Colors.primary)
                                        .cornerRadius(DesignSystem.CornerRadius.medium)
                                }
                            } else {
                                Button(action: {
                                    viewModel.loadFeed()
                                }) {
                                    Text("Try Again")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, DesignSystem.Spacing.lg)
                                        .padding(.vertical, DesignSystem.Spacing.md)
                                        .background(DesignSystem.Colors.primary)
                                        .cornerRadius(DesignSystem.CornerRadius.medium)
                                }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredReviews.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Spacer()
                            Image(systemName: "cup.and.saucer")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48))
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text("No reviews yet")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Be the first to review a chai spot!")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showingAddReview = true
                            }) {
                                Text("Add Review")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, DesignSystem.Spacing.lg)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                    .background(DesignSystem.Colors.primary)
                                    .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.lg) {
                                ForEach(viewModel.filteredReviews) { review in
                                    ReviewCardView(review: review)
                                        .iPadCardStyle()
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddReview) {
                NavigationView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Text("Add Review")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Select a chai spot to review")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Go to Search") {
                            showingAddReview = false
                            // TODO: Navigate to search tab
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(DesignSystem.Spacing.xl)
                    .navigationTitle("Add Review")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                showingAddReview = false
                            }
                        }
                    }
                }
                .navigationViewStyle(.stack)
            }
        }
        .navigationViewStyle(.stack)
    }
} 