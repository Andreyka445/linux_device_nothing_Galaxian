#!/system/bin/sh
# ==============================================================================
# Nothing Phone (3a) Lite (MT6878) - Return to Android & Restore Mali GPU
# ==============================================================================

echo "[*] Killing Linux processes..."
pkill -9 -f "brightnessid" 2>/dev/null
for pid in $(lsof /data/pmos 2>/dev/null | awk 'NR>1 {print $2}' | sort -u); do
    kill -9 "$pid" 2>/dev/null || true
done
killall -9 phoc phosh wvkbd squeekboard phosh-osk-stevia seatd pipewire pipewire-pulse wireplumber dbus-daemon 2>/dev/null
setprop service.bootanim.exit 1 2>/dev/null
stop bootanim 2>/dev/null
pkill -9 bootanimation 2>/dev/null

# Wait until ALL processes close DRM / Panthor GPU nodes completely
echo "[*] Waiting for all processes to release Panthor GPU..."
for i in $(seq 1 30); do
    if ! lsof /dev/dri/render* /dev/dri/card1 >/dev/null 2>&1; then
        echo "[+] Panthor GPU handles released cleanly!"
        break
    fi
    sleep 0.3
done
if lsof /dev/dri/render* /dev/dri/card1 >/dev/null 2>&1; then
    for pid in $(lsof /dev/dri/render* /dev/dri/card1 2>/dev/null | awk 'NR>1 {print $2}' | sort -u); do
        kill -9 "$pid" 2>/dev/null || true
    done
    sleep 0.5
fi

echo "[*] Unbinding Panthor & rebinding Mali driver..."
if [ -d /sys/bus/platform/drivers/panthor ]; then
    echo 13000000.mali > /sys/bus/platform/drivers/panthor/unbind 2>/dev/null || true
fi
rmmod panthor 2>/dev/null || true
rmmod gpu-sched 2>/dev/null || true

# Restore original Android Mali CSF firmware path
echo /vendor/firmware > /sys/module/firmware_class/parameters/path 2>/dev/null

if [ -d /sys/bus/platform/drivers/mali ]; then
    echo 13000000.mali > /sys/bus/platform/drivers/mali/bind 2>/dev/null || true
fi
sleep 1

# Re-link /dev/mali0 to active Mali node, fix permissions & SELinux context
MALI_DEV=$(ls -d /dev/mali* 2>/dev/null | grep -E 'mali[0-9]' | head -n 1)
if [ -n "$MALI_DEV" ] && [ "$MALI_DEV" != "/dev/mali0" ]; then
    rm -f /dev/mali0
    ln -sf "$MALI_DEV" /dev/mali0
fi
chmod 666 /dev/mali* 2>/dev/null
chown system:graphics /dev/mali* 2>/dev/null
restorecon -F /dev/mali* 2>/dev/null
chmod 666 /dev/pts/ptmx /dev/ptmx 2>/dev/null

# Re-enable MediaTek GED GPU DVFS
echo 1 > /sys/module/ged/parameters/gpu_dvfs_enable 2>/dev/null
echo 1 > /sys/module/ged/parameters/ged_boost_enable 2>/dev/null
echo 1 > /sys/module/ged/parameters/ged_smart_boost 2>/dev/null

echo "[*] Mali device status:"
ls -laZ /dev/mali* 2>/dev/null

echo "[*] Waking up Android Graphics Subsystem and Framework..."
start vendor.hwcomposer-3-2 2>/dev/null
start

# Wait for SurfaceFlinger & Android framework to initialize
echo "[*] Waiting for Android UI to become ready..."
for i in $(seq 1 40); do
    if lsof /dev/mali* 2>/dev/null | grep -q surfaceflinger; then
        echo "[+] SurfaceFlinger is active on Mali GPU!"
        break
    fi
    sleep 0.5
done

setprop service.bootanim.exit 1 2>/dev/null
stop bootanim 2>/dev/null
pkill -9 bootanimation 2>/dev/null

# Ensure display is awake, unblanked, and keyguard dismissed
echo "[*] Powering on display panel & waking keyguard..."
echo 2000 > /sys/devices/platform/display_id/brightnessid 2>/dev/null
echo 2000 > /sys/class/leds/lcd-backlight/brightness 2>/dev/null
input keyevent KEYCODE_WAKEUP 2>/dev/null
sleep 0.5
wm dismiss-keyguard 2>/dev/null
input keyevent 82 2>/dev/null

echo "[+] Android successfully restored!"
