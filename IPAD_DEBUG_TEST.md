# iPad Debug Test Guide

## Current Status
✅ Firebase messaging working (APNS token and FCM registration successful)
✅ App delegate proxy disabled
✅ All text fields updated to use iPad-optimized style

## Debug Steps

### 1. Test Text Field Interaction
- Tap on any text field in the app
- Check console for constraint warnings
- Verify keyboard appears and dismisses properly

### 2. Test Specific Features
- **Sign In**: Try logging in with email/password
- **Search**: Use search functionality in Feed, Map, or Friends
- **Forms**: Try adding a chai spot or editing profile
- **Navigation**: Test tab switching and navigation

### 3. Check for Specific Errors
Look for these in the console:
- `Unable to simultaneously satisfy constraints`
- `UIViewAlertForUnsatisfiableConstraints`
- `Snapshotting a view that is not in a visible window`
- Any crash logs or error messages

### 4. Test Different iPad Orientations
- Portrait mode
- Landscape mode
- Split screen (if applicable)

## Common Issues and Solutions

### If you see constraint warnings:
- The text field fixes should have resolved these
- Check if any new text fields were added

### If app crashes:
- Check for memory issues
- Look for Firebase configuration problems

### If UI looks wrong:
- Check if iPad-specific styling is applied
- Verify text field sizing and positioning

### If features don't work:
- Check network connectivity
- Verify Firebase configuration
- Test on iPhone simulator for comparison

## What to Report
Please share:
1. **Specific error messages** from console
2. **What exactly isn't working** (UI, functionality, performance)
3. **Steps to reproduce** the issue
4. **Screenshots** if UI looks wrong

## Quick Fixes to Try
1. **Reset Simulator**: Device → Erase All Content and Settings
2. **Clean Build**: Product → Clean Build Folder
3. **Restart Xcode**: Close and reopen Xcode
4. **Test on iPhone**: Compare behavior with iPhone simulator

