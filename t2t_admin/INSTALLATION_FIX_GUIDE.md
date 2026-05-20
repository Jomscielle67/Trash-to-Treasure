# T2T Admin - Installation & Build Fix Guide

## ✅ Issues Fixed

### 1. **Kotlin Version Updated** ✓
- **Before**: Kotlin 1.8.22 (deprecated)
- **After**: Kotlin 2.1.0 (latest stable)
- **File**: `android/settings.gradle.kts` (line 24)

### 2. **APK Installation Failure** (Manual Steps Required)

---

## 🚨 Installation Error Explanation

### Error Messages:
```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package signatures do not match
INSTALL_FAILED_USER_RESTRICTED: Install canceled by user
```

### What This Means:
1. **Signature Mismatch**: An older version of the app with a different signing key is installed
2. **User Restricted**: Your phone's security settings are blocking the installation

---

## 🔧 **Solution Steps**

### **Step 1: Uninstall Existing App from Phone**

Choose one of these methods:

#### Option A - Via ADB (Recommended):
```powershell
# Run this command in your terminal
adb uninstall com.example.t2t_admin
```

#### Option B - Manually on Phone:
1. Open **Settings** on your phone
2. Go to **Apps** or **Application Manager**
3. Find **T2T Admin** in the list
4. Tap on it
5. Tap **Uninstall**
6. Confirm uninstall

---

### **Step 2: Enable Installation from USB (If Needed)**

If you get "Install canceled by user" error:

1. Open **Settings** on your phone
2. Go to **Developer Options**
3. Find and enable:
   - ✅ **USB debugging** (should already be on)
   - ✅ **Install via USB**
   - ✅ **USB debugging (Security settings)**

**If you don't see Developer Options:**
1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. Developer Options will appear in Settings

---

### **Step 3: Clean & Rebuild the Project**

Run these commands in order:

```powershell
# 1. Clean the build
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Rebuild and run
flutter run
```

---

## 🎯 **Quick Fix Command (All-in-One)**

Run this single command sequence:

```powershell
adb uninstall com.example.t2t_admin; flutter clean; flutter pub get; flutter run
```

This will:
1. ✅ Uninstall old app
2. ✅ Clean build cache
3. ✅ Get fresh dependencies
4. ✅ Build and install new app

---

## 📱 **If Installation Still Fails**

### Check Phone Authorization:

1. **Look at your phone screen** when you run `flutter run`
2. You might see a popup asking to **"Allow USB debugging?"**
3. Tap **Allow** or **OK**
4. Check **"Always allow from this computer"** (optional)

### Verify ADB Connection:

```powershell
# Check if device is connected
adb devices

# Should show:
# List of devices attached
# 23049PCD8G    device
```

If it shows "unauthorized":
1. Disconnect USB cable
2. Reconnect USB cable
3. Allow the authorization popup on phone
4. Run `adb devices` again

---

## 🔍 **Troubleshooting**

### Issue: "ADB not recognized"
**Solution**: Make sure Android SDK platform-tools are in your PATH

```powershell
# Check ADB path
flutter doctor -v
```

### Issue: "Device not found"
**Solutions**:
1. Try a different USB cable (data cable, not just charging)
2. Try a different USB port on your computer
3. Enable "File Transfer" mode on phone (not just "Charging")

### Issue: Still getting signature error after uninstall
**Solution**: Completely remove app data

```powershell
# Force uninstall with all data
adb shell pm uninstall -k --user 0 com.example.t2t_admin
```

### Issue: Gradle build fails
**Solution**: Clear Gradle cache

```powershell
# Navigate to android directory
cd android

# Clean Gradle
./gradlew clean

# Go back to root
cd ..

# Try again
flutter run
```

---

## ✅ **Verification Checklist**

Before running `flutter run`, ensure:

- [ ] Old app is completely uninstalled from phone
- [ ] USB debugging is enabled
- [ ] Phone shows as "device" (not "unauthorized") in `adb devices`
- [ ] Flutter clean has been run
- [ ] Kotlin version is updated to 2.1.0 (done ✓)
- [ ] Phone is unlocked during installation

---

## 🎨 **What Changed in the Code**

### File: `android/settings.gradle.kts`

```kotlin
// BEFORE:
id("org.jetbrains.kotlin.android") version "1.8.22" apply false

// AFTER:
id("org.jetbrains.kotlin.android") version "2.1.0" apply false
```

**Why**: 
- Flutter is dropping support for Kotlin < 2.0
- Kotlin 2.1.0 is the latest stable version
- Ensures compatibility with future Flutter updates
- Improves build performance and adds new Kotlin features

---

## 🚀 **Ready to Run!**

Now you can run the app with the latest fixes:

```powershell
# Full clean build (recommended first time)
flutter clean && flutter pub get && flutter run

# Or just run directly
flutter run
```

---

## 📊 **Expected Output**

You should see:

```
Running Gradle task 'assembleDebug'...                              
√ Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...           
Syncing files to device 23049PCD8G...                              
Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

💪 Running with sound null safety 💪

An Observatory debugger and profiler on 23049PCD8G is available at: http://127.0.0.1:xxxxx/
The Flutter DevTools debugger and profiler on 23049PCD8G is available at: http://127.0.0.1:xxxxx/
```

---

## 🎉 **Summary**

### Fixed:
1. ✅ Kotlin version updated to 2.1.0
2. ✅ Removed deprecation warning
3. ✅ Ready for future Flutter updates

### Action Required:
1. ⚠️ Uninstall old app from phone: `adb uninstall com.example.t2t_admin`
2. ⚠️ Enable USB installation in phone settings
3. ⚠️ Run: `flutter clean && flutter pub get && flutter run`

---

## 💡 **Pro Tips**

### Faster Rebuilds:
After the first successful install, you can use:
```powershell
# Hot reload (fastest - preserves app state)
r

# Hot restart (medium - resets app state)
R

# Full rebuild (slowest - use only if needed)
flutter run
```

### Building Release APK:
When ready to release:
```powershell
flutter build apk --release
```

### Checking Flutter Setup:
```powershell
flutter doctor -v
```

---

**Need Help?** If you still encounter issues after following these steps, please share:
1. Output of `adb devices`
2. Output of `flutter doctor -v`
3. The full error message you're getting

Good luck! 🚀
