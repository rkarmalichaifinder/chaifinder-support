import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("Feed")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .font(.system(size: 16))
                            
                            TextField("Search reviews...", text: $searchText)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                                            .onChange(of: searchText) { newValue in
                                // Debounce the search to avoid state modification during view updates
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if searchText == newValue {
                                        viewModel.filterReviews(searchText)
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
                                        .font(.system(size: 16))
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
                    
                    // Feed Content
                    if viewModel.isLoading {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading feed...")
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .padding(.top, DesignSystem.Spacing.md)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredReviews.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Spacer()
                            Image(systemName: "cup.and.saucer")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text("No Reviews Yet")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Be the first to review a chai spot!")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(DesignSystem.Spacing.xl)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(viewModel.filteredReviews) { review in
                                    ReviewCardView(review: review)
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .padding(.bottom, 100) // Space for FAB
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                
                // Floating Action Button - Positioned absolutely
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            // Add new review
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Circle())
                                .shadow(
                                    color: DesignSystem.Shadows.medium.color,
                                    radius: DesignSystem.Shadows.medium.radius,
                                    x: DesignSystem.Shadows.medium.x,
                                    y: DesignSystem.Shadows.medium.y
                                )
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadFeed()
            }
        }
    }
} 