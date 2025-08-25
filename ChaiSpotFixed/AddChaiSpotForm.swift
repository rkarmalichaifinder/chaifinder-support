import SwiftUI
import MapKit



struct AddChaiFinderForm: View {
    var coordinate: CLLocationCoordinate2D?
    var onSubmit: (String, String, Int, String, [String], CLLocationCoordinate2D, Int, Int, [String]) -> Void

    @State private var name = ""
    @State private var address = ""
    @State private var rating = 3
    @State private var comments = ""
    @State private var chaiType = ""
    @State private var isLoadingAddress = false
    @State private var showingNoCoordinateAlert = false
    @State private var resolvedCoordinate: CLLocationCoordinate2D? = nil
    @State private var isSubmitting = false
    
    // New rating states
    @State private var creaminessRating = 0
    @State private var chaiStrengthRating = 0
    @State private var selectedFlavorNotes: Set<String> = []
    @State private var customFlavorNote = ""

    @StateObject private var autoModel = AutocompleteModel()
    @State private var showNameDropdown = false
    @State private var showChaiTypeDropdown = false
    @State private var justSelectedName = false

    private let allChaiTypes = [
        "Masala", "Ginger", "Cardamom / Elaichi",
        "Kashmiri", "Saffron / Zafrani", "Adrak",
        "Irani", "Karak", "Adeni", "Tulsi", "Lemongrass",
        "Cinnamon", "Black Pepper", "Fennel", "Mint",
        "Rose", "Vanilla", "Honey", "Jaggery", "Sugar-free"
    ]
    
