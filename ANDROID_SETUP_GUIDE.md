# 🔧 Fix: Android Device Not Detected in Flutter

## Problem
Your mobile phone is connected but not showing in `flutter devices` because **Android SDK is not installed**.

---

## ✅ Solution: Install Android Studio (Includes Android SDK)

### Step 1: Download Android Studio

1. **Go to:** https://developer.android.com/studio
2. **Click "Download Android Studio"**
3. **Wait for download** (about 1GB)

### Step 2: Install Android Studio

1. **Run the installer** (`android-studio-*.exe`)
2. **Click "Next"** through the setup wizard
3. **Choose installation location** (default is fine)
4. **Click "Install"** and wait for installation
5. **Click "Finish"** - Android Studio will launch

### Step 3: First-Time Setup

1. **When Android Studio opens:**
   - Choose "Standard" installation type
   - Click "Next" → "Next" → "Finish"
   - **Wait for SDK components to download** (10-20 minutes)
   - This will install Android SDK automatically

2. **During installation, it will download:**
   - Android SDK
   - Android SDK Platform-Tools (includes ADB)
   - Android SDK Build-Tools
   - Android Emulator (optional)

### Step 4: Configure Flutter to Use Android SDK

After Android Studio finishes installing SDK components:

1. **Note the SDK location:**
   - Usually: `C:\Users\YourName\AppData\Local\Android\Sdk`
   - Or: `C:\Android\Sdk` (if you chose custom location)

2. **Configure Flutter:**
   ```bash
   # Replace with your actual SDK path if different
   flutter config --android-sdk "%LOCALAPPDATA%\Android\Sdk"
   ```

3. **Verify setup:**
   ```bash
   flutter doctor
   ```
   You should now see ✅ for Android toolchain!

---

## 📱 Step 5: Enable USB Debugging on Your Phone

### For Android Phone:

1. **Enable Developer Options:**
   - Go to **Settings → About Phone**
   - Find **"Build Number"** (may be under "Software Information")
   - **Tap Build Number 7 times** until you see "You are now a developer!"

2. **Enable USB Debugging:**
   - Go to **Settings → Developer Options** (now visible)
   - **Turn ON "USB Debugging"**
   - Turn ON **"Stay Awake"** (optional, keeps screen on while charging)

3. **Connect Phone:**
   - Connect phone to laptop via USB cable
   - On phone: Select **"File Transfer"** or **"MTP"** mode when prompted
   - You may see: **"Allow USB debugging?"** → Tap **"Allow"** and check **"Always allow from this computer"**

---

## 🔌 Step 6: Install USB Drivers (If Needed)

### For Windows:

**If your phone is still not detected after enabling USB debugging:**

1. **Find your phone manufacturer:**
   - **Samsung:** Install [Samsung USB Drivers](https://developer.samsung.com/mobile/android-usb-driver.html)
   - **Xiaomi:** Install Mi USB Drivers (via Mi PC Suite)
   - **Huawei:** Install HiSuite
   - **OnePlus:** Install OnePlus USB Drivers
   - **Google Pixel:** Usually works automatically
   - **Other brands:** Install [Google USB Driver](https://developer.android.com/studio/run/win-usb)

2. **After installing drivers:**
   - **Restart your computer**
   - **Unplug and reconnect** your phone
   - **Check USB debugging authorization** on your phone again

---

## ✅ Step 7: Verify Device Detection

### Check ADB (Android Debug Bridge):

```bash
# Find ADB path (after Android Studio installs SDK)
# Usually: C:\Users\YourName\AppData\Local\Android\Sdk\platform-tools\adb.exe

# Add to PATH or use full path
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices
```

**You should see:**
```
List of devices attached
R58M90ABCDE    device
```

If you see **"unauthorized"**: Check your phone for the USB debugging popup and tap "Allow"

### Check Flutter Devices:

```bash
flutter devices
```

**You should now see:**
```
2 connected devices:
SM-G991B (mobile) • R58M90ABCDE • android-arm64 • Android 13
Windows (desktop) • windows • windows-x64 • Microsoft Windows [Version 10.0.19045.6466]
```

---

## 🚀 Step 8: Run Your App

Once your device is detected:

```bash
cd App
flutter run
```

Or specify your device:
```bash
flutter run -d R58M90ABCDE
```

---

## 🐛 Troubleshooting

### "ADB not found" or "adb: command not found"?

1. **Add Android SDK Platform-Tools to PATH:**
   - Press `Win + R`, type `sysdm.cpl`, press Enter
   - Click **"Environment Variables"**
   - Under **"System Variables"**, find **"Path"**, click **"Edit"**
   - Click **"New"** and add:
     ```
     C:\Users\YourName\AppData\Local\Android\Sdk\platform-tools
     ```
   - Click **"OK"** on all windows
   - **Restart your terminal/PowerShell**

2. **Or use full path:**
   ```bash
   "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices
   ```

### Device shows as "unauthorized"?

- **On your phone:** Look for the USB debugging authorization popup
- Tap **"Allow"** and check **"Always allow from this computer"**
- If popup doesn't appear:
  - Go to **Settings → Developer Options → Revoke USB debugging authorizations**
  - Disconnect and reconnect USB cable

### Still not detected?

1. **Try different USB cable** (some are charge-only)
2. **Try different USB port** (prefer USB 3.0 ports)
3. **Check USB connection mode** on phone (should be File Transfer/MTP)
4. **Restart ADB:**
   ```bash
   "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" kill-server
   "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" start-server
   "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices
   ```

### Flutter Doctor still shows "Unable to locate Android SDK"?

1. **Find your SDK path:**
   - Open Android Studio
   - Go to **File → Settings → Appearance & Behavior → System Settings → Android SDK**
   - Copy the **"Android SDK Location"** path

2. **Configure Flutter:**
   ```bash
   flutter config --android-sdk "YOUR_SDK_PATH_HERE"
   ```

3. **Verify:**
   ```bash
   flutter doctor -v
   ```

---

## 📋 Quick Checklist

- [ ] Download and install Android Studio
- [ ] Complete first-time setup (SDK components will download)
- [ ] Enable Developer Options on phone (tap Build Number 7 times)
- [ ] Enable USB Debugging on phone
- [ ] Connect phone via USB
- [ ] Allow USB debugging authorization on phone
- [ ] Install USB drivers if needed
- [ ] Verify `adb devices` shows your phone
- [ ] Verify `flutter devices` shows your phone
- [ ] Run `flutter run` to deploy app

---

## ⏱️ Estimated Time

- **Android Studio download:** 5-10 minutes
- **Android Studio installation:** 5-10 minutes
- **SDK components download:** 10-20 minutes
- **Phone setup:** 2-5 minutes
- **Total:** ~30-45 minutes

---

## 🎯 Once Everything is Set Up

You'll be able to:
- See your phone in `flutter devices`
- Run apps directly on your phone with `flutter run`
- Debug apps using Flutter DevTools
- Test on real hardware instead of emulator

**Good luck! Let me know if you need help with any step.** 🚀
