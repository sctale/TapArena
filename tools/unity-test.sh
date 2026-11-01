#!/bin/bash
# Unity 版实机验证：安装 → 首页 → 选人 → 开局 → 截图
ADB="C:/Users/HAOHAO/AppData/Local/Android/Sdk/platform-tools/adb.exe"
APK="${1:-unity/Builds/TapArena.apk}"
"$ADB" -s emulator-5554 install -r "$APK" 2>&1 | tail -1
"$ADB" -s emulator-5554 shell am force-stop com.sctale.taparena
"$ADB" -s emulator-5554 shell am start -n com.sctale.taparena/com.unity3d.player.UnityPlayerActivity >/dev/null 2>&1
sleep 6
"$ADB" -s emulator-5554 exec-out screencap -p > tools/shots/u-home.png
"$ADB" -s emulator-5554 shell input tap 480 670      # 开始冒险
sleep 2
"$ADB" -s emulator-5554 exec-out screencap -p > tools/shots/u-select.png
"$ADB" -s emulator-5554 shell input tap 585 378      # 第一张卡（阿虎）
sleep 1
"$ADB" -s emulator-5554 shell input tap 960 994      # 出发
sleep 10
"$ADB" -s emulator-5554 exec-out screencap -p > tools/shots/u-battle.png
"$ADB" -s emulator-5554 shell dumpsys gfxinfo com.sctale.taparena >/dev/null 2>&1
echo done
