import SwiftUI
import MapKit
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import CoreLocation


struct ContentView: View {
    @State private var selectedTab: Int = 0
    @StateObject private var notificationChecker = NotificationChecker() // ✅ Step 1

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)

            ListTabView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .tag(1)

            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(2)

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(3)
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)

        }
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                print("Logged in as \(uid)")
                FriendService.createUserDocumentIfNeeded { success in

                    if success {
                        notificationChecker.checkForNewActivity()
                    } else {
                        print("❌ Failed to ensure Firestore user document.")
                    }
                }
            }
        }

    }
}

struct MapTabView: View {
    private let db = Firestore.firestore()

    @AppStorage("regionLat") private var regionLat: Double = 37.7749
    @AppStorage("regionLon") private var regionLon: Double = -122.4194
    @AppStorage("regionSpan") private var regionSpan: Double = 0.05

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    private var regionBinding: Binding<MKCoordinateRegion> {
        Binding(get: { region }, set: {
            region = $0
            regionLat = $0.center.latitude
            regionLon = $0.center.longitude
            regionSpan = $0.span.latitudeDelta
        })
    }
    @StateObject private var notificationChecker = NotificationChecker()
    @State private var chaiFinder: [ChaiFinder] = []
    @State private var ratings: [Rating] = []
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var tempSearchCoordinate: CLLocationCoordinate2D?
    @State private var showingAddForm = false
    @State private var selectedSpotForRating: SpotIDWrapper?
    @State private var isInRatingMode = false
    @State private var showThankYou = false
    @State private var showDuplicateAlert = false
    @State private var userRating: Rating?
    @State private var allUsers: [UserProfile] = []
    @State private var ratingsLoaded = false
    @State private var usersLoaded = false


    var body: some View {
        ZStack {
            TappableMapView(
                region: regionBinding,
                chaiFinder: chaiFinder,
                onTap: { coord in
                    selectedCoordinate = coord
                    showingAddForm = true
                },
                onAnnotationTap: { spotId in
                    fetchExistingRating(for: spotId) { r in
                        userRating = r
                        isInRatingMode = false
                        selectedSpotForRating = SpotIDWrapper(value: spotId)
                    }
                },
                tempSearchCoordinate: tempSearchCoordinate
            )
            .ignoresSafeArea(edges: .top)


            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showingAddForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            AddChaiFinderForm(
                coordinate: selectedCoordinate ?? tempSearchCoordinate,
                onSubmit: { name, address, ratingValue, comment, chaiTypes, coord in
                    addSpot(
                        name: name,
                        address: address,
                        ratingValue: ratingValue,
                        comment: comment,
                        chaiTypes: chaiTypes,
                        at: coord
                    ) { success in if success { showingAddForm = false } }
                }
            )
        }
        .alert("Duplicate Spot", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("That chai spot already exists!")
        }
        .sheet(item: $selectedSpotForRating) { wrapped in
            ratingSheet(spotId: wrapped.value)
        }
        .alert("Thank you!", isPresented: $showThankYou) {
            Button("OK") {}
        }
        .onAppear(perform: loadData)
    }

    // MARK: – Helper Methods

