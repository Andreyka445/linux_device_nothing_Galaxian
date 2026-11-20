#!/system/bin/sh
# ==============================================================================
# Nothing Phone (3a) Lite (Galaxian / MT6878) - PostmarketOS Phosh Launcher
# ==============================================================================

# 1. SELinux, Keep CPU awake & Immune to Android OOM Killer
setenforce 0 2>/dev/null
echo "pmos_stay_awake" > /sys/power/wake_lock 2>/dev/null
echo -1000 > /proc/$$/oom_score_adj 2>/dev/null

# Wait for Android to settle if it was recently started
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    echo "[*] Waiting for Android boot to complete..."
    sleep 2
done

# Ignore SIGHUP so Termux going to background never kills Linux
trap '' HUP INT QUIT

PMOS_DIR="/data/pmos"
IMG_PATH="/data/pmos_files/pmos_phosh.img"

# 2. Mount rootfs if not already mounted
if ! grep -q "$PMOS_DIR " /proc/mounts; then
    echo "[*] Mounting postmarketOS rootfs..."
    mkdir -p "$PMOS_DIR"
    LOOP=$(losetup -f -s "$IMG_PATH")
    mount -t ext4 -o rw "$LOOP" "$PMOS_DIR"
    mount -t proc proc "$PMOS_DIR/proc"
    mount -t sysfs sys "$PMOS_DIR/sys"
    mount --bind /dev "$PMOS_DIR/dev"
    mount --bind /dev/pts "$PMOS_DIR/dev/pts"
    mkdir -p "$PMOS_DIR/dev/shm" "$PMOS_DIR/run" "$PMOS_DIR/tmp" "$PMOS_DIR/data/local/tmp"
    mount -t tmpfs tmpfs "$PMOS_DIR/dev/shm"
    mount -t tmpfs tmpfs "$PMOS_DIR/run"
    mount -t tmpfs tmpfs "$PMOS_DIR/tmp"
    chmod 1777 "$PMOS_DIR/tmp" "$PMOS_DIR/dev/shm" "$PMOS_DIR/data/local/tmp"
    mkdir -p "$PMOS_DIR/tmp/runtime-root"
    chmod 0700 "$PMOS_DIR/tmp/runtime-root"
fi

# 3. Permissions for DRM, Input, Audio
chmod 666 "$PMOS_DIR/dev/dri/"* "$PMOS_DIR/dev/input/"* "$PMOS_DIR/dev/snd/"* 2>/dev/null

# Ensure /dev/pts (PTY for terminals) and /dev/shm (POSIX shared memory for Wayland keymaps) are mounted
mkdir -p "$PMOS_DIR/dev/pts" "$PMOS_DIR/dev/shm"
if ! grep -q "$PMOS_DIR/dev/pts " /proc/mounts; then
    mount -t devpts devpts -o rw,nosuid,noexec,relatime,mode=620,ptmxmode=666 "$PMOS_DIR/dev/pts" 2>/dev/null
fi
rm -f "$PMOS_DIR/dev/ptmx"
ln -sf pts/ptmx "$PMOS_DIR/dev/ptmx" 2>/dev/null

if ! grep -q "$PMOS_DIR/dev/shm " /proc/mounts; then
    mount -t tmpfs tmpfs "$PMOS_DIR/dev/shm" 2>/dev/null
    chmod 1777 "$PMOS_DIR/dev/shm" 2>/dev/null
fi

# 4. Always ensure runtime directory exists with 0700 permissions
mkdir -p "$PMOS_DIR/tmp/runtime-root"
chmod 0700 "$PMOS_DIR/tmp/runtime-root"
rm -f "$PMOS_DIR/tmp/runtime-root/wayland-*" "$PMOS_DIR/tmp/runtime-root/pulse/native" "$PMOS_DIR/run/seatd.sock" 2>/dev/null

# 5. Configure udev database (assign FocalTech touch to seat0, isolate power button)
mkdir -p "$PMOS_DIR/run/udev/data"
cat << 'UDEV' > "$PMOS_DIR/run/udev/data/c13:67"
E:ID_INPUT=1
E:ID_INPUT_TOUCHSCREEN=1
E:ID_SEAT=seat0
E:WL_OUTPUT=DSI-1
UDEV
rm -f "$PMOS_DIR/run/udev/data/c13:64" "$PMOS_DIR/run/udev/data/c13:65" "$PMOS_DIR/run/udev/data/c13:66" "$PMOS_DIR/run/udev/data/c13:68" 2>/dev/null

