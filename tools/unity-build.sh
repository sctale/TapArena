#!/usr/bin/env bash
# 本地构建 Unity 版 APK（Windows / Git Bash）。
# 为什么要绕一圈：headless 下 Unity 会把 Gradle 的堆算成 -Xmx0m 直接崩，
# 所以先导出 Gradle 工程，再用外部 gradlew 构建；IL2CPP 还会被系统临时目录拒写，
# 把 TMP/TEMP 指到工程内目录即可。
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$REPO/unity"
BUILD="$PROJ/Builds/AndroidProject"
UNITY_EXE="${UNITY_EXE:-C:/Program Files/Unity/Hub/Editor/6000.3.10f1/Editor/Unity.exe}"
JDK="${TAPARENA_JDK:-C:/Program Files/Unity/Hub/Editor/6000.3.10f1/Editor/Data/PlaybackEngines/AndroidPlayer/OpenJDK}"

# Git Bash 里转成 Unity 认得的 Windows 路径
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

VERSION="$(grep -oE 'const string Version = "[^"]+"' "$PROJ/Assets/Editor/BuildScript.cs" | sed -E 's/.*"([^"]+)"/\1/')"
VERSION="${VERSION:-2.0.0}"

mkdir -p "$PROJ/il2cpp-tmp" "$PROJ/Builds"

echo "[1/3] 导出 Gradle 工程（$VERSION）"
"$UNITY_EXE" -batchmode -nographics -quit \
  -projectPath "$(winpath "$PROJ")" \
  -executeMethod TapArena.EditorTools.BuildScript.ExportAndroidProject \
  -logFile "$(winpath "$PROJ/Builds/export.log")"

echo "[2/3] gradlew assembleRelease"
cd "$BUILD"
# 保底：外部 Gradle 需要正常的堆
sed -i 's/^org.gradle.jvmargs=.*/org.gradle.jvmargs=-Xmx4096M -Dfile.encoding=UTF-8/' gradle.properties
TMP="$(winpath "$PROJ/il2cpp-tmp")" TEMP="$(winpath "$PROJ/il2cpp-tmp")" JAVA_HOME="$JDK" \
  cmd //c "gradlew.bat assembleRelease --no-daemon"

APK="$BUILD/launcher/build/outputs/apk/release/launcher-release.apk"
OUT="$REPO/TapArena-v$VERSION.apk"
cp "$APK" "$OUT"

echo "[3/3] 产物：$OUT"
ls -la "$OUT"
