param([string]$Phone='37220DLJG001ML',[switch]$Install)
$ErrorActionPreference='Stop'
$kinRoot=Split-Path $PSScriptRoot -Parent
$kinSdk=Join-Path $env:LOCALAPPDATA 'Android/Sdk'
$kinAdb=Join-Path $kinSdk 'platform-tools/adb.exe'
$kinWatch='emulator-5556'
if(!((& $kinAdb devices) -match '^emulator-5556\s+device')) {
    Start-Process -FilePath (Join-Path $kinSdk 'emulator/emulator.exe') -ArgumentList '-avd PocketKin_Wear_API34 -port 5556 -no-boot-anim' -WindowStyle Hidden
    & $kinAdb -s $kinWatch wait-for-device
    for($attempt=0;$attempt -lt 90;$attempt++) {
        if((& $kinAdb -s $kinWatch shell getprop sys.boot_completed).Trim() -eq '1'){break}
        Start-Sleep -Seconds 2
    }
}
& $kinAdb -s $Phone forward tcp:5601 tcp:5601
& $kinAdb -s $kinWatch reverse tcp:5601 tcp:5601
& $kinAdb -s $Phone forward tcp:8765 tcp:8765
& $kinAdb -s $kinWatch reverse tcp:8765 tcp:8765
if($Install) {
    & $kinAdb -s $Phone install -r (Join-Path $kinRoot 'android/phone/build/outputs/apk/debug/phone-debug.apk')
    if($LASTEXITCODE -ne 0){throw 'Phone install failed. Do not erase an existing pet to change certificates.'}
    & $kinAdb -s $kinWatch install -r (Join-Path $kinRoot 'android/wear/build/outputs/apk/debug/wear-debug.apk')
    if($LASTEXITCODE -ne 0){throw 'Watch install failed. Check that both APKs use the same signing certificate.'}
}
& $kinAdb -s $Phone shell am start -n com.pocketkin.game/.MainActivity
& $kinAdb -s $kinWatch shell am start -n com.pocketkin.game/.WatchActivity
Write-Output 'Watch emulator running. USB forwarding lasts until ADB restarts or the phone disconnects. Run this script again to reconnect.'
