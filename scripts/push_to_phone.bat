@echo off
setlocal
echo ==============================================================================
echo  Nothing Phone (3a) Lite - PostmarketOS Phosh Deployment Script
echo ==============================================================================

echo [*] Checking ADB connection...
adb devices
if %ERRORLEVEL% NEQ 0 (
    echo [!] ADB not found or device not connected!
    pause
    exit /b 1
)

echo [*] Preparing directories on device...
adb shell "su -c 'mkdir -p /data/pmos_files /data/pmos && chmod 777 /data/pmos_files'"

echo [*] Pushing scripts and configurations...
adb push "%~dp0start_phosh.sh" /data/local/tmp/start_phosh.sh
adb push "%~dp0stop_phosh.sh" /data/local/tmp/stop_phosh.sh
adb push "%~dp0linux_pmos.sh" /data/local/tmp/linux_pmos.sh
adb push "%~dp0android_pmos.sh" /data/local/tmp/android_pmos.sh
adb push "%~dp0linux_termux.sh" /data/local/tmp/linux_termux.sh
adb push "%~dp0android_termux.sh" /data/local/tmp/android_termux.sh
adb push "%~dp0..\configs\phoc.ini" /data/local/tmp/phoc.ini
adb push "%~dp0..\binaries\wvkbd-mobintl" /data/local/tmp/wvkbd
adb push "%~dp0..\binaries\squeekboard" /data/local/tmp/squeekboard

adb shell "su -c 'mv /data/local/tmp/start_phosh.sh /data/pmos_files/start_phosh.sh && mv /data/local/tmp/stop_phosh.sh /data/pmos_files/stop_phosh.sh && mv /data/local/tmp/linux_pmos.sh /data/pmos_files/linux && mv /data/local/tmp/android_pmos.sh /data/pmos_files/android && chmod +x /data/pmos_files/* && cp /data/local/tmp/linux_termux.sh /data/data/com.termux/files/usr/bin/linux 2>/dev/null && cp /data/local/tmp/android_termux.sh /data/data/com.termux/files/usr/bin/android 2>/dev/null && chmod +x /data/data/com.termux/files/usr/bin/linux /data/data/com.termux/files/usr/bin/android 2>/dev/null'"

echo.
echo [*] Do you want to push the 3GB rootfs image (pmos_phosh.img)? [Y/N]
set /p PUSH_IMG=
if /i "%PUSH_IMG%"=="Y" (
    echo [*] Pushing pmos_phosh.img (3.2 GB, takes 1-2 minutes)...
    adb push "%~dp0..\..\output\pmos_phosh.img" /data/local/tmp/pmos_phosh.img
    adb shell "su -c 'mv /data/local/tmp/pmos_phosh.img /data/pmos_files/pmos_phosh.img'"
)

echo.
echo ==============================================================================
echo  Deployment complete!
echo  To start on phone: Open Termux and run: linux
echo  To return to Android: In Phosh terminal or Termux run: android
echo ==============================================================================
pause