# 6. CPU performance boost (all 8 cores)
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$cpu" 2>/dev/null
done

# 7. Gracefully stop Android UI, Zygote and HWComposer
# Disable GED DVFS during switch to prevent background frequency governor race
echo 0 > /sys/module/ged/parameters/gpu_dvfs_enable 2>/dev/null
echo 0 > /sys/module/ged/parameters/ged_boost_enable 2>/dev/null
echo 0 > /sys/module/ged/parameters/ged_smart_boost 2>/dev/null

echo "[*] Stopping Android graphics and framework..."
stop vendor.hwcomposer-3-2 2>/dev/null
stop

# Wait until ALL Android processes completely exit and close Mali GPU
echo "[*] Waiting for all processes to release Mali GPU..."
for i in $(seq 1 40); do
    if ! lsof /dev/mali* >/dev/null 2>&1; then
        echo "[+] All Mali handles released cleanly!"
        break
    fi
    sleep 0.3
done
if lsof /dev/mali* >/dev/null 2>&1; then
    echo "[!] Killing remaining Mali processes..."
    for pid in $(lsof /dev/mali* 2>/dev/null | awk 'NR>1 {print $2}' | sort -u); do
        kill -9 "$pid" 2>/dev/null || true
    done
    sleep 0.5
fi

