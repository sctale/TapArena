# 萌兽峡谷 TapArena — Godot 本地构建脚本
# 用法：powershell -ExecutionPolicy Bypass -File .\tools\godot-build.ps1
# 流程：生成导出预设 -> 导入资产 -> 无头规则回归 -> 导出 Android release -> aapt/apksigner 校验 -> 复制根目录 APK

param(
    [int]$VersionCode = 34,
    [switch]$SkipSim
)

$ErrorActionPreference = "Stop"

$Repo = "D:\V-Coding\TapArena"
$Proj = Join-Path $Repo "godot"
$Godot = "godot"
$AndroidSdk = "C:\Users\HAOHAO\AppData\Local\Android\Sdk"
$JavaHome = "C:\Program Files\Eclipse Adoptium\jdk-17.0.19+10"
$BuildTools = Join-Path $AndroidSdk "build-tools\36.0.0"
$KeystoreProps = Join-Path $Repo "keystore.properties"
$KeystoreSrc = Join-Path $Repo "keystore\taparena-release.keystore"
$KeystoreDst = Join-Path $Proj "keystore\taparena-release.keystore"

function Read-Utf8([string]$path) {
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8NoBom([string]$path, [string]$text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $text, $enc)
}

function Invoke-Godot([string[]]$argsList) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $Godot @argsList 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    Write-Host $out
    if ($code -ne 0) {
        throw "godot 退出码 $code"
    }
    return $out
}

# 1. 版本号与签名信息
$projectText = Read-Utf8 (Join-Path $Proj "project.godot")
if ($projectText -notmatch 'config/version="([^"]+)"') {
    throw "无法从 project.godot 读取 config/version"
}
$Version = $matches[1]

$props = @{}
foreach ($line in [System.IO.File]::ReadAllLines($KeystoreProps, [System.Text.Encoding]::UTF8)) {
    if ($line -match '^(.*?)=(.*)$') {
        $props[$matches[1].Trim()] = $matches[2].Trim()
    }
}
if (-not $props.ContainsKey("storePassword") -or -not $props.ContainsKey("keyAlias")) {
    throw "keystore.properties 缺少 storePassword / keyAlias"
}
$KeyAlias = $props["keyAlias"]
$StorePwd = $props["storePassword"]

if (-not (Test-Path $KeystoreDst)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $KeystoreDst) | Out-Null
    Copy-Item $KeystoreSrc $KeystoreDst -Force
}

Write-Host "==> 版本 $Version / versionCode $VersionCode" -ForegroundColor Cyan

# 2. 生成导出预设（含签名密码，文件已 gitignore）
$presetText = @"
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="build/*,.godot/*,tests/*,keystore/*"
export_path="build/windows/TapArena.exe"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=true
application/icon="res://assets/icons/app_icon.png"
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version="4.0.0.0"
application/product_version="4.0.0.0"
application/company_name="sctale"
application/product_name="萌兽峡谷 TapArena"
application/file_description="TapArena Godot vertical slice"
application/copyright=""
application/trademarks=""
application/export_angle=0
application/export_d3d12=0
application/d3d12_agility_sdk_multiarch=true
ssh_remote_deploy/enabled=false

[preset.1]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="build/*,.godot/*,tests/*,keystore/*"
export_path="build/android/TapArena.apk"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=$VersionCode
version/name="$Version"
package/unique_name="com.sctale.taparena"
package/name="萌兽峡谷"
package/signed=true
keystore/debug=""
keystore/debug_user=""
keystore/debug_password=""
keystore/release="res://keystore/taparena-release.keystore"
keystore/release_user="$KeyAlias"
keystore/release_password="$StorePwd"
package/app_category=2
package/retain_data_on_uninstall=false
package/exclude_from_recents=false
package/show_in_android_tv=false
package/show_in_app_library=true
package/show_as_launcher_app=false
launcher_icons/main_192x192="res://assets/icons/app_icon.png"
launcher_icons/adaptive_foreground_432x432=""
launcher_icons/adaptive_background_432x432=""
graphics/opengl_debug=false
xr_features/xr_mode=0
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
user_data_backup/allow=false
command_line/extra_args=""
apk_expansion/enable=false
apk_expansion/SALT=""
apk_expansion/public_key=""
permissions/custom_permissions=PackedStringArray()
permissions/access_network_state=false
"@
Write-Utf8NoBom (Join-Path $Proj "export_presets.cfg") $presetText

# 3. 导入资产
Write-Host "==> 导入 Godot 资产" -ForegroundColor Cyan
Invoke-Godot @("--headless", "--path", $Proj, "--import") | Out-Null

# 4. 无头规则回归
if (-not $SkipSim) {
    Write-Host "==> 无头对局回归（10 局 + 水晶保护规则）" -ForegroundColor Cyan
    $simOut = Invoke-Godot @("--headless", "--path", $Proj, "--script", "res://tests/sim_headless.gd")
    if ($simOut -notmatch "SIM_OK" -or $simOut -notmatch "RULE_OK") {
        throw "无头回归未通过：缺少 SIM_OK / RULE_OK"
    }
    Write-Host "==> 首页/战斗流程回归" -ForegroundColor Cyan
    $flowOut = Invoke-Godot @("--headless", "--path", $Proj, "--script", "res://tests/flow_headless.gd")
    if ($flowOut -notmatch "FLOW_OK") {
        throw "首页/战斗流程回归未通过：缺少 FLOW_OK"
    }
}

# 5. 导出 Android release
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:PATH = "$JavaHome\bin;$AndroidSdk\platform-tools;$BuildTools;$env:PATH"

New-Item -ItemType Directory -Force -Path (Join-Path $Proj "build\android") | Out-Null
Write-Host "==> 导出 Android release APK" -ForegroundColor Cyan
Invoke-Godot @("--headless", "--path", $Proj, "--export-release", "Android", "build/android/TapArena.apk") | Out-Null

$Apk = Join-Path $Proj "build\android\TapArena.apk"
if (-not (Test-Path $Apk)) {
    throw "APK 不存在：$Apk"
}

# 6. APK 校验
Write-Host "==> 校验 APK" -ForegroundColor Cyan
$aapt = Join-Path $BuildTools "aapt2.exe"
$apksigner = Join-Path $BuildTools "apksigner.bat"
$oldPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$badging = & $aapt dump badging $Apk 2>&1 | Out-String
$certs = & $apksigner verify --print-certs $Apk 2>&1 | Out-String
$ErrorActionPreference = $oldPref

$expectPackage = "package: name='com.sctale.taparena' versionCode='$VersionCode' versionName='$Version'"
if ($badging -notmatch [regex]::Escape($expectPackage)) {
    throw "APK 包名/版本不匹配，期望：$expectPackage"
}
if ($badging -notmatch "native-code: 'arm64-v8a'") {
    throw "APK 缺少 arm64-v8a"
}
if ($certs -notmatch "CN=TapArena") {
    throw "APK 签名证书不是 TapArena"
}

$Out = Join-Path $Repo ("TapArena-v{0}.apk" -f $Version)
Copy-Item $Apk $Out -Force
$size = (Get-Item $Out).Length
Write-Host ("==> 完成：{0}（{1:N0} bytes）" -f $Out, $size) -ForegroundColor Green
Write-Host "==> 校验通过：package=com.sctale.taparena versionCode=$VersionCode versionName=$Version arm64-v8a cert=CN=TapArena"
