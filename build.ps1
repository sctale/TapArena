$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$www = Join-Path $root 'www'
$assets = Join-Path $root 'android\app\src\main\assets\www'

Write-Host '[1/4] Copy HTML game into Android assets'
if (Test-Path $assets) { Remove-Item $assets -Recurse -Force }
New-Item -ItemType Directory -Force -Path $assets | Out-Null
Copy-Item (Join-Path $www '*') $assets -Recurse -Force

$jdk = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path (Join-Path $jdk 'bin\java.exe')) { $env:JAVA_HOME = $jdk }

$gradleFile = Join-Path $root 'android\app\build.gradle'
$gradleText = Get-Content $gradleFile -Raw
$version = '1.0.0'
if ($gradleText -match "versionName\s+'([^']+)'") { $version = $matches[1] }

Write-Host '[2/4] Build signed release APK'
Push-Location (Join-Path $root 'android')
try {
    & .\gradlew.bat assembleRelease --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "gradle failed: $LASTEXITCODE" }
} finally {
    Pop-Location
}

$src = Join-Path $root 'android\app\build\outputs\apk\release\app-release.apk'
$dest = Join-Path $root ("TapArena-v{0}.apk" -f $version)
if (!(Test-Path $src)) { throw "APK not found: $src" }
Copy-Item $src $dest -Force

Write-Host '[3/4] Verify signature'
$bt = Join-Path $env:ANDROID_HOME 'build-tools\36.0.0'
& (Join-Path $bt 'apksigner.bat') verify --print-certs $dest
if ($LASTEXITCODE -ne 0) { throw 'apksigner verify failed' }

Write-Host '[4/4] Dump manifest'
& (Join-Path $bt 'aapt2.exe') dump badging $dest | Select-String -Pattern "package:|application-label:|launchable-activity:|sdkVersion:|targetSdkVersion:"
Get-FileHash $dest -Algorithm SHA256 | Format-List
Write-Host ("Done: " + $dest)