# Power GPU & Bind Panthor Driver for Linux HW Acceleration
echo "[*] Powering GPU & binding Panthor..."
echo power_on > /proc/gpufreqv2/mfgsys_power_control 2>/dev/null
echo /data/local/tmp/panthor > /sys/module/firmware_class/parameters/path 2>/dev/null
insmod /data/local/tmp/panthor/gpu-sched.ko 2>/dev/null || true
insmod /data/local/tmp/panthor/panthor.ko 2>/dev/null || true
echo 13000000.mali > /sys/bus/platform/drivers/mali/unbind 2>/dev/null || true
echo 13000000.mali > /sys/bus/platform/drivers/panthor/bind 2>/dev/null || true
chmod 666 /dev/dri/* "$PMOS_DIR/dev/dri/"* 2>/dev/null

# 8. Enable AMOLED display and set comfortable brightness
chmod 666 /sys/class/drm/card0-DSI-1/dpms 2>/dev/null || true
 echo On > /sys/class/drm/card0-DSI-1/dpms 2>/dev/null || true 2>/dev/null
echo 2600 > /sys/devices/platform/display_id/brightnessid

# Background brightness keeper
pkill -9 -f "brightnessid" 2>/dev/null
(while true; do echo 2600 > /sys/devices/platform/display_id/brightnessid 2>/dev/null; sleep 3; done) &
BRIGHT_PID=$!

# Ensure return command exists inside Linux
cat << 'CMD' > "$PMOS_DIR/usr/bin/android"
#!/bin/sh
echo "Returning to Android..."
killall -9 phoc phosh squeekboard phosh-osk-stevia wvkbd
CMD
chmod +x "$PMOS_DIR/usr/bin/android"

# 9. Launch Phosh environment
echo "[*] Launching Phosh (Wayland)..."
chroot "$PMOS_DIR" /bin/sh -c '
export PATH=/usr/libexec:/bin:/usr/bin:/sbin:/usr/sbin
export SHELL=/bin/sh
export TMPDIR=/tmp
export TEMP=/tmp
export TMP=/tmp
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_DATA_DIRS=/usr/share:/usr/local/share
export WLR_RENDERER=gles2
export WLR_NO_HARDWARE_CURSORS=1
export WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1
export SEATD_VTBOUND=0
export LIBSEAT_BACKEND=seatd
export GSETTINGS_BACKEND=keyfile
export GSK_RENDERER=gl

# Enable Hardware Speaker Routing, I2S Amplifiers & Volume
amixer -c 0 cset name="Ext_Speaker_Amp Switch" 1 2>/dev/null
amixer -c 0 cset name="DAC In Mux" 0 2>/dev/null
amixer -c 0 cset name="LOL Mux" 2 2>/dev/null
amixer -c 0 cset name="HPL Mux" 1 2>/dev/null
amixer -c 0 cset name="HPR Mux" 1 2>/dev/null
amixer -c 0 cset name="ADDA_DL_CH1 DL0_CH1" 1 2>/dev/null
amixer -c 0 cset name="ADDA_DL_CH2 DL0_CH2" 1 2>/dev/null
amixer -c 0 cset name="I2SOUT1_CH1 DL0_CH1" 1 2>/dev/null
amixer -c 0 cset name="I2SOUT1_CH2 DL0_CH2" 1 2>/dev/null
amixer -c 0 cset name="I2SOUT2_CH1 DL0_CH1" 1 2>/dev/null
amixer -c 0 cset name="I2SOUT2_CH2 DL0_CH2" 1 2>/dev/null
amixer -c 0 cset name="I2SOUT4_CH1 DL0_CH1" 1 2>/dev/null
amixer -c 0 cset name="I2SOUT4_CH2 DL0_CH2" 1 2>/dev/null
amixer -c 0 cset name="TFA Profile" 0 2>/dev/null
amixer -c 0 cset name="TFA Stop" 0 2>/dev/null
amixer -c 0 sset "Lineout Volume" 100% 2>/dev/null
amixer -c 0 sset "Headset Volume" 100% 2>/dev/null
amixer -c 0 sset "Handset Volume" 100% 2>/dev/null

mkdir -p /var/run/dbus /run/dbus
dbus-uuidgen --ensure 2>/dev/null
dbus-daemon --system --fork 2>/dev/null

pkill -9 seatd squeekboard wvkbd pipewire pipewire-pulse wireplumber 2>/dev/null
seatd -u root -g root &
sleep 1

# Start PipeWire audio servers
pipewire &
sleep 1
pipewire-pulse &
sleep 1
wireplumber &

# Unmute PipeWire audio sinks and set 100% volume
(
    sleep 4
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 2>/dev/null
    pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null
    pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null
    for s in $(pactl list short sinks 2>/dev/null | cut -f1); do
        pactl set-sink-mute "$s" 0 2>/dev/null
        pactl set-sink-volume "$s" 100% 2>/dev/null
    done
) &

# Ensure On-Screen Keyboard D-Bus service and autostart exist (Stevia / Phosh OSK)
mkdir -p /usr/share/dbus-1/services /etc/xdg/autostart
echo "[D-BUS Service]" > /usr/share/dbus-1/services/sm.puri.OSK0.service
echo "Name=sm.puri.OSK0" >> /usr/share/dbus-1/services/sm.puri.OSK0.service
echo "Exec=/usr/bin/phosh-osk-stevia --allow-replacement" >> /usr/share/dbus-1/services/sm.puri.OSK0.service
cp -f /usr/share/applications/sm.puri.OSK0.desktop /etc/xdg/autostart/sm.puri.OSK0.desktop 2>/dev/null

dbus-run-session -- sh -c "
trap \"\" HUP
gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null
gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.power power-button-action \"nothing\" 2>/dev/null

# Configure on-screen keyboard (auto-pops up on input focus or bottom bar tap)
gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'ru')]\" 2>/dev/null
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true 2>/dev/null

# Launch Phosh OSK (Stevia - native terminal, browser & GTK4 typing support)
(sleep 2; phosh-osk-stevia --allow-replacement >/tmp/osk.log 2>&1) &

phoc -C /etc/phoc.ini -E /usr/libexec/phosh 2>&1 | tee /tmp/phoc.log
" 2>&1 | tee /tmp/session.log
'

# 10. Clean up and restore Android automatically upon Phosh exit
kill -9 "$BRIGHT_PID" 2>/dev/null
pkill -9 -f "brightnessid" 2>/dev/null

echo "[*] Terminating all Linux chroot processes..."
for pid in $(lsof /data/pmos 2>/dev/null | awk 'NR>1 {print $2}' | sort -u); do
    kill -9 "$pid" 2>/dev/null || true
done
killall -9 phoc phosh squeekboard phosh-osk-stevia wvkbd seatd pipewire pipewire-pulse wireplumber dbus-daemon 2>/dev/null

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

# Restore Android display & framework
echo "[*] Restoring Android display and framework..."
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

echo "[+] Android display restored!"
