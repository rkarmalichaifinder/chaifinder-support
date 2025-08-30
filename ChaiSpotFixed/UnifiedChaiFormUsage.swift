import SwiftUI
import CoreLocation

// MARK: - Usage Examples for UnifiedChaiForm
// This file shows how to use the new UnifiedChaiForm for both scenarios

struct UnifiedChaiFormUsageExamples: View {
    @State private var showingAddNewSpotForm = false
    @State private var showingRateExistingSpotForm = false
    
    // Example existing spot for rating
    let exampleSpot = ChaiSpot(
        id: "example123",
        name: "Chai Corner Cafe",
        address: "123 Main Street, Downtown",
        latitude: 40.7128,
        longitude: -74.0060,
        chaiTypes: ["Masala", "Ginger"],
        averageRating: 4.2,
        ratingCount: 15
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("UnifiedChaiForm Usage Examples")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    // Example 1: Add New Chai Spot
                    Button("Add New Chai Spot") {
                        showingAddNewSpotForm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    // Example 2: Rate Existing Chai Spot
                    Button("Rate Existing Chai Spot") {
                        showingRateExistingSpotForm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Usage Examples")
        }
        .sheet(isPresented: $showingAddNewSpotForm) {
            UnifiedChaiForm(
                isAddingNewSpot: true,
                existingSpot: nil,
                coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                onComplete: {
                    print("New chai spot added successfully!")
                    showingAddNewSpotForm = false
                }
            )
        }
        .sheet(isPresented: $showingRateExistingSpotForm) {
            UnifiedChaiForm(
                isAddingNewSpot: false,
                existingSpot: exampleSpot,
                coordinate: nil,
                onComplete: {
                    print("Rating submitted successfully!")
                    showingRateExistingSpotForm = false
                }
            )
        }
    }
}

// MARK: - Integration Examples

// Example 1: Replace AddChaiSpotForm in PersonalizedMapView
struct MapViewWithUnifiedForm: View {
    @State private var showingAddSpotForm = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        VStack {
            // Your map view content here
            Text("Map View")
                .font(.title)
            
            Button("Add Chai Spot Here") {
                showingAddSpotForm = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingAddSpotForm) {
            UnifiedChaiForm(
                isAddingNewSpot: true,
                existingSpot: nil,
                coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                onComplete: {
                    print("New spot added!")
                    showingAddSpotForm = false
                }
            )
        }
    }
}

// Example 2: Replace SubmitRatingView in ChaiSpotDetailSheet
struct DetailSheetWithUnifiedForm: View {
    let spot: ChaiSpot
    @State private var showingRatingForm = false
    
    var body: some View {
        VStack {
            // Your spot detail content here
            Text("Spot Details: \(spot.name)")
                .font(.title)
            
            Button("Rate This Spot") {
                showingRatingForm = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingRatingForm) {
            UnifiedChaiForm(
                isAddingNewSpot: false,
                existingSpot: spot,
                coordinate: nil,
                onComplete: {
                    print("Rating submitted for \(spot.name)!")
                    showingRatingForm = false
                }
            )
        }
    }
}

// MARK: - Migration Guide

/*
 MIGRATION GUIDE: From Two Forms to UnifiedChaiForm
 
 1. REPLACE AddChaiSpotForm usage:
    OLD:
    AddChaiFinderForm(coordinate: coordinate) { name, address, rating, comments, chaiTypes, coordinate, creaminessRating, chaiStrengthRating, flavorNotes in
        // Handle form submission
    }
    
    NEW:
    UnifiedChaiForm(
        isAddingNewSpot: true,
        existingSpot: nil,
        coordinate: coordinate, // Pass the coordinate from map
        onComplete: {
            // Handle completion
        }
    )
 
 2. REPLACE SubmitRatingView usage:
    OLD:
    SubmitRatingView(
        spotId: spot.id,
        spotName: spot.name,
        spotAddress: spot.address,
        existingRating: nil,
        onComplete: {
            // Handle completion
        }
    )
    
    NEW:
    UnifiedChaiForm(
        isAddingNewSpot: false,
        existingSpot: spot,
        coordinate: nil, // No coordinate needed for existing spots
        onComplete: {
            // Handle completion
        }
    )
 
 3. BENEFITS:
    - Single form to maintain
    - Consistent UX across both actions
    - Better location handling (auto-populated for existing spots)
    - All advanced features available for both scenarios
    - Reduced code duplication
 
 4. KEY FEATURES:
    - Automatic location population for existing spots
    - Conditional location fields (editable for new, read-only for existing)
    - Same advanced rating system for both use cases
    - Photo upload, privacy controls, gamification for both
    - Consistent validation and submission logic
 */

struct UnifiedChaiFormUsageExamples_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedChaiFormUsageExamples()
    }
}
