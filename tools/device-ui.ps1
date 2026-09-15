param([string]$Serial='37220DLJG001ML')
$kinAdb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
& $kinAdb -s $Serial shell uiautomator dump /sdcard/kin-ui.xml | Out-Null
$kinXml=& $kinAdb -s $Serial shell cat /sdcard/kin-ui.xml
([xml]$kinXml).SelectNodes('//node') | Where-Object { $_.text -or $_.'content-desc' } | Select-Object text,content-desc,bounds | Format-Table -AutoSize -Wrap
