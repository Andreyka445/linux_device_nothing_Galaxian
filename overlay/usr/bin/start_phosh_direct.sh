#!/bin/sh
# 1. GPU Driver & Hardware Bringup (Panthor Mali-G610)
if [ ! -d /sys/module/panthor ] || [ ! -e /sys/class/drm/renderD128 ]; then
    rmmod panthor 2>/dev/null
    chroot /sysroot modprobe mtk_gpufreq_mt6878 2>/dev/null
    echo power_on > /proc/gpufreqv2/mfgsys_power_control 2>/dev/null
    insmod /sysroot/lib/modules/6.1.162-android14-11-ga92e11aaa8fc-dirty/gpu-sched.ko 2>/dev/null
    insmod /sysroot/lib/modules/6.1.162-android14-11-ga92e11aaa8fc-dirty/panthor.ko 2>/dev/null
fi

# Wait for Panthor render node to become ready (up to 10s)
for i in $(seq 1 50); do
    if [ -e /sys/class/drm/renderD128 ]; then
        mknod /dev/dri/card1 c 226 1 2>/dev/null
        mknod /dev/dri/renderD128 c 226 128 2>/dev/null
        mknod /sysroot/dev/dri/card1 c 226 1 2>/dev/null
        mknod /sysroot/dev/dri/renderD128 c 226 128 2>/dev/null
        chmod 666 /dev/dri/* /sysroot/dev/dri/* 2>/dev/null
        if chroot /sysroot python3 -c "import os; os.close(os.open('/dev/dri/renderD128', os.O_RDWR))" 2>/dev/null; then
            break
        fi
    fi
    sleep 0.2
done

# Backlight Driver Bringup
if [ ! -d /sys/class/backlight/panel ]; then
    insmod /sysroot/lib/modules/6.1.162-android14-11-ga92e11aaa8fc-dirty/galaxian_backlight.ko 2>/dev/null || insmod /lib/modules/galaxian_backlight.ko 2>/dev/null
fi
chmod 666 /sys/class/backlight/panel/brightness /sysroot/sys/class/backlight/panel/brightness 2>/dev/null || true

# 2. Hostname & User Environment
hostname galaxian
echo "galaxian" > /etc/hostname 2>/dev/null
echo "galaxian" > /sysroot/etc/hostname 2>/dev/null
echo -e "127.0.0.1\tlocalhost galaxian\n::1\tlocalhost galaxian" > /etc/hosts 2>/dev/null
echo -e "127.0.0.1\tlocalhost galaxian\n::1\tlocalhost galaxian" > /sysroot/etc/hosts 2>/dev/null

mkdir -p /sysroot/home/user/Desktop \
         /sysroot/home/user/Documents \
         /sysroot/home/user/Downloads \
         /sysroot/home/user/Music \
         /sysroot/home/user/Pictures \
         /sysroot/home/user/Videos
chown -R 10000:10000 /sysroot/home/user 2>/dev/null

# 3. Ensure system directories, permissions and mounts
mkdir -p /sysroot/proc /sysroot/sys /sysroot/dev /sysroot/run /sysroot/tmp /sysroot/dev/pts /sysroot/dev/shm /dev/shm
grep -q " /sysroot/proc " /proc/mounts || mount --bind /proc /sysroot/proc
grep -q " /sysroot/sys " /proc/mounts || mount --bind /sys /sysroot/sys
grep -q " /sysroot/dev " /proc/mounts || mount --bind /dev /sysroot/dev
grep -q " /sysroot/dev/pts " /proc/mounts || mount --bind /dev/pts /sysroot/dev/pts 2>/dev/null || mount -t devpts devpts /sysroot/dev/pts
grep -q " /sysroot/run " /proc/mounts || mount -t tmpfs tmpfs /sysroot/run
grep -q " /sysroot/tmp " /proc/mounts || mount -t tmpfs tmpfs /sysroot/tmp
grep -q " /sysroot/dev/shm " /proc/mounts || mount -t tmpfs tmpfs /sysroot/dev/shm 2>/dev/null || true
grep -q " /dev/shm " /proc/mounts || mount -t tmpfs tmpfs /dev/shm 2>/dev/null || true

chmod 1777 /sysroot/tmp /sysroot/dev/shm /dev/shm 2>/dev/null
chmod 666 /dev/null /dev/zero /dev/urandom /dev/ptmx /dev/fuse 2>/dev/null
chmod 666 /dev/dri/* /dev/input/* /sysroot/dev/dri/* /sysroot/dev/input/* 2>/dev/null
chmod 666 /dev/uinput /sysroot/dev/uinput 2>/dev/null

[ -c /dev/input/event0 ] || mknod /dev/input/event0 c 13 64 2>/dev/null
[ -c /dev/input/event1 ] || mknod /dev/input/event1 c 13 65 2>/dev/null
[ -c /dev/input/event2 ] || mknod /dev/input/event2 c 13 66 2>/dev/null
chmod 666 /dev/input/* /sysroot/dev/input/* 2>/dev/null

mkdir -p /sysroot/run/user/10000 /sysroot/run/udev/data
chown -R 10000:10000 /sysroot/run/user/10000
chmod 700 /sysroot/run/user/10000

# Touchscreen
cat << 'UDEV' > /sysroot/run/udev/data/c13:66
E:ID_INPUT=1
E:ID_INPUT_TOUCHSCREEN=1
E:ID_SEAT=seat0
E:WL_OUTPUT=DSI-1
UDEV

# Volume Down & AppSelect (gpio-keys) - Keys only, NOT keyboard!
cat << 'UDEV' > /sysroot/run/udev/data/c13:64
E:ID_INPUT=1
E:ID_INPUT_KEY=1
E:ID_SEAT=seat0
UDEV

# Volume Up & Power (mtk-pmic-keys) - Keys only, NOT keyboard!
cat << 'UDEV' > /sysroot/run/udev/data/c13:65
E:ID_INPUT=1
E:ID_INPUT_KEY=1
E:ID_SEAT=seat0
UDEV

# 4. Start System D-Bus & Galaxian Helper Daemon (login1 & Keys) & Polkit
mkdir -p /sysroot/var/run/dbus /sysroot/run/dbus
if [ ! -e /sysroot/run/dbus/system_bus_socket ]; then
    chroot /sysroot dbus-daemon --system 2>/dev/null
fi

if ! pgrep -x polkitd >/dev/null 2>&1; then
    chroot /sysroot /usr/lib/polkit-1/polkitd --no-debug >/dev/null 2>&1 &
fi

killall python3 2>/dev/null
chroot /sysroot /usr/bin/python3 /usr/bin/galaxian_helper_daemon.py > /tmp/helper.log 2>&1 &

killall -9 drm_splash 2>/dev/null

# 4.1 Wi-Fi & Bluetooth Bringup
sh /sysroot/usr/bin/galaxian_wifi_bringup.sh > /tmp/wifi_bringup.log 2>&1 &

# 5. Start seatd session controller
killall seatd 2>/dev/null
rm -f /sysroot/run/seatd.sock
chroot /sysroot /bin/sh -c 'export SEATD_VTBOUND=0; /usr/bin/seatd -u user -g video -l info > /tmp/seatd.log 2>&1 &'
sleep 1

# 6. Apply settings for user
chroot /sysroot /bin/su - user -c '
    gsettings set org.gnome.settings-daemon.plugins.power power-button-action "nothing" 2>/dev/null
    gsettings set mobi.phosh.shell enable-suspend false 2>/dev/null
    gsettings set mobi.phosh.osk ignore-hw-keyboards true 2>/dev/null
    gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true 2>/dev/null
' 2>/dev/null || true

# 7. Phosh & On-Screen Keyboard Supervisor Loop
while true; do
    chroot /sysroot /bin/su - user -c '
    export XDG_RUNTIME_DIR=/run/user/10000
    export XDG_CURRENT_DESKTOP=GNOME:Phosh
    export XDG_SESSION_DESKTOP=phosh
    export XDG_SESSION_TYPE=wayland
    export DESKTOP_SESSION=phosh
    export SEATD_SOCK=/run/seatd.sock
    export LIBSEAT_BACKEND=seatd
    export SEATD_VTBOUND=0
    export WLR_RENDERER=gles2
    export WLR_DRM_DEVICES=/dev/dri/card0
    export WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128
    export WLR_LIBINPUT_NO_DEVICES=1
    dbus-run-session -- phoc -v -S -C /etc/phosh/phoc.ini -E /usr/bin/phosh_session_start.sh
    ' > /tmp/phosh_launch.log 2>&1
    sleep 2
done
