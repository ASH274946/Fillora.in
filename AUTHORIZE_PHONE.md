# 🔓 How to Authorize Your Phone in Android Studio

## ✅ Good News!
Your phone is **detected** but needs **authorization**. Device ID: `00195658T001904`

---

## 📱 Step-by-Step: Authorize Your Phone

### Step 1: Check Your Phone Screen

**Look at your phone right now** - you should see a popup that says:

```
Allow USB debugging?
The computer's RSA key fingerprint is: [some numbers/letters]

[ ] Always allow from this computer
[Cancel]  [OK]
```

### Step 2: Authorize the Connection

1. **Check the box** ☑️ **"Always allow from this computer"**
   - This will remember your laptop so you don't have to do this every time

2. **Tap "OK"** or **"Allow"**

### Step 3: If You Don't See the Popup

**Try these steps:**

1. **Unlock your phone** (popup may only appear when unlocked)

2. **Disconnect and reconnect the USB cable:**
   - Unplug the USB cable from your laptop
   - Wait 2 seconds
   - Plug it back in
   - Check your phone screen again

3. **Revoke and re-authorize:**
   - On your phone: **Settings → Developer Options → Revoke USB debugging authorizations**
   - Tap **"Revoke"** or **"OK"**
   - Disconnect and reconnect USB cable
   - You should see the popup again

4. **Check USB connection mode:**
   - Pull down notification panel on phone
   - Look for USB notification
   - Tap it and select **"File Transfer"** or **"MTP"** mode
   - Not "Charging only" mode

---

## ✅ Step 4: Verify Authorization

After you tap "Allow" on your phone, come back here and run:

```bash
flutter devices
```

**You should now see:**
```
Found 4 connected devices:
00195658T001904 (mobile) • 00195658T001904 • android-arm64 • Android [version]
Windows (desktop) • windows • windows-x64 • ...
Chrome (web) • chrome • web-javascript • ...
Edge (web) • edge • web-javascript • ...
```

**Notice:** The device now shows as `(mobile)` instead of "unauthorized"!

---

## 🎯 Step 5: Add Device to Android Studio Device Manager (Optional)

**Your device will automatically appear in Android Studio once authorized!**

To view it:
1. **Open Android Studio**
2. **Go to:** View → Tool Windows → Device Manager
   - Or click the **Device Manager** tab on the right side
3. Your phone should appear under **"Physical Devices"** section

---

## 🚀 Step 6: Run Your App

Once authorized, you can run your app:

```bash
cd App
flutter run -d 00195658T001904
```

Or simply:
```bash
flutter run
```
(Flutter will auto-select your phone if it's the only Android device)

---

## 🐛 Troubleshooting

### Still showing "unauthorized"?

**Try restarting ADB:**

```bash
# Find your ADB path (usually in Android SDK)
%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe kill-server
%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe start-server
%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices
```

**Then check your phone again** - the popup might reappear.

### Device disappeared after authorization?

- Make sure USB cable is still connected
- Make sure USB debugging is still enabled
- Try unplugging and replugging the cable

### Can't find Developer Options?

1. **Go to:** Settings → About Phone
2. **Find "Build Number"** (might be under "Software Information")
3. **Tap Build Number 7 times** until you see "You are now a developer!"
4. **Go back to Settings** → You'll now see **"Developer Options"**
5. **Enable "USB Debugging"**

---

## ✅ Quick Checklist

- [ ] Phone is unlocked
- [ ] USB cable is connected
- [ ] USB debugging is enabled on phone
- [ ] I see the "Allow USB debugging?" popup on my phone
- [ ] I checked "Always allow from this computer"
- [ ] I tapped "Allow" or "OK"
- [ ] `flutter devices` now shows my phone as authorized

---

## 📱 What the Authorization Popup Looks Like

```
┌─────────────────────────────────┐
│  Allow USB debugging?           │
│                                 │
│  The computer's RSA key         │
│  fingerprint is:                │
│  AB:CD:EF:12:34:56:78:90:...   │
│                                 │
│  ☐ Always allow from this       │
│    computer                     │
│                                 │
│  [Cancel]          [OK]         │
└─────────────────────────────────┘
```

**Make sure to check the box and tap OK!**

---

**Once you authorize on your phone, come back and run `flutter devices` to verify!** 🚀
