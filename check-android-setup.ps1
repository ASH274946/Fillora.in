# Android Setup Verification Script
# Run this script after installing Android Studio

Write-Host "`n🔍 Checking Android SDK Setup...`n" -ForegroundColor Cyan

# Check for Android SDK
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
$sdkExists = Test-Path $sdkPath

if ($sdkExists) {
    Write-Host "✅ Android SDK found at: $sdkPath" -ForegroundColor Green
    
    # Check for ADB
    $adbPath = Join-Path $sdkPath "platform-tools\adb.exe"
    if (Test-Path $adbPath) {
        Write-Host "✅ ADB found: $adbPath" -ForegroundColor Green
        
        Write-Host "`n📱 Checking connected devices...`n" -ForegroundColor Cyan
        & $adbPath devices
    } else {
        Write-Host "❌ ADB not found. Make sure Android SDK Platform-Tools is installed." -ForegroundColor Red
        Write-Host "   In Android Studio: Tools → SDK Manager → SDK Tools → Android SDK Platform-Tools" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Android SDK not found at: $sdkPath" -ForegroundColor Red
    Write-Host "`n📥 Please install Android Studio first:" -ForegroundColor Yellow
    Write-Host "   1. Download from: https://developer.android.com/studio" -ForegroundColor White
    Write-Host "   2. Install Android Studio" -ForegroundColor White
    Write-Host "   3. Complete first-time setup (SDK will be downloaded automatically)" -ForegroundColor White
    Write-Host "   4. Run this script again to verify setup`n" -ForegroundColor White
}

# Check Flutter Android configuration
Write-Host "`n🔍 Checking Flutter configuration...`n" -ForegroundColor Cyan
flutter doctor -v | Select-String -Pattern "Android"

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Make sure USB debugging is enabled on your phone" -ForegroundColor White
Write-Host "   2. Connect your phone via USB" -ForegroundColor White
Write-Host "   3. Allow USB debugging authorization on your phone" -ForegroundColor White
Write-Host "   4. Run: flutter devices" -ForegroundColor White
Write-Host "   5. Run: flutter run" -ForegroundColor White
Write-Host ""
