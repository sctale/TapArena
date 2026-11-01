import subprocess, time, io, sys
from PIL import Image

ADB = r"C:\Users\HAOHAO\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SHOTS = r"D:\V-Coding\TapArena\tools\shots"
DEADLINE = time.time() + 300

def grab():
    out = subprocess.run([ADB, "-s", "emulator-5554", "exec-out", "screencap", "-p"],
                         capture_output=True, timeout=30)
    return Image.open(io.BytesIO(out.stdout)).convert("RGB")

misses = 0
last = None
while time.time() < DEADLINE:
    try:
        im = grab()
    except Exception as e:
        print("grab failed:", e); time.sleep(5); continue
    last = im
    # 顶左 HUD 底板固定深青绿；结算页无 HUD
    r, g, b = im.getpixel((420, 30))
    hud = (r < 90 and g < 130 and b < 115 and g > r)
    print(time.strftime("%H:%M:%S"), (r, g, b), "HUD" if hud else "NO-HUD", flush=True)
    if not hud:
        misses += 1
        if misses >= 3:
            im.save(SHOTS + r"\apk-result.png")
            print("RESULT SCREEN CAPTURED", flush=True)
            sys.exit(0)
    else:
        misses = 0
    time.sleep(5)

if last is not None:
    last.save(SHOTS + r"\apk-timeout.png")
print("TIMEOUT - no result screen", flush=True)
sys.exit(1)
