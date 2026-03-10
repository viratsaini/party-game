# BattleZone Party - Android APK Build Script
# Run this in PowerShell from the d:\game directory after all setup is complete
#
# Prerequisites (already installed):
#   - Godot 4.6.1 (via winget)
#   - JDK 17 (Eclipse Temurin via winget)
#   - Android SDK with platform 34 (C:\Users\virat\AppData\Local\Android\Sdk)
#   - Debug keystore (d:\game\debug.keystore)
#   - Export templates (extracted to AppData\Roaming\Godot\export_templates\4.6.1.stable)

$ErrorActionPreference = "Stop"

# --- Paths ---
$godotExe = "C:\Users\virat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe"
$projectDir = "D:\game"
$outputApk  = "$projectDir\export\BattleZoneParty.apk"
$jdk17      = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"

# --- Set JAVA_HOME for Godot ---
$env:JAVA_HOME = $jdk17
$env:PATH = "$jdk17\bin;$env:PATH"

Write-Host "============================================"
Write-Host "  BattleZone Party - APK Builder"
Write-Host "============================================"
Write-Host ""
Write-Host "Godot:   $godotExe"
Write-Host "Project: $projectDir"
Write-Host "Output:  $outputApk"
Write-Host "JDK 17:  $jdk17"
Write-Host ""

# --- Verify prerequisites ---
if (-not (Test-Path $godotExe)) { Write-Error "Godot not found at $godotExe"; exit 1 }
if (-not (Test-Path "$projectDir\project.godot")) { Write-Error "project.godot not found"; exit 1 }
if (-not (Test-Path "$projectDir\debug.keystore")) { Write-Error "debug.keystore not found"; exit 1 }

$templatesDir = "$env:APPDATA\Godot\export_templates\4.6.1.stable"
if (-not (Test-Path "$templatesDir\android_debug.apk")) {
    Write-Error "Android export templates not found at $templatesDir. Run setup first."
    exit 1
}

Write-Host "All prerequisites verified!" -ForegroundColor Green
Write-Host ""

# --- Create output dir ---
New-Item -ItemType Directory -Force -Path "$projectDir\export" | Out-Null

# --- Import project first (generates .godot/ cache) ---
Write-Host "Importing project resources..."
& $godotExe --headless --path $projectDir --import 2>&1 | Out-Null
Write-Host "Import complete." -ForegroundColor Green

# --- Export APK ---
Write-Host ""
Write-Host "Exporting Android APK..."
Write-Host "This may take 1-3 minutes..."
Write-Host ""

& $godotExe --headless --path $projectDir --export-debug "Android" $outputApk 2>&1

if (Test-Path $outputApk) {
    $size = (Get-Item $outputApk).Length / 1MB
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  APK BUILT SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  Output: $outputApk" -ForegroundColor Green
    Write-Host "  Size:   $([math]::Round($size, 1)) MB" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "To install on your phone:"
    Write-Host "  1. Connect phone via USB (enable USB Debugging)"
    Write-Host "  2. Run:  adb install `"$outputApk`""
    Write-Host ""
    Write-Host "Or copy the APK file to your phone and install manually."
} else {
    Write-Host ""
    Write-Host "ERROR: APK was not created. Check the output above for errors." -ForegroundColor Red
    exit 1
}
