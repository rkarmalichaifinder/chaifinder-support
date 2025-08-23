# Firebase Messaging Setup Guide for ChaiSpot

## Overview
This guide will help you add Firebase Messaging to the ChaiSpot project to enable push notifications.

## Prerequisites
- Xcode 14.0 or later
- iOS 13.0 or later deployment target
- Firebase project already configured (FirebaseCore, FirebaseAuth, FirebaseFirestore)

## Step 1: Add Firebase Messaging Dependency

### Option A: Using Xcode UI (Recommended)
1. Open `ChaiSpotFixed.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the `ChaiSpotFixed` target
4. Go to **Package Dependencies** tab
5. Find the Firebase package (should already be there)
6. Click the **+** button next to Firebase
7. Add `FirebaseMessaging` dependency
8. Click **Add Package**

### Option B: Manual Package.swift (if exists)
If the project has a Package.swift file, add this dependency:
```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
],
targets: [
    .target(
        name: "ChaiSpotFixed",
        dependencies: [
            .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
            .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            .product(name: "FirebaseMessaging", package: "firebase-ios-sdk") // Add this line
        ]
    )
]
```

## Step 2: Configure Push Notifications

### 2.1 Enable Push Notifications Capability
1. In Xcode, select the `ChaiSpotFixed` target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Push Notifications**

### 2.2 Configure Background Modes (Optional)
For background notification processing:
1. In **Signing & Capabilities**
2. Click **+ Capability**
3. Add **Background Modes**
4. Check **Remote notifications**

## Step 3: Firebase Console Configuration

### 3.1 Upload APNs Authentication Key
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your ChaiSpot project
3. Go to **Project Settings** → **Cloud Messaging**
4. Upload your APNs Authentication Key (.p8 file)
5. Note the **Key ID** and **Team ID**

### 3.2 Get APNs Authentication Key
1. Go to [Apple Developer Portal](https://developer.apple.com/)
2. **Certificates, Identifiers & Profiles**
3. **Keys** → **All**
4. Create new key or use existing one
5. Enable **Apple Push Notifications service (APNs)**
6. Download the .p8 file

## Step 4: Code Implementation

### 4.1 NotificationService.swift
The file is already updated with:
- Firebase Messaging import
- FCM token handling
- Push notification processing
- User preference controls

### 4.2 AppDelegate.swift
Already configured with:
- Firebase initialization
- Push notification handling
- Gamification notification processing

## Step 5: Testing Push Notifications

### 5.1 Test on Device
1. Build and run on a physical device
2. Grant notification permissions
3. Check FCM token in notification settings
4. Use test buttons to verify functionality

### 5.2 Test from Firebase Console
1. Go to Firebase Console → **Cloud Messaging**
2. Send test message to your device
3. Verify notification appears

## Step 6: Server-Side Integration

### 6.1 Send Notifications via Firebase Admin SDK
```python
# Python example
import firebase_admin
from firebase_admin import messaging

# Initialize Firebase Admin SDK
firebase_admin.initialize_app()

# Send notification
message = messaging.Message(
    notification=messaging.Notification(
        title='🎖️ New Badge Unlocked!',
        body='Congratulations on earning the Chai Explorer badge!'
    ),
    data={
        'type': 'badge_unlock',
        'badge_id': 'chai_explorer'
    },
    token='user_fcm_token_here'
)

response = messaging.send(message)
```

### 6.2 Cloud Functions Integration
```javascript
// Firebase Cloud Functions
exports.sendBadgeNotification = functions.firestore
    .document('users/{userId}/badges/{badgeId}')
    .onCreate(async (snap, context) => {
        const badgeData = snap.data();
        const userId = context.params.userId;
        
        // Get user's FCM token
        const userDoc = await admin.firestore()
            .collection('users')
            .doc(userId)
            .get();
        
        const fcmToken = userDoc.data().fcmToken;
        
        if (fcmToken) {
            const message = {
                notification: {
                    title: '🎖️ New Badge Unlocked!',
                    body: `Congratulations on earning the ${badgeData.name} badge!`
                },
                data: {
                    type: 'badge_unlock',
                    badge_id: badgeData.id
                },
                token: fcmToken
            };
            
            return admin.messaging().send(message);
        }
    });
```

## Troubleshooting

### Common Issues

#### 1. "No such module 'FirebaseMessaging'"
- Ensure Firebase Messaging is added to Package Dependencies
- Clean build folder (Cmd+Shift+K)
- Restart Xcode

#### 2. Push Notifications Not Working
- Verify APNs key is uploaded to Firebase Console
- Check device has internet connection
- Ensure app has notification permissions

#### 3. FCM Token Not Generated
- Check Firebase configuration in AppDelegate
- Verify notification permissions are granted
- Check Xcode console for error messages

### Debug Commands
```bash
# Check notification permissions
xcrun simctl push booted com.yourapp.bundleid notification.json

# View device logs
xcrun simctl spawn booted log stream --predicate 'process == "SpringBoard"'
```

## Next Steps

### 1. Implement Server-Side Notifications
- Set up Firebase Cloud Functions
- Create notification triggers for user actions
- Implement notification scheduling

### 2. Add Rich Notifications
- Custom notification sounds
- Notification actions (Accept/Decline friend requests)
- Deep linking to specific app sections

### 3. Analytics & Optimization
- Track notification engagement
- A/B test notification content
- Optimize notification timing

## Support
If you encounter issues:
1. Check Firebase Console for error logs
2. Review Xcode console output
3. Verify all dependencies are properly linked
4. Ensure APNs configuration is correct

## Current Status
✅ **Code Implementation**: Complete  
✅ **Notification Preferences**: Complete  
✅ **Local Notifications**: Complete  
⏳ **Firebase Messaging**: Pending dependency addition  
⏳ **Push Notifications**: Pending testing  
⏳ **Server Integration**: Ready for implementation  

The notification system is fully implemented and ready for Firebase Messaging integration!