    private let allFlavorNotes: [FlavorNote] = [
        FlavorNote(name: "Cardamom", color: Color(hex: "#8B4513"), symbol: "leaf"), // Brown
        FlavorNote(name: "Ginger", color: Color(hex: "#FF6B35"), symbol: "flame"), // Orange
        FlavorNote(name: "Cloves", color: Color(hex: "#800020"), symbol: "circle"), // Burgundy
        FlavorNote(name: "Saffron", color: Color(hex: "#FFD700"), symbol: "star"), // Gold
        FlavorNote(name: "Fennel", color: Color(hex: "#228B22"), symbol: "drop") // Forest Green
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Chai Spot Details")) {
                    // Shop Name with autocomplete
                    TextField("Shop Name", text: $name, onEditingChanged: { began in
                        if began && !justSelectedName {
                            showNameDropdown = !name.isEmpty
                            autoModel.completer.queryFragment = name
                        }
                        if !began {
                            justSelectedName = false
                        }
                    })
                    .padding(8)
                    .background(Color(white: 0.95))
                    .cornerRadius(6)
                    .onChange(of: name) { newValue in
                        if !justSelectedName {
                            showNameDropdown = !newValue.isEmpty
                            autoModel.completer.queryFragment = newValue
                        }
                    }

                    // Autocomplete suggestions listed below name field
                    if showNameDropdown && !autoModel.results.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(autoModel.results, id: \.self) { completion in
                                    Button(action: {
                                        let full = completion.title + " " + completion.subtitle
                                        justSelectedName = true
                                        name = completion.title
                                        showNameDropdown = false
                                        autoModel.results = []
                                        geocodePlace(named: full)
                                        
                                        // Reset the flag after a short delay to allow typing again
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            justSelectedName = false
                                        }
                                    }) {
                                        VStack(alignment: .leading) {
                                            Text(completion.title)
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .background(Color.white)
                        .cornerRadius(6)
                        .shadow(radius: 2)
                        .padding(.horizontal, -16) // extend full width within the form
                    }

                    // Address field & geocoding indicator
                    HStack {
                        TextField("Address", text: $address)
                        if isLoadingAddress {
                            ProgressView().scaleEffect(0.8)
                        }
                    }

                    // Display chosen coordinate
                    if let coord = resolvedCoordinate ?? coordinate {
                        Text("📍 Location: \(coord.latitude, specifier: "%.4f"), \(coord.longitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("❌ No location selected yet")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text("Rating")) {
                    Stepper("Rating: \(rating)★", value: $rating, in: 1...5)
                }
                
                Section(header: Text("Creaminess Rating")) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("How creamy is the chai?")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            if creaminessRating > 0 {
                                Text("\(creaminessRating)/5")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.creaminessRating)
                            } else {
                                Text("Not rated")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .italic()
                            }
                        }
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(1..<6) { i in
                                Button(action: { 
                                    creaminessRating = i
                                }) {
                                    Image(systemName: i <= creaminessRating ? "drop.fill" : "drop")
                                        .foregroundColor(i <= creaminessRating ? DesignSystem.Colors.creaminessRating : DesignSystem.Colors.border)
                                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20))
                                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 44 : 36, height: UIDevice.current.userInterfaceIdiom == .pad ? 44 : 36)
                                        .background(
                                            Circle()
                                                .fill(i <= creaminessRating ? DesignSystem.Colors.creaminessRating.opacity(0.1) : Color.clear)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(i <= creaminessRating ? DesignSystem.Colors.creaminessRating : DesignSystem.Colors.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        HStack {
                            Text("Watery")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Creamy")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Text("(Optional - tap any drop to rate)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                    }
                }
                
                Section(header: Text("Chai Strength Rating")) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("How strong is the chai flavor?")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            if chaiStrengthRating > 0 {
                                Text("\(chaiStrengthRating)/5")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.chaiStrengthRating)
                            } else {
                                Text("Not rated")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .italic()
                            }
                        }
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(1..<6) { i in
                                Button(action: { 
                                    chaiStrengthRating = i
                                }) {
                                    Image(systemName: i <= chaiStrengthRating ? "leaf.fill" : "leaf")
                                        .foregroundColor(i <= chaiStrengthRating ? DesignSystem.Colors.chaiStrengthRating : DesignSystem.Colors.border)
                                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20))
                                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 44 : 36, height: UIDevice.current.userInterfaceIdiom == .pad ? 44 : 36)
                                        .background(
                                            Circle()
                                                .fill(i <= chaiStrengthRating ? DesignSystem.Colors.chaiStrengthRating.opacity(0.1) : Color.clear)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(i <= chaiStrengthRating ? DesignSystem.Colors.chaiStrengthRating : DesignSystem.Colors.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        HStack {
                            Text("Mild")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Strong")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Text("(Optional - tap any leaf to rate)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                    }
                }
                
                Section(header: Text("Primary Flavor Notes")) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Select the primary flavors you taste:")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("(Optional - tap to select/deselect)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2), spacing: DesignSystem.Spacing.sm) {
                            ForEach(allFlavorNotes, id: \.self) { note in
                                Button(action: {
                                    if selectedFlavorNotes.contains(note.name) {
                                        selectedFlavorNotes.remove(note.name)
                                    } else {
                                        selectedFlavorNotes.insert(note.name)
                                    }
                                }) {
                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        Image(systemName: selectedFlavorNotes.contains(note.name) ? note.symbol + ".fill" : note.symbol)
                                            .foregroundColor(selectedFlavorNotes.contains(note.name) ? .white : note.color)
                                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14))
                                            .frame(width: 16, height: 16)
                                        Text(note.name)
                                            .font(DesignSystem.Typography.bodySmall)
                                            .foregroundColor(selectedFlavorNotes.contains(note.name) ? .white : note.color)
                                            .fontWeight(selectedFlavorNotes.contains(note.name) ? .semibold : .regular)
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                    .background(selectedFlavorNotes.contains(note.name) ? note.color : Color.clear)
                                    .cornerRadius(DesignSystem.CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                            .stroke(selectedFlavorNotes.contains(note.name) ? note.color : note.color.opacity(0.6), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        if !customFlavorNote.isEmpty || selectedFlavorNotes.isEmpty {
                            HStack {
                                TextField("Add custom flavor note", text: $customFlavorNote)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                if !customFlavorNote.isEmpty {
                                    Button("Add") {
                                        if !customFlavorNote.isEmpty {
                                            selectedFlavorNotes.insert(customFlavorNote)
                                            customFlavorNote = ""
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Comments")) {
                    TextField("Your thoughts…", text: $comments)
                }

                Section(header: Text("Chai Type")) {
                    TextField("Type to search chai types (e.g., Masala, Ginger...)", text: $chaiType, onEditingChanged: { began in
                        showChaiTypeDropdown = began && !chaiType.isEmpty
                    })
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: chaiType) { newValue in
                        showChaiTypeDropdown = !newValue.isEmpty
                    }
                    
                    Text("(Optional - start typing to see suggestions)")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
                    
                    // Chai type autocomplete suggestions
                    if showChaiTypeDropdown && !chaiType.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(allChaiTypes.filter { $0.lowercased().contains(chaiType.lowercased()) }, id: \.self) { type in
                                    Button(action: {
                                        chaiType = type
                                        showChaiTypeDropdown = false
                                    }) {
                                        Text(type)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.white)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .background(Color.white)
                        .cornerRadius(6)
                        .shadow(radius: 2)
                        .padding(.horizontal, -16)
                    }
                }

                Button(isSubmitting ? "Adding..." : "Submit") {
                    guard !name.isEmpty && !isSubmitting else { return }
                    isSubmitting = true
                    let types = chaiType.isEmpty ? [] : [chaiType]
                    if let coord = resolvedCoordinate ?? coordinate {
                        onSubmit(name, address, rating, comments, types, coord, creaminessRating, chaiStrengthRating, Array(selectedFlavorNotes) + (customFlavorNote.isEmpty ? [] : [customFlavorNote]))
                    } else {
                        showingNoCoordinateAlert = true
                        isSubmitting = false
                    }
                }
                .disabled(name.isEmpty || isSubmitting)
            }
            .formStyle(GroupedFormStyle())
            .navigationTitle("Add Chai Spot")
            .alert("No Location", isPresented: $showingNoCoordinateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please select a suggestion or enter an address.")
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { autoModel.completer.delegate = autoModel }
    }

    // Reverse lookup the selected place into an address & coordinate
    private func geocodePlace(named full: String) {
        isLoadingAddress = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = full
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isLoadingAddress = false
                if let coord = response?.mapItems.first?.placemark.coordinate {
                    resolvedCoordinate = coord
                    address = full
                } else {
                    address = full
                }
            }
        }
    }
}