    private func loadData() {
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: regionLat, longitude: regionLon),
            span: MKCoordinateSpan(latitudeDelta: regionSpan, longitudeDelta: regionSpan)
        )
        CLLocationManager().requestWhenInUseAuthorization()

        db.collection("chaiFinder").addSnapshotListener { snap, err in
            guard let docs = snap?.documents, err == nil else { return }
            chaiFinder = docs.compactMap {
                var s = try? $0.data(as: ChaiFinder.self)
                s?.id = $0.documentID; return s
            }
            updateAverageRatings()
        }
        db.collection("ratings").addSnapshotListener { snap, err in
            guard let docs = snap?.documents, err == nil else { return }
            ratings = docs.compactMap {
                var r = try? $0.data(as: Rating.self)
                r?.id = $0.documentID; return r
            }
            updateAverageRatings()
        }
        db.collection("users").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else { return }
            allUsers = documents.compactMap {
                var user = try? $0.data(as: UserProfile.self)
                user?.id = $0.documentID
                return user
            }
        }

    }

    private func updateAverageRatings() {
        var map: [String:[Int]] = [:]
        for r in ratings { map[r.spotId, default:[]].append(r.value) }
        chaiFinder = chaiFinder.map {
            var s = $0
            if let vals = map[$0.id ?? ""] {
                s.averageRating = Double(vals.reduce(0,+))/Double(vals.count)
                s.ratingCount = vals.count
            }
            return s
        }
    }

    private func fetchExistingRating(for spotId:String, completion:@escaping(Rating?)->Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil); return
        }
        db.collection("ratings")
            .whereField("spotId", isEqualTo: spotId)
            .whereField("userId", isEqualTo: uid)
            .limit(to:1)
            .getDocuments { snap, _ in
                if let doc = snap?.documents.first,
                   var r = try? doc.data(as:Rating.self) {
                    r.id = doc.documentID; completion(r)
                } else { completion(nil) }
            }
    }

    private func ratingSheet(spotId: String) -> some View {
        guard let spot = chaiFinder.first(where: { $0.id == spotId }) else {
            return AnyView(Text("Spot not found."))
        }

        if isInRatingMode {
            return AnyView(
                SubmitRatingView(
                    spotId: spot.id ?? "",
                    existingRating: userRating,
                    onComplete: {
                        isInRatingMode = false
                        selectedSpotForRating = nil
                        userRating = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showThankYou = true
                        }
                    }
                )
            )
        } else {
            return AnyView(
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text(spot.name).font(.title2).bold()
                            Text(spot.address).font(.subheadline)

                            if let avg = spot.averageRating {
                                Text("⭐️ \(String(format: "%.1f", avg)) average")
                                Text("Based on \(spot.ratingCount ?? 0) reviews")
                                    .font(.footnote).foregroundColor(.gray)
                            }

                            // 🧍 Your Rating
                            if let uid = Auth.auth().currentUser?.uid {
                                if let userRating = ratings.first(where: { $0.userId == uid && $0.spotId == spot.id }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("⭐️ Your Rating: \(userRating.value)")
                                            .font(.headline)
                                        if let comment = userRating.comment, !comment.isEmpty {
                                            Text("📝 \(comment)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }

                                // 👥 Friends’ Ratings
                                let currentUser = allUsers.first(where: { $0.uid == uid })
                                let friendIds = currentUser?.friends ?? []

                                let filteredRatings = ratings.filter { r in
                                    r.spotId == spot.id && r.userId != uid
                                }

                                let friendRatings = filteredRatings.filter { r in
                                    friendIds.contains(r.userId)
                                }

                                if !friendRatings.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("👥 Friends’ Ratings")
                                            .font(.headline)

                                        ForEach(friendRatings, id: \.id) { r in
                                            if let reviewer = allUsers.first(where: { $0.uid == r.userId }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("\(reviewer.displayName): ⭐️ \(r.value)")
                                                        .font(.subheadline)
                                                    if let comment = r.comment, !comment.isEmpty {
                                                        Text("📝 \(comment)")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .padding()
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.top)
                                }
                            }

                            // Buttons
                            Button("Rate this Spot") {
                                fetchExistingRating(for: spot.id ?? "") { r in
                                    userRating = r
                                    isInRatingMode = true
                                    selectedSpotForRating = SpotIDWrapper(value: spot.id ?? "")
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink("Read All Reviews") {
                                CommentListView(spotId: spot.id ?? "")
                            }
                            .buttonStyle(.bordered)

                            Button("Close") {
                                selectedSpotForRating = nil
                            }
                        }
                        .padding()
                    }
                }
            )
        }
    }


    private func addSpot(
        name:String,address:String,ratingValue:Int,
        comment:String,chaiTypes:[String],
        at coordinate:CLLocationCoordinate2D,
        onComplete:@escaping(Bool)->Void
    ){
        let coll = db.collection("chaiFinder")
        coll.whereField("name",isEqualTo:name).getDocuments{snap,err in
            guard err==nil,let docs=snap?.documents else {
                onComplete(false);return
            }
            let dup = docs.contains{
                (try? $0.data(as:ChaiFinder.self))?.address==address
            }
            if dup {
                showDuplicateAlert=true; onComplete(false); return
            }
            let newSpot = ChaiFinder(
                id:nil,name:name,
                latitude:coordinate.latitude,
                longitude:coordinate.longitude,
                address:address,
                chaiTypes:chaiTypes,
                averageRating:nil,
                ratingCount:nil
            )
            do {
                let ref = try coll.addDocument(from:newSpot)
                guard let uid=Auth.auth().currentUser?.uid else {
                    onComplete(false);return
                }
                let newRating:[String:Any] = [
                    "spotId":ref.documentID,
                    "userId":uid,
                    "value":ratingValue,
                    "comment":comment,
                    "timestamp":FieldValue.serverTimestamp()
                ]
                db.collection("ratings").addDocument(data:newRating){ _ in
                    onComplete(true)
                }
            } catch {
                onComplete(false)
            }
        }
    }
}


struct ListTabView: View {
    private let db = Firestore.firestore()

    @State private var chaiFinder: [ChaiFinder] = []
    @State private var ratings: [Rating] = []
    @State private var selectedSpotForRating: SpotIDWrapper?
    @State private var userRating: Rating?
    @State private var isInRatingMode = false
    @State private var showThankYou = false

    @State private var searchText = ""
    @State private var minRating: Double = 0
    @State private var sortMode: SortMode = .nearest

    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                HStack {
                    TextField("Search chai spots or type a city…",
                              text: $searchText,
                              onCommit: { searchLocation(named: searchText) })
                        .submitLabel(.search)
                        .padding(8)
                        .background(Color(white: 0.9))
                        .cornerRadius(8)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()

                // Filters
                HStack {
                    Text("Min ⭐️: \(String(format: "%.1f", minRating))")
                    Slider(value: $minRating, in: 0...5, step: 0.5)
                }
                .padding(.horizontal)

                Picker("Sort", selection: $sortMode) {
                    ForEach(SortMode.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // List View
                List(filteredChaiSpots) { spot in
                    Button {
                        fetchExistingRating(for: spot.id ?? "") { r in
                            userRating = r
                            isInRatingMode = false
                            selectedSpotForRating = SpotIDWrapper(value: spot.id ?? "")
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(spot.name).font(.headline)
                            Text(spot.address).font(.subheadline)
                            if let avg = spot.averageRating {
                                Text("⭐️ \(String(format: "%.1f", avg)) (\(spot.ratingCount ?? 0))")
                                    .font(.footnote).foregroundColor(.gray)
                            } else {
                                Text("No ratings yet").font(.footnote)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Chai Spots")
        }
        .sheet(item: $selectedSpotForRating) { wrapped in
            ratingSheet(spotId: wrapped.value)
        }
        .alert("Thank you!", isPresented: $showThankYou) {
            Button("OK") {}
        }
        .onAppear(perform: loadData)
    }

    // MARK: – Computed Filtered Spots

    private var filteredChaiSpots: [ChaiFinder] {
        var filtered = chaiFinder.filter { spot in
            let matches = searchText.isEmpty
                || spot.name.localizedCaseInsensitiveContains(searchText)
                || spot.address.localizedCaseInsensitiveContains(searchText)
            return matches && (spot.averageRating ?? 0) >= minRating
        }
        switch sortMode {
        case .nearest:
            if let loc = CLLocationManager().location {
                filtered.sort {
                    CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                        .distance(from: loc)
                    < CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                        .distance(from: loc)
                }
            }
        case .topRated:
            filtered.sort { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
        case .mostReviewed:
            filtered.sort { ($0.ratingCount ?? 0) > ($1.ratingCount ?? 0) }
        }
        return filtered
    }

    // MARK: – Firestore Data

    private func loadData() {
        db.collection("chaiFinder").addSnapshotListener { snap, err in
            guard let docs = snap?.documents, err == nil else { return }
            chaiFinder = docs.compactMap {
                var s = try? $0.data(as: ChaiFinder.self)
                s?.id = $0.documentID; return s
            }
            updateAverageRatings()
        }
        db.collection("ratings").addSnapshotListener { snap, err in
            guard let docs = snap?.documents, err == nil else { return }
            ratings = docs.compactMap {
                var r = try? $0.data(as: Rating.self)
                r?.id = $0.documentID; return r
            }
            updateAverageRatings()
        }
    }

    private func updateAverageRatings() {
        var map: [String:[Int]] = [:]
        for r in ratings { map[r.spotId, default:[]].append(r.value) }
        chaiFinder = chaiFinder.map {
            var s = $0
            if let vals = map[$0.id ?? ""] {
                s.averageRating = Double(vals.reduce(0,+))/Double(vals.count)
                s.ratingCount = vals.count
            }
            return s
        }
    }

    private func fetchExistingRating(for spotId:String, completion:@escaping(Rating?)->Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil); return
        }
        db.collection("ratings")
            .whereField("spotId", isEqualTo: spotId)
            .whereField("userId", isEqualTo: uid)
            .limit(to:1)
            .getDocuments { snap, _ in
                if let doc = snap?.documents.first,
                   var r = try? doc.data(as:Rating.self) {
                    r.id = doc.documentID; completion(r)
                } else { completion(nil) }
            }
    }

    private func ratingSheet(spotId:String)->some View {
        guard let spot = chaiFinder.first(where:{ $0.id==spotId }) else {
            return AnyView(Text("Spot not found."))
        }
        if isInRatingMode {
            return AnyView(
                SubmitRatingView(
                    spotId: spot.id ?? "",
                    existingRating: userRating,
                    onComplete: {
                        isInRatingMode = false
                        selectedSpotForRating = nil
                        userRating = nil
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.3){
                            showThankYou = true
                        }
                    }
                )
            )
        } else {
            return AnyView(
                NavigationStack {
                    VStack(spacing:16){
                        Text(spot.name).font(.title2).bold()
                        Text(spot.address).font(.subheadline)
                        if let avg = spot.averageRating {
                            Text("⭐️ \(String(format: "%.1f",avg)) average")
                            Text("Based on \(spot.ratingCount ?? 0) reviews")
                                .font(.footnote).foregroundColor(.gray)
                        }
                        Button("Rate this Spot"){
                            fetchExistingRating(for:spot.id ?? ""){ r in
                                userRating=r
                                isInRatingMode=true
                                selectedSpotForRating=SpotIDWrapper(value:spot.id ?? "")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        NavigationLink("Read All Reviews"){
                            CommentListView(spotId:spot.id ?? "")
                        }
                        .buttonStyle(.bordered)
                        Button("Close"){ selectedSpotForRating=nil }
                    }
                    .padding()
                }
            )
        }
    }

    // Optional: Handles external city searches
    private func searchLocation(named query: String) {
        guard !query.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        MKLocalSearch(request: req).start { resp, _ in
            if let coord = resp?.mapItems.first?.placemark.coordinate {
                // Do nothing for now — just available for map centering later
            }
        }
    }
}


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFirestoreSwift

struct FeedView: View {
    @State private var ratings: [Rating] = []
    @State private var friends: [String] = []
    @State private var usersById: [String: UserProfile] = [:]
    @State private var loading = true
    @State private var notLoggedIn = false

    var body: some View {
        NavigationStack {
            VStack {
                if notLoggedIn {
                    Text("Please log in to see your feed.")
                        .foregroundColor(.gray)
                        .padding()
                } else if loading {
                    ProgressView("Loading friend activity…")
                        .padding()
                } else if ratings.isEmpty {
                    Text("No friend activity yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(ratings.sorted(by: { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) })) { rating in
                        if let user = usersById[rating.userId] {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    profileImage(for: user)
                                        .frame(width: 30, height: 30)
                                        .clipShape(Circle())
                                    Text(user.displayName)
                                        .font(.headline)
                                }
                                Text("⭐️ \(rating.value)")
                                if let comment = rating.comment, !comment.isEmpty {
                                    Text("“\(comment)”")
                                        .italic()
                                        .font(.subheadline)
                                }
                                if let date = rating.timestamp {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Friends Feed")
            .onAppear(perform: checkAndLoadFeed)
        }
    }

    private func checkAndLoadFeed() {
        guard let uid = Auth.auth().currentUser?.uid else {
            notLoggedIn = true
            loading = false
            return
        }
        loadFeed(for: uid)
    }

    private func loadFeed(for uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                self.loading = false
                return
            }

            let friendIds = data["friends"] as? [String] ?? []
            self.friends = friendIds

            if friendIds.isEmpty {
                self.loading = false
                return
            }

            db.collection("ratings")
                .whereField("userId", in: friendIds)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments { snap, err in
                    guard let docs = snap?.documents, err == nil else {
                        self.loading = false
                        return
                    }

                    self.ratings = docs.compactMap { try? $0.data(as: Rating.self) }
                    fetchUserProfiles(for: friendIds)
                }
        }
    }

    private func fetchUserProfiles(for uids: [String]) {
        let db = Firestore.firestore()
        db.collection("users").whereField("uid", in: uids).getDocuments { snap, err in
            guard let docs = snap?.documents, err == nil else {
                self.loading = false
                return
            }

            var map: [String: UserProfile] = [:]
            for doc in docs {
                if let user = try? doc.data(as: UserProfile.self) {
                    map[user.uid] = user
                }
            }
            self.usersById = map
            self.loading = false
        }
    }

    private func profileImage(for user: UserProfile) -> some View {
        if let urlStr = user.photoURL, let url = URL(string: urlStr) {
            return AnyView(AsyncImage(url: url) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            })
        } else {
            let initials = user.displayName.split(separator: " ")
                .compactMap { $0.first }
                .prefix(2)
                .map { String($0) }
                .joined()

            return AnyView(
                Text(initials.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.gray)
                    .clipShape(Circle())
            )
        }
    }
}




import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct FriendsView: View {
    @State private var users: [UserProfile] = []
    @State private var currentUser: UserProfile?
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var notLoggedIn = false
    @State private var sentRequests: Set<String> = []
    @State private var sendingToUser: String?

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            VStack {
                if notLoggedIn {
                    Text("Please log in to manage your friends.")
                        .foregroundColor(.gray)
                        .padding()
                } else if loading {
                    ProgressView("Loading...")
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)").foregroundColor(.red)
                } else {
                    List {
                        // My Profile
                        if let currentUser = currentUser {
                            Section(header: Text("My Profile")) {
                                HStack {
                                    profileImage(for: currentUser)
                                    VStack(alignment: .leading) {
                                        Text(currentUser.displayName)
                                            .font(.headline)
                                        Text(currentUser.email)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }

                            // Friend Requests
                            if let incoming = currentUser.incomingRequests, !incoming.isEmpty {
                                Section(header: Text("Friend Requests")) {
                                    ForEach(users.filter { incoming.contains($0.uid) }) { user in
                                        HStack {
                                            profileImage(for: user)
                                            VStack(alignment: .leading) {
                                                Text(user.displayName)
                                                Text(user.email).font(.caption).foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Button("Accept") {
                                                FriendService.acceptFriendRequest(from: user.uid) { _ in
                                                    reloadData()
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)

                                            Button("Reject") {
                                                FriendService.rejectFriendRequest(from: user.uid) { _ in
                                                    reloadData()
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }

                        // Invite
                        Section {
                            Button {
                                inviteFriends()
                            } label: {
                                Label("Invite a Friend", systemImage: "square.and.arrow.up")
                            }
                        }

                        // People You May Know
                        if !users.isEmpty {
                            Section(header: Text("People You May Know")) {
                                ForEach(users) { user in
                                    HStack {
                                        profileImage(for: user)
                                        VStack(alignment: .leading) {
                                            Text(user.displayName)
                                            Text(user.email).font(.caption).foregroundColor(.gray)
                                        }
                                        Spacer()

                                        if isFriend(user) {
                                            Button("Remove") {
                                                removeFriend(user)
                                            }
                                            .buttonStyle(.bordered)
                                            .foregroundColor(.red)
                                        } else {
                                            Button(action: {
                                                print("\u{1F4E4} Sending request to: \(user.displayName) (\(user.uid))")
                                                withAnimation {
                                                    sendingToUser = user.uid
                                                }
                                                let targetRef = db.collection("users").document(user.uid)

                                                db.runTransaction({ transaction, errorPointer in
                                                    do {
                                                        let snapshot = try transaction.getDocument(targetRef)
                                                        guard snapshot.exists else {
                                                            throw NSError(domain: "FriendError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document does not exist."])
                                                        }
                                                    } catch let error {
                                                        errorPointer?.pointee = error as NSError
                                                        return nil
                                                    }
                                                    return nil
                                                }, completion: { _, error in
                                                    DispatchQueue.main.async {
                                                        sendingToUser = nil
                                                    }
                                                    if let error = error {
                                                        print("❌ Request failed: \(error.localizedDescription)")
                                                    } else {
                                                        FriendService.sendFriendRequest(to: user.uid) { success in
                                                            if success {
                                                                sentRequests.insert(user.uid)
                                                                print("✅ Friend request sent!")
                                                                reloadData()
                                                            } else {
                                                                print("❌ Request failed")
                                                            }
                                                        }
                                                    }
                                                })
                                            }) {
                                                if sendingToUser == user.uid {
                                                    ProgressView()
                                                } else if sentRequests.contains(user.uid) || isRequestSent(to: user) {
                                                    Text("Requested")
                                                        .foregroundColor(.gray)
                                                        .font(.caption)
                                                } else {
                                                    Text("Send Request")
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(sendingToUser != nil)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .onAppear(perform: reloadData)
        }
    }

    private func reloadData() {
        guard let uid = Auth.auth().currentUser?.uid else {
            notLoggedIn = true
            loading = false
            return
        }

        db.collection("users").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                errorMessage = error?.localizedDescription ?? "Unknown error"
                loading = false
                return
            }

            let allUsers = documents.compactMap { doc -> UserProfile? in
                var user = try? doc.data(as: UserProfile.self)
                user?.id = doc.documentID
                user?.uid = doc.get("uid") as? String ?? doc.documentID
                return user
            }

            self.currentUser = allUsers.first(where: { $0.uid == uid })
            self.users = allUsers.filter { $0.uid != uid }
            self.loading = false

            print("👥 Loaded users:")
            for user in self.users {
                print("- \(user.displayName): \(user.uid)")
            }
        }
    }

    private func isFriend(_ user: UserProfile) -> Bool {
        currentUser?.friends?.contains(user.uid) ?? false
    }

    private func isRequestSent(to user: UserProfile) -> Bool {
        currentUser?.outgoingRequests?.contains(user.uid) ?? false
    }

    private func removeFriend(_ user: UserProfile) {
        guard let currentUser = currentUser else { return }

        let batch = db.batch()
        let currentRef = db.collection("users").document(currentUser.uid)
        let otherRef = db.collection("users").document(user.uid)

        var currentFriends = Set(currentUser.friends ?? [])
        currentFriends.remove(user.uid)
        batch.updateData(["friends": Array(currentFriends)], forDocument: currentRef)

        var otherFriends = Set(user.friends ?? [])
        otherFriends.remove(currentUser.uid)
        batch.updateData(["friends": Array(otherFriends)], forDocument: otherRef)

        batch.commit { error in
            if error == nil {
                self.reloadData()
            }
        }
    }

    private func profileImage(for user: UserProfile) -> some View {
        let initials = user.displayName
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map { String($0) }
            .joined()

        return Text(initials.uppercased())
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(Color.gray)
            .clipShape(Circle())
            .padding(.trailing, 4)
    }

    private func inviteFriends() {
        let inviteText = "🍵 Check out Chai Finder! Download it and add me as a friend."
        let av = UIActivityViewController(activityItems: [inviteText], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}
