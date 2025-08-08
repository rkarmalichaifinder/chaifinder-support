import SwiftUI
import MapKit

struct AddChaiFinderForm: View {
    var coordinate: CLLocationCoordinate2D?
    var onSubmit: (String, String, Int, String, [String], CLLocationCoordinate2D) -> Void

    @State private var name = ""
    @State private var address = ""
    @State private var rating = 3
    @State private var comments = ""
    @State private var selectedChaiTypes: Set<String> = []
    @State private var customChaiType = ""
    @State private var isLoadingAddress = false
    @State private var showingNoCoordinateAlert = false
    @State private var resolvedCoordinate: CLLocationCoordinate2D? = nil
    @State private var isSubmitting = false

    @StateObject private var autoModel = AutocompleteModel()
    @State private var showNameDropdown = false

    private let allChaiTypes = [
        "Masala", "Ginger", "Cardamom / Elaichi",
        "Kashmiri", "Saffron / Zafrani", "Adrak",
        "Irani", "Karak", "Adeni"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Chai Spot Details")) {
                    // Shop Name with autocomplete
                    TextField("Shop Name", text: $name, onEditingChanged: { began in
                        showNameDropdown = began && !name.isEmpty
                        autoModel.completer.queryFragment = name
                    })
                    .padding(8)
                    .background(Color(white: 0.95))
                    .cornerRadius(6)
                    .onChange(of: name) { newValue in
                        showNameDropdown = !newValue.isEmpty
                        autoModel.completer.queryFragment = newValue
                    }

                    // Autocomplete suggestions listed below name field
                    if showNameDropdown && !autoModel.results.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(autoModel.results, id: \.self) { completion in
                                    Button(action: {
                                        let full = completion.title + " " + completion.subtitle
                                        name = completion.title
                                        showNameDropdown = false
                                        autoModel.results = []
                                        geocodePlace(named: full)
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
                    Picker("Rating", selection: $rating) {
                        ForEach(1..<6) { i in Text("\(i) Stars").tag(i) }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Comments")) {
                    TextField("Your thoughts…", text: $comments)
                }

                Section(header: Text("Chai Types")) {
                    ForEach(allChaiTypes, id: \.self) { type in
                        Toggle(type, isOn: Binding(
                            get: { selectedChaiTypes.contains(type) },
                            set: { isOn in
                                if isOn { selectedChaiTypes.insert(type) }
                                else { selectedChaiTypes.remove(type) }
                            }
                        ))
                    }
                    TextField("Custom chai type", text: $customChaiType)
                }

                Button(isSubmitting ? "Adding..." : "Submit") {
                    guard !name.isEmpty && !isSubmitting else { return }
                    isSubmitting = true
                    let types = Array(selectedChaiTypes) + (customChaiType.isEmpty ? [] : [customChaiType])
                    if let coord = resolvedCoordinate ?? coordinate {
                        onSubmit(name, address, rating, comments, types, coord)
                    } else {
                        showingNoCoordinateAlert = true
                        isSubmitting = false
                    }
                }
                .disabled(name.isEmpty || isSubmitting)
            }
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
