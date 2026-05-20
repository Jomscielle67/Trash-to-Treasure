# T2T Admin App - APK Installation Guide

## ✅ APK Successfully Built!

Your Android APK has been built and is ready for installation.

### 📍 APK Location
```
c:\Users\Vincent\Desktop\webpage\capstone\t2t\Super_User\t2t_admin\build\app\outputs\flutter-apk\app-release.apk
```

**File Size:** 65.9 MB

---

## 📱 Installing the APK on Android Devices

### Method 1: Direct Transfer (Recommended)

1. **Connect your Android device** to your computer via USB
2. **Enable File Transfer** mode on your phone
3. **Copy the APK file** from the location above to your phone's Downloads folder
4. **On your phone:**
   - Open the **Files** or **Downloads** app
   - Tap on `app-release.apk`
   - If prompted, **allow installation from unknown sources**
   - Tap **Install**
   - Once installed, tap **Open** to launch the app

### Method 2: Email/Cloud Transfer

1. **Upload** `app-release.apk` to:
   - Google Drive
   - Dropbox
   - Send via Email
   - Or any cloud storage

2. **On your Android device:**
   - Download the APK file
   - Open it from your Downloads
   - Allow installation from unknown sources if prompted
   - Install and launch

### Method 3: QR Code/File Sharing

1. Use apps like **ShareIt**, **Xender**, or **Google Files** to transfer the APK
2. Install on the receiving device

---

## 🔒 Security Settings

### Enable Installation from Unknown Sources

**Android 8.0 and above:**
1. Go to **Settings** → **Apps & Notifications**
2. Tap **Advanced** → **Special App Access**
3. Tap **Install Unknown Apps**
4. Select the browser/file manager you'll use to install
5. Enable **Allow from this source**

**Android 7.1 and below:**
1. Go to **Settings** → **Security**
2. Enable **Unknown Sources**

---

## 🚀 Building Different APK Variants

### Build APK for specific architecture (smaller size)

For ARM64 devices (most modern phones):
```bash
flutter build apk --release --target-platform android-arm64
```

For ARM32 devices:
```bash
flutter build apk --release --target-platform android-arm
```

### Build App Bundle (for Google Play Store)

If you want to publish to the Play Store:
```bash
flutter build appbundle --release
```

The bundle will be at: `build/app/outputs/bundle/release/app-release.aab`

---

## 📦 Distributing the APK

### Option 1: Rename for Easy Identification
```bash
# Navigate to the directory
cd "c:\Users\Vincent\Desktop\webpage\capstone\t2t\Super_User\t2t_admin\build\app\outputs\flutter-apk"

# Rename the file
ren app-release.apk t2t-admin-v1.0.0.apk
```

### Option 2: Create a Distribution Folder
Create a folder on your Desktop with:
- The APK file
- Installation instructions
- App icon/screenshots

### Option 3: Upload to File Hosting
- Google Drive
- Dropbox
- OneDrive
- Firebase App Distribution
- GitHub Releases

---

## 🔄 Updating the App

To build a new version:

1. **Update version in `pubspec.yaml`:**
   ```yaml
   version: 1.0.1+2  # Increment the version
   ```

2. **Rebuild the APK:**
   ```bash
   flutter build apk --release
   ```

3. **Distribute the new APK** to users

---

## ⚠️ Important Notes

### App Permissions
The T2T Admin app requires these permissions:
- **Camera** - For QR code scanning
- **Internet** - For Firebase connectivity
- **Storage** - For image selection

### Firebase Configuration
- The app is pre-configured with Firebase
- Make sure the `google-services.json` file is in `android/app/`
- Firebase services will work out of the box

### First-Time Setup
Users will need:
- Internet connection
- Admin credentials to log in
- Camera permission for QR scanning

---

## 🛠️ Troubleshooting

### App won't install
- **Solution:** Enable installation from unknown sources
- Check if there's enough storage space on the device

### App crashes on startup
- Make sure the device has Android 5.0 (API 21) or higher
- Check internet connection for Firebase

### Camera not working
- Grant camera permission in app settings
- Some devices may need additional permissions

---

## 📊 App Information

- **Package Name:** com.example.t2t_admin
- **Version:** 1.0.0 (Build 1)
- **Minimum Android Version:** Android 5.0 (API 21)
- **Target Android Version:** Latest
- **App Size:** 65.9 MB

---

## 🎯 Quick Start Command

To quickly copy APK to Desktop:
```powershell
Copy-Item "c:\Users\Vincent\Desktop\webpage\capstone\t2t\Super_User\t2t_admin\build\app\outputs\flutter-apk\app-release.apk" "$env:USERPROFILE\Desktop\t2t-admin.apk"
```

---

## 📝 Production Release Checklist

Before wide distribution:

- [ ] Update app version in `pubspec.yaml`
- [ ] Test on multiple Android devices
- [ ] Verify all features work (login, QR scan, dashboard)
- [ ] Check Firebase connectivity
- [ ] Create release notes
- [ ] Generate signed APK for production (optional)
- [ ] Test installation on fresh device
- [ ] Prepare user documentation
- [ ] Set up update notification system

---

## 🔐 Signing the APK (For Production)

Currently, the APK is signed with debug keys. For production distribution:

1. **Generate a keystore**
2. **Configure signing in `android/app/build.gradle.kts`**
3. **Rebuild with production signing**

Let me know if you need help with production signing!

---

**Your APK is ready to use! 🎉**

Simply navigate to the APK location and start distributing to your Android devices.
