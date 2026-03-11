# 🎮 BattleZone Party - APK Download & Installation Guide

## 📦 Download the APK

Your game APK has been successfully built and is ready for download!

**File Location:** `export/BattleZoneParty.apk`
**File Size:** 29 MB
**Version:** 0.1.0
**Build Type:** Debug (signed with debug keystore)

## 📱 How to Install on Your Android Device

### Method 1: Direct Download (Recommended)

1. **Download the APK:**
   - Navigate to the `export/` folder in this repository
   - Download `BattleZoneParty.apk` to your Android device
   - You can download it via GitHub's web interface or clone the repository

2. **Enable Installation from Unknown Sources:**
   - Go to **Settings** → **Security** (or **Privacy**)
   - Enable **"Install unknown apps"** for your browser or file manager
   - On newer Android versions (8.0+), you'll be prompted when you try to install

3. **Install the APK:**
   - Open your **Files** app or **Downloads** folder
   - Tap on `BattleZoneParty.apk`
   - Follow the on-screen instructions to install
   - Tap **Install** when prompted

4. **Launch the Game:**
   - Find "BattleZone Party" in your app drawer
   - Tap to launch and enjoy!

### Method 2: USB Installation (Using ADB)

If you have Android Debug Bridge (ADB) installed on your computer:

```bash
# Connect your Android device via USB
# Enable USB Debugging on your device first

# Install the APK
adb install export/BattleZoneParty.apk

# Or if you get an error, use force install
adb install -r export/BattleZoneParty.apk
```

### Method 3: Download from GitHub Actions

If this APK was built by GitHub Actions:

1. Go to the **Actions** tab in this repository
2. Find the latest successful workflow run
3. Download the APK from the **Artifacts** section
4. Extract the zip file
5. Transfer `BattleZoneParty.apk` to your Android device
6. Follow steps 2-4 from Method 1 above

## 🎮 Game Features

**BattleZone Party** is a local multiplayer 3D party game with:

- 🎯 **5 Action-Packed Mini-Games**
- 🌐 **Multiple Connection Options:**
  - WiFi LAN
  - Bluetooth
  - Internet (online play)
- 👥 **Up to 4 Players**
- 🎨 **Premium UI/UX** with AAA-quality animations
- 📱 **Mobile-Optimized** controls and performance

## 🎮 Mini-Games Included:

1. **Battle Royale** - Last player standing wins
2. **Capture the Flag** - Team-based objective gameplay
3. **Racing** - Speed through checkpoints
4. **Jetpack Arena** - Aerial combat with jetpacks
5. **Survival Mode** - Survive waves of challenges

## ⚙️ System Requirements

- **Android Version:** 5.0 (Lollipop) or higher
- **Architecture:** ARM64 (arm64-v8a)
- **Storage:** 50 MB free space
- **RAM:** 2 GB minimum, 4 GB recommended
- **Network:** WiFi or mobile data for online multiplayer

## 🔧 Troubleshooting

### "App not installed" error
- **Solution:** Make sure you have enough storage space and enabled installation from unknown sources

### "Parse error" message
- **Solution:** Your device might not support this app. Check that you have Android 5.0+

### Game crashes on launch
- **Solution:**
  1. Clear the app's cache and data
  2. Restart your device
  3. Reinstall the app
  4. Make sure your Android is updated

### Can't connect to other players
- **Solution:**
  1. Ensure all devices are on the same WiFi network
  2. Check that the required permissions are granted:
     - Internet access
     - Network state
     - WiFi state
     - Bluetooth (if using Bluetooth mode)
  3. Disable VPN if active
  4. Check firewall settings

## 🔒 Permissions Required

The app requires these permissions:

- **Internet** - For online multiplayer
- **Network State** - To check connection status
- **WiFi State** - For local WiFi multiplayer
- **Bluetooth** - For Bluetooth multiplayer
- **Nearby Devices** - For discovering nearby players

## 📝 Notes

- This is a **DEBUG BUILD** signed with a debug keystore
- For production release, rebuild with a release keystore
- The APK includes all game assets and is ready to play offline (single device)
- Multiplayer requires network connectivity

## 🎯 Quick Start Guide

1. **Install the app** using one of the methods above
2. **Launch BattleZone Party**
3. **Choose a game mode:**
   - **Host a Game** - Create a lobby for others to join
   - **Join a Game** - Connect to an existing lobby
   - **Tutorial** - Learn how to play
4. **Select your mini-game** and start playing!

## 🌟 Features Highlights

### Premium UI/UX
- AAA-quality animations (Valorant/Apex Legends standard)
- Smooth 60 FPS performance
- Advanced shader effects
- Cinematic transitions
- Premium tooltips and feedback

### Accessibility
- WCAG AAA compliant
- Colorblind-safe palettes
- Touch-optimized controls
- Adaptive performance scaling

### Mobile Optimizations
- Battery-aware effects
- Adaptive quality system
- Device tier detection
- Optimized memory usage

## 🐛 Found a Bug?

If you encounter any issues:

1. Note the Android version and device model
2. Describe what you were doing when the issue occurred
3. Check if the issue persists after reinstalling
4. Report the issue in the repository's Issues section

## 🎊 Enjoy the Game!

Thank you for playing **BattleZone Party**!

Gather your friends, connect your devices, and battle it out in this epic mobile multiplayer experience!

---

**Built with:** Godot 4.6.1
**License:** Check repository LICENSE file
**Version:** 0.1.0 (Debug Build)
**Build Date:** March 11, 2026
