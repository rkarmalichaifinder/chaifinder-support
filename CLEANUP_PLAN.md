# 🧹 Codebase Cleanup Plan

## 🗑️ **Immediate Actions Needed**

### 1. **Remove Debug Print Statements** (50+ instances)
**Files to clean:**
- `FeedView.swift` - Remove debug prints
- `SavedSpotsView.swift` - Remove debug prints  
- `FriendsView.swift` - Remove debug prints
- `ChaiSpotDetailSheet.swift` - Remove debug prints
- `FeedViewModel.swift` - Remove debug prints
- `SignInView.swift` - Remove debug prints
- `SubmitRatingView.swift` - Remove debug prints
- `FriendRatingsView.swift` - Remove debug prints
- `NotificationChecker.swift` - Remove debug prints
- `FriendService.swift` - Remove debug prints
- `CommentListView.swift` - Remove debug prints
- `SessionStore.swift` - Remove debug prints
- `ProfileView.swift` - Remove debug prints
- `AutocompleteModel.swift` - Remove debug prints

### 2. **Optimize Firebase Imports**
**Files to optimize:**
- `FeedView.swift` - Only needs `FirebaseFirestore`
- `ContentView.swift` - Only needs `FirebaseAuth` and `FirebaseFirestore`
- `ChaiSpotDetailSheet.swift` - Only needs `FirebaseFirestore`
- `SavedSpotsView.swift` - Only needs `FirebaseFirestore`
- `SignInView.swift` - Only needs `FirebaseAuth` and `FirebaseFirestore`
- `FriendsView.swift` - Only needs `FirebaseFirestore`
- `ProfileView.swift` - Only needs `FirebaseFirestore`

### 3. **Remove Redundant Files**
- **`SpotIDWrapper.swift`** - Delete (7 lines, unnecessary)
- **`SortMode.swift`** - Move enum inline or delete if unused
- **`ReviewFeedItem.swift`** - Merge with `Rating.swift` if possible

### 4. **Split Large Files**
- **`SearchView.swift`** (1,261 lines) → Split into:
  - `SearchView.swift` (main view)
  - `SearchViewModel.swift` (business logic)
  - `SearchResultsView.swift` (results display)
  - `SearchFiltersView.swift` (filters)

- **`FriendsView.swift`** (604 lines) → Split into:
  - `FriendsView.swift` (main view)
  - `FriendsViewModel.swift` (business logic)
  - `FriendRequestsView.swift` (requests)
  - `FriendsListView.swift` (friends list)

- **`ProfileView.swift`** (534 lines) → Split into:
  - `ProfileView.swift` (main view)
  - `ProfileViewModel.swift` (business logic)
  - `ProfileSettingsView.swift` (settings)

### 5. **Remove TODO Comments**
- `FeedView.swift` - Remove TODO comments
- Any other files with TODO comments

## 🎯 **Priority Order**

1. **High Priority** - Remove debug prints (immediate)
2. **Medium Priority** - Optimize imports (quick wins)
3. **Low Priority** - Split large files (refactoring)

## 📊 **Expected Impact**

- **Reduced file size:** ~20-30% smaller
- **Better performance:** Fewer debug statements
- **Cleaner code:** Better organization
- **Easier maintenance:** Smaller, focused files

## 🚀 **Implementation Steps**

1. **Phase 1:** Remove all debug prints (1-2 hours)
2. **Phase 2:** Optimize imports (30 minutes)
3. **Phase 3:** Remove redundant files (15 minutes)
4. **Phase 4:** Split large files (4-6 hours) 