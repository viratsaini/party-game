# 🏗️ How the APK Build Works — A Complete Beginner's Guide

> **Who is this for?** If you have never built an app before and have no idea what an APK is, this guide is for you. We explain everything from scratch — no prior knowledge needed.

---

## 📖 Table of Contents

1. [What Is an APK?](#-what-is-an-apk)
2. [The Big Picture — What Happens When You Change Code](#-the-big-picture--what-happens-when-you-change-code)
3. [Step-by-Step: The Automated Build Pipeline](#-step-by-step-the-automated-build-pipeline)
4. [What Triggers a Build?](#-what-triggers-a-build)
5. [The Build Process in Detail](#-the-build-process-in-detail)
6. [Where Does the APK Go After It's Built?](#-where-does-the-apk-go-after-its-built)
7. [How to Download Your APK](#-how-to-download-your-apk)
8. [Building Locally on Your Own Computer](#-building-locally-on-your-own-computer)
9. [Key Files That Control the Build](#-key-files-that-control-the-build)
10. [Troubleshooting Common Issues](#-troubleshooting-common-issues)
11. [Glossary — Terms Explained](#-glossary--terms-explained)

---

## 📱 What Is an APK?

An **APK** (Android Package Kit) is the file format Android uses to install apps. Think of it like a `.exe` file on Windows or a `.dmg` on Mac — it's the installer for your game.

When we say "build the APK", we mean:

> Take all the game code, images, sounds, and settings → package them together → create a single `.apk` file that any Android phone can install and run.

**Our APK:** `BattleZoneParty.apk` (~29 MB)

---

## 🖼️ The Big Picture — What Happens When You Change Code

Here's what happens every time someone updates the game code:

```
 You edit code on your computer
         │
         ▼
 You push the changes to GitHub
         │
         ▼
 GitHub detects the push automatically
         │
         ▼
 GitHub Actions (a robot) starts building the APK
         │
         ▼
 The robot downloads all the tools it needs
 (Godot engine, Java, Android SDK)
         │
         ▼
 The robot packages your game into an APK
         │
         ▼
 The APK is saved in two places:
   1. As a downloadable "Artifact" on GitHub
   2. Committed back into the repository
         │
         ▼
 Anyone can now download the latest APK! 🎉
```

**The entire process takes about 5–10 minutes** and happens 100% automatically — you don't need to press any buttons or install anything.

---

## 🔄 Step-by-Step: The Automated Build Pipeline

Let's walk through exactly what happens, one step at a time.

### Step 1: You Make a Code Change

You edit a file in the game — maybe you fix a bug, add a new feature, or change a texture. You save the file on your computer.

### Step 2: You Push to GitHub

Using Git (a version control tool), you upload your changes to the GitHub repository. This is called a "push". The command looks like:

```bash
git add .
git commit -m "Fixed player movement bug"
git push
```

### Step 3: GitHub Detects the Change

GitHub is always watching. The moment your code arrives, it checks a file called `.github/workflows/build-android.yml`. This file contains instructions that tell GitHub: *"Whenever new code arrives, build the APK."*

### Step 4: A Virtual Computer Spins Up

GitHub provides a free virtual computer (called a "runner") running Ubuntu Linux. This computer is brand new — it has nothing installed on it. Think of it like getting a fresh laptop with only the operating system.

### Step 5: The Build Robot Sets Up Its Tools

The runner downloads and installs everything it needs:

| Tool | What It Does | Why It's Needed |
|------|-------------|-----------------|
| **Godot 4.6.1** | The game engine | Packages the game into an APK |
| **Java 17** | Programming language runtime | Android apps need Java to build |
| **Android SDK** | Android development tools | Provides Android-specific build tools |
| **Export Templates** | Pre-built Godot engine for Android | The actual engine code that runs on phones |

### Step 6: Import Project Resources

The runner tells Godot to scan all the game files (images, sounds, scenes, scripts) and prepare them:

```bash
godot --headless --import --quit
```

- `--headless` means "run without showing a window" (this is a server with no screen)
- `--import` means "process all the game assets"
- `--quit` means "exit when done"

### Step 7: Build the APK

Now the magic happens. Godot takes everything and packages it into a single APK file:

```bash
godot --headless --export-debug "Android" export/BattleZoneParty.apk
```

This command says: *"Export the game using the 'Android' preset, and save it as `export/BattleZoneParty.apk`."*

During this step, Godot:
1. Compiles all GDScript code
2. Packs all game assets (textures, sounds, scenes)
3. Bundles the Godot engine (the part that runs on Android)
4. Signs the APK with a debug key (so Android trusts it)
5. Writes the final `.apk` file

### Step 8: The APK Is Saved

The finished APK is stored in two places:
1. **GitHub Artifacts** — a temporary download link (available for 30 days)
2. **Inside the repository** — committed back to the code so it's always available

---

## ⚡ What Triggers a Build?

Not every action triggers a build. Here are the three things that do:

### 1. Pushing Code to Specific Branches

| Branch | Build Triggered? |
|--------|-----------------|
| `main` | ✅ Yes |
| `claude/**` (e.g., `claude/fix-bug`) | ✅ Yes |
| Any other branch | ❌ No |

**Example:** If you push code to a branch called `claude/add-new-game`, the build starts automatically.

### 2. Opening or Updating a Pull Request to `main`

When you create a Pull Request (PR) — a request to merge your changes into the main code — the build runs to make sure your changes don't break the game.

> **Note:** When triggered by a PR, the APK is only uploaded as an Artifact. It is NOT committed back to the repository — that only happens when code is actually pushed to `main` or `claude/**`.

### 3. Manual Trigger (workflow_dispatch)

You can also start a build manually:
1. Go to the repository on GitHub
2. Click the **"Actions"** tab
3. Click **"Build Android APK"** on the left
4. Click the **"Run workflow"** button
5. Choose a branch and click **"Run workflow"**

This is useful if you want to rebuild without making code changes.

---

## 🔧 The Build Process in Detail

Here's a deeper look at every step the GitHub Actions workflow performs:

```
┌──────────────────────────────────────────────────────┐
│              GitHub Actions Workflow                  │
│              "Build Android APK"                     │
├──────────────────────────────────────────────────────┤
│                                                      │
│  1. 📥 Checkout Code                                 │
│     └─ Downloads the repository to the runner        │
│                                                      │
│  2. ☕ Set Up Java 17                                │
│     └─ Installs Temurin JDK 17                       │
│                                                      │
│  3. 💾 Cache Godot Files                             │
│     └─ Reuses previously downloaded Godot            │
│        files if available (speeds up builds)         │
│                                                      │
│  4. 🎮 Download Godot 4.6.1                         │
│     └─ Downloads the game engine binary              │
│        (only if not cached)                          │
│                                                      │
│  5. 📦 Download Export Templates                     │
│     └─ Gets Android-specific Godot templates         │
│        (the engine code that runs on phones)         │
│                                                      │
│  6. 📱 Set Up Android SDK                            │
│     └─ Installs Android development tools            │
│                                                      │
│  7. 🔨 Install Build Tools                           │
│     └─ build-tools 35.0.0                            │
│     └─ platforms android-34                           │
│     └─ cmdline-tools latest                           │
│     └─ NDK 25.2.9519653                              │
│                                                      │
│  8. 🔄 Import Project Resources                      │
│     └─ Godot scans and imports all game files        │
│                                                      │
│  9. 🏗️ Export Android APK                            │
│     └─ Packages everything into                      │
│        export/BattleZoneParty.apk                    │
│                                                      │
│ 10. ⬆️ Upload as Artifact                            │
│     └─ Makes APK downloadable from                   │
│        GitHub Actions (30 days)                      │
│                                                      │
│ 11. 💾 Commit APK to Repository                      │
│     └─ (Only on push to main/claude/**)              │
│     └─ Pushes the APK back into the repo             │
│        so it's always available                      │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 📍 Where Does the APK Go After It's Built?

The built APK ends up in two places:

### 1. GitHub Actions Artifacts (Always)

Every build creates a downloadable artifact:
- **Name:** `BattleZoneParty-Android-APK`
- **Retention:** Available for 30 days, then automatically deleted
- **Access:** Anyone with access to the repository can download it

### 2. Inside the Repository (Only for Push Events)

When code is pushed to `main` or `claude/**` branches:
- The APK is committed to `export/BattleZoneParty.apk`
- The commit message is: `"Update APK build [skip ci]"`
- The `[skip ci]` tag tells GitHub: *"Don't trigger another build for this commit"* (this prevents an infinite loop of build → commit → build → commit)

---

## 📥 How to Download Your APK

### Method 1: From GitHub Actions Artifacts

1. Go to the repository on GitHub
2. Click the **"Actions"** tab at the top
3. Click on the latest **"Build Android APK"** workflow run
4. Scroll down to the **"Artifacts"** section
5. Click **"BattleZoneParty-Android-APK"** to download

### Method 2: From the Repository

1. Go to the repository on GitHub
2. Navigate to the `export/` folder
3. Click on `BattleZoneParty.apk`
4. Click **"Download"**

### Method 3: Using Git

```bash
git clone https://github.com/viratsaini/party-game.git
# The APK is at: export/BattleZoneParty.apk
```

---

## 💻 Building Locally on Your Own Computer

If you want to build the APK on your own machine instead of waiting for GitHub Actions, you can use the PowerShell script (Windows only).

### Prerequisites

You need these installed on your computer:

1. **Godot 4.6.1** — Download from [godotengine.org](https://godotengine.org/)
2. **Java 17 (JDK)** — Download Eclipse Temurin from [adoptium.net](https://adoptium.net/)
3. **Android SDK** — Included with [Android Studio](https://developer.android.com/studio)
4. **Godot Export Templates** — Downloaded inside Godot Editor (Editor → Manage Export Templates)

### Build Command (Windows)

```powershell
# Navigate to the project folder
cd D:\game

# Run the build script
.\build_apk.ps1
```

The script will:
1. Check that all tools are installed
2. Import the project resources
3. Build the APK
4. Report the APK file size
5. Tell you how to install it on a device

### Build Command (Linux/Mac)

```bash
# Make sure Godot is installed and in your PATH

# Step 1: Import project resources
godot --headless --import --quit

# Step 2: Build the APK
mkdir -p export
godot --headless --export-debug "Android" export/BattleZoneParty.apk

# Step 3: Check the result
ls -la export/BattleZoneParty.apk
```

---

## 📂 Key Files That Control the Build

| File | What It Does |
|------|-------------|
| `.github/workflows/build-android.yml` | The automated build instructions for GitHub Actions |
| `export_presets.cfg` | Tells Godot HOW to export (package name, version, architecture, signing) |
| `project.godot` | Main Godot project file (game name, main scene, engine version) |
| `debug.keystore` | The signing key used to sign the APK (required by Android) |
| `build_apk.ps1` | PowerShell script for building locally on Windows |
| `android/build/build.gradle` | Android Gradle build configuration (SDK versions, dependencies) |
| `android/build/config.gradle` | Gradle version numbers and helper functions |

### What's in `export_presets.cfg`?

This file tells Godot exactly how to build the APK:

| Setting | Value | Meaning |
|---------|-------|---------|
| Package name | `com.battlezone.party` | The unique ID for the app on Android |
| Version name | `0.1.1` | The version shown to users |
| Architecture | `arm64-v8a` | Built for modern 64-bit ARM phones |
| Min Android | SDK 21 (5.0) | Works on Android 5.0 and above |
| Target SDK | 34 | Optimized for Android 14 |
| Export path | `export/BattleZoneParty.apk` | Where the APK file is saved |

---

## 🛠️ Troubleshooting Common Issues

### The build failed — what do I do?

1. Go to the **Actions** tab on GitHub
2. Click on the failed workflow run (it will have a red ❌)
3. Click on the **"Build Android APK"** job
4. Read the logs to find the error message
5. Common errors and fixes:

| Error | Cause | Fix |
|-------|-------|-----|
| "Export template not found" | Godot couldn't find Android templates | Check the Godot version matches the templates |
| "No export presets found" | `export_presets.cfg` is missing or broken | Ensure the file exists in the project root |
| "Java not found" | JDK 17 is not installed | The workflow should install it automatically |
| "APK not found after export" | The export command failed silently | Check the full build log for Godot errors |

### I changed code but no build started

- Make sure you pushed to `main` or a `claude/**` branch
- Other branches don't trigger automatic builds
- You can always trigger a build manually from the Actions tab

### The APK doesn't install on my phone

- Make sure "Install from unknown sources" is enabled in your phone settings
- Make sure your phone is ARM64 (most modern phones are)
- Make sure your Android version is 5.0 or higher

---

## 📚 Glossary — Terms Explained

| Term | What It Means |
|------|--------------|
| **APK** | Android Package Kit — the file format used to install apps on Android |
| **Build** | The process of turning source code into a runnable application |
| **CI/CD** | Continuous Integration / Continuous Delivery — automatically building and testing code |
| **GitHub Actions** | GitHub's built-in automation service that runs tasks when code changes |
| **Workflow** | A set of automated steps defined in a YAML file |
| **Runner** | A virtual computer provided by GitHub that executes the workflow |
| **Artifact** | A file produced by a workflow that can be downloaded |
| **Godot** | The open-source game engine used to build BattleZone Party |
| **GDScript** | Godot's built-in scripting language (similar to Python) |
| **Export Template** | Pre-compiled Godot engine binaries for a target platform (Android, iOS, etc.) |
| **Android SDK** | Software Development Kit — tools needed to build Android apps |
| **NDK** | Native Development Kit — tools for building native C/C++ code for Android |
| **JDK** | Java Development Kit — Java tools needed for Android builds |
| **Gradle** | A build tool used by Android projects to manage dependencies and compilation |
| **Keystore** | A file containing cryptographic keys used to sign the APK |
| **Debug build** | A build meant for testing (not optimized, includes debug info) |
| **Release build** | A build meant for distribution (optimized, signed with a release key) |
| **Branch** | A separate version of the code (like a parallel universe for your code) |
| **Push** | Uploading your local code changes to GitHub |
| **Pull Request (PR)** | A request to merge your branch's changes into another branch |
| **Commit** | A saved snapshot of code changes with a description |
| **Cache** | Storing downloaded files so they don't need to be downloaded again |
| **Headless** | Running a program without a graphical interface (no window) |
| **`[skip ci]`** | A tag in a commit message that tells GitHub Actions to NOT trigger a build |
| **ARM64 / arm64-v8a** | The CPU architecture used by most modern Android phones |
| **SDK version** | A number representing an Android version (e.g., SDK 34 = Android 14) |

---

## 🔗 Related Documentation

- [BUILD_SUCCESS.md](../BUILD_SUCCESS.md) — Build status and APK details
- [DOWNLOAD_APK.md](../DOWNLOAD_APK.md) — APK download and installation guide
- [ARCHITECTURE.md](ARCHITECTURE.md) — System architecture overview
- [API_REFERENCE.md](API_REFERENCE.md) — Complete API documentation
- [COMPONENT_GUIDE.md](COMPONENT_GUIDE.md) — UI and game component guide
