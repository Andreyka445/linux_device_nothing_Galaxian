#!/system/bin/sh
# ==============================================================================
# Nothing Phone (3a) Lite (Galaxian / MT6878) - PostmarketOS Phosh Launcher
# ==============================================================================

# 1. SELinux, Keep CPU awake & Immune to Android OOM Killer
setenforce 0 2>/dev/null
echo "pmos_stay_awake" > /sys/power/wake_lock 2>/dev/null
echo -1000 > /proc/$$/oom_score_adj 2>/dev/null

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

# 7. Detach Android display server to free DRM_MASTER
echo "[*] Stopping Android HWComposer..."
stop vendor.hwcomposer-3-2
pkill -STOP -f "composer@3.2"

# 8. Enable AMOLED display and set comfortable brightness
echo On > /sys/class/drm/card0-DSI-1/dpms 2>/dev/null
echo 2600 > /sys/devices/platform/display_id/brightnessid

# Background brightness keeper
pkill -9 -f "brightnessid" 2>/dev/null
(while true; do echo 2600 > /sys/devices/platform/display_id/brightnessid 2>/dev/null; sleep 3; done) &
BRIGHT_PID=$!

# Ensure return command exists inside Linux
cat << 'CMD' > "$PMOS_DIR/usr/bin/android"
#!/bin/sh
echo "Returning to Android..."
killall -9 phoc phosh squeekboard wvkbd
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
export WLR_RENDERER=pixman
export WLR_NO_HARDWARE_CURSORS=1
export WLR_DRM_DEVICES=/dev/dri/card0
export SEATD_VTBOUND=0
export LIBSEAT_BACKEND=seatd
export GSETTINGS_BACKEND=keyfile
export GSK_RENDERER=cairo

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

# Ensure Squeekboard D-Bus service and autostart exist
mkdir -p /usr/share/dbus-1/services /etc/xdg/autostart
echo "[D-BUS Service]" > /usr/share/dbus-1/services/sm.puri.OSK0.service
echo "Name=sm.puri.OSK0" >> /usr/share/dbus-1/services/sm.puri.OSK0.service
echo "Exec=/usr/bin/squeekboard" >> /usr/share/dbus-1/services/sm.puri.OSK0.service
cp -f /usr/share/applications/sm.puri.OSK0.desktop /etc/xdg/autostart/sm.puri.OSK0.desktop 2>/dev/null

dbus-run-session -- sh -c "
trap \"\" HUP
gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null
gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
gsettings set org.gnome.settings-daemon.plugins.power power-button-action \"nothing\" 2>/dev/null

# Configure on-screen keyboard (auto-pops up on input focus or bottom bar tap)
gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'ru')]\" 2>/dev/null
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true 2>/dev/null

# Launch Squeekboard
(sleep 2; squeekboard >/tmp/squeekboard.log 2>&1) &

phoc -C /etc/phoc.ini -E /usr/libexec/phosh >/tmp/phoc.log 2>&1
" >/tmp/session.log 2>&1
'

# 10. Clean up and restore Android automatically upon Phosh exit
kill -9 "$BRIGHT_PID" 2>/dev/null
pkill -9 -f "brightnessid" 2>/dev/null
killall -9 phoc phosh squeekboard wvkbd seatd pipewire pipewire-pulse wireplumber 2>/dev/null

# Restore Android display
echo "[*] Restoring Android display..."
pkill -CONT -f "composer@3.2" 2>/dev/null
start vendor.hwcomposer-3-2
echo "[+] Android display restored!"
