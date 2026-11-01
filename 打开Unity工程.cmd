@echo off
rem Open the TapArena Unity project with Unity 6000.3.10f1
cd /d "%~dp0unity"
if exist "C:\Program Files\Unity\Hub\Editor\6000.3.10f1\Editor\Unity.exe" (
  start "" "C:\Program Files\Unity\Hub\Editor\6000.3.10f1\Editor\Unity.exe" -projectPath "%CD%"
) else (
  echo Unity 6000.3.10f1 not found. Open this folder with Unity Hub instead:
  echo   %CD%
  pause
)
