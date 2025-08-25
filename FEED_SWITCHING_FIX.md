# Feed Switching Fix - Complete Solution

## The Problem
Your feed view initially works when switching between friends and community, but going from friends → community → friends again leads to an "error unable to load" screen.

## Root Cause
The issue is caused by missing Firestore composite indexes for your filtered queries:

1. **Friends query**: `whereField("userId", in: friends).whereField("visibility", in: ["public", "friends"]).order(by: "timestamp", descending: true)`
2. **Community query**: `whereField("visibility", isEqualTo: "public").order(by: "timestamp", descending: true)`

## The Solution
Instead of just creating indexes, we've implemented a comprehensive solution that:

1. **Migrates existing data** to include required fields
2. **Provides fallback queries** for legacy data
3. **Ensures future data** includes proper fields
4. **Creates proper indexes** for optimal performance

## What We've Added

### 1. Data Migration Function
```swift
func backfillRatingsDefaults(batchSize: Int = 300, completion: @escaping (Error?) -> Void)
```
This function:
- Adds `visibility: "public"` to old ratings
- Adds `deleted: false` to old ratings
- Processes data in batches to avoid timeouts
- Updates all existing ratings documents

### 2. Enhanced Query Functions with Fallbacks
- `loadFriendRatingsWithFallback()` - Tries filtered query first, falls back to legacy
- `loadCommunityRatingsWithFallback()` - Same pattern for community ratings
- Automatic fallback when filtered queries fail or return no results

### 3. Debug Migration View
- `DebugMigrationView.swift` - A simple UI to trigger the migration
- Shows migration progress and status
- Can be added to your app temporarily

## How to Implement

### Step 1: Add the Debug View (Temporary)
Add this to your main navigation or settings:

```swift
NavigationLink("Debug Tools") {
    DebugMigrationView(feedViewModel: feedViewModel)
}
```

### Step 2: Run the Migration
1. Navigate to the Debug Tools view
2. Tap "Start Data Migration"
3. Wait for completion (usually 1-2 minutes)
4. The migration will automatically refresh your feed

### Step 3: Test Feed Switching
After migration, try switching between friends and community views. The error should be gone.

### Step 4: Remove Debug View (Optional)
Once everything works, you can remove the DebugMigrationView from your app.

## Required Firestore Indexes

After migration, you'll need these composite indexes:

### Index 1: Friends Feed
- Collection: `ratings`
- Fields:
  - `userId` (Ascending)
  - `visibility` (Ascending)
  - `deleted` (Ascending)
  - `timestamp` (Descending)

### Index 2: Community Feed
- Collection: `ratings`
- Fields:
  - `visibility` (Ascending)
  - `deleted` (Ascending)
  - `timestamp` (Descending)

## Future Data Structure

All new ratings should include these fields:

```swift
let ratingData: [String: Any] = [
    "userId": userId,
    "spotId": spotId,
    "rating": rating,
    "timestamp": FieldValue.serverTimestamp(),
    "visibility": "public", // or "friends", "private"
    "deleted": false,
    // ... other fields
]
```

## Benefits of This Approach

1. **Immediate Fix**: Solves your current feed switching issue
2. **Future Proof**: Ensures new data works properly
3. **Backward Compatible**: Old data continues to work
4. **Performance**: Proper indexes for optimal query performance
5. **Privacy Ready**: Foundation for future privacy features

## Monitoring

Check your console logs for:
- `🔄 Starting ratings data migration...`
- `🔄 Processed batch: X docs, updated: Y`
- `✅ Migration completed! Total processed: X, Total updated: Y`

## Troubleshooting

If migration fails:
1. Check your internet connection
2. Ensure you have write permissions to the ratings collection
3. Check the console for specific error messages
4. The fallback queries will still work, so your app won't break

## Next Steps

1. **Immediate**: Run the migration to fix the current issue
2. **Short-term**: Test feed switching thoroughly
3. **Long-term**: Consider adding privacy controls using the visibility field
4. **Cleanup**: Remove debug view once everything works

This solution addresses the root cause while maintaining backward compatibility and setting you up for future enhancements.
