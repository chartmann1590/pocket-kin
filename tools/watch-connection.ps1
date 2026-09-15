param([string]$Phone='37220DLJG001ML',[int]$Hours=8)
$kinAdb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$kinUntil=(Get-Date).AddHours($Hours)
$kinLog=Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts/watch-connection.log'
while((Get-Date) -lt $kinUntil) {
    $kinDevices=& $kinAdb devices 2>$null
    if($kinDevices -match 'emulator-5556\s+offline') {
        & $kinAdb connect 127.0.0.1:5557 | Out-Null
    }
    if(($kinDevices -match "^$Phone\s+device") -and ($kinDevices -match '^emulator-5556\s+device')) {
        $kinForward=& $kinAdb forward --list
        if(-not($kinForward -match "^$Phone tcp:5601 tcp:5601")) {
            & $kinAdb -s $Phone forward tcp:5601 tcp:5601 | Out-Null
            Add-Content $kinLog "$(Get-Date -Format o) Restored Pixel USB tunnel 5601"
        }
        if(-not($kinForward -match "^$Phone tcp:8765 tcp:8765")) {
            & $kinAdb -s $Phone forward tcp:8765 tcp:8765 | Out-Null
            Add-Content $kinLog "$(Get-Date -Format o) Restored Pixel USB tunnel 8765"
        }
        $kinReverse=& $kinAdb -s emulator-5556 reverse --list
        if(-not($kinReverse -match 'tcp:5601 tcp:5601')) {
            & $kinAdb -s emulator-5556 reverse tcp:5601 tcp:5601 | Out-Null
            Add-Content $kinLog "$(Get-Date -Format o) Restored watch USB tunnel 5601"
        }
        if(-not($kinReverse -match 'tcp:8765 tcp:8765')) {
            & $kinAdb -s emulator-5556 reverse tcp:8765 tcp:8765 | Out-Null
            Add-Content $kinLog "$(Get-Date -Format o) Restored watch USB tunnel 8765"
        }
    }
    Start-Sleep -Seconds 5
}
