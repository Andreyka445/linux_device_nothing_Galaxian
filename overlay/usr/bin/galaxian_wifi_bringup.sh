#!/bin/sh
# Galaxian Wi-Fi & Bluetooth Bringup Script

M="/sysroot/lib/modules/6.1.162-android14-11-ga92e11aaa8fc-dirty"

# 1. Bind mount firmware to rootfs /lib/firmware
mkdir -p /lib/firmware /sysroot/lib/firmware
grep -q " /lib/firmware " /proc/mounts || mount --bind /sysroot/lib/firmware /lib/firmware 2>/dev/null || true

# 2. Mount nvdata partition (sdc7) to retrieve factory calibration if needed
if [ ! -f /sysroot/lib/firmware/WIFI_NVRAM ]; then
    mkdir -p /mnt/nvdata
    mount -o ro /dev/sdc7 /mnt/nvdata 2>/dev/null || true
    if [ -f /mnt/nvdata/APCFG/APRDEB/WIFI ]; then
        cp -f /mnt/nvdata/APCFG/APRDEB/WIFI /sysroot/lib/firmware/WIFI_NVRAM 2>/dev/null || true
    fi
    umount /mnt/nvdata 2>/dev/null || true
fi

# Ensure config files
[ -f /sysroot/lib/firmware/conninfra.cfg ] || echo 'co_clock_flag=1' > /sysroot/lib/firmware/conninfra.cfg
[ -f /sysroot/lib/firmware/connfem.cfg ] || touch /sysroot/lib/firmware/connfem.cfg

# 3. Load core networking and MediaTek connectivity modules
for mod in rfkill libarc4 cfg80211 mac80211 connfem connadp ccci_util_lib ccci_auxadc ccmni ccci_md_all mddp conninfra bluetooth bt_drv_6878 wmt_chrdev_wifi_connac2 wlan_drv_gen4m_6878; do
    if ! lsmod | grep -q "^${mod} "; then
        insmod "$M/${mod}.ko" 2>/dev/null || true
    fi
done

# Wait for /sys/class/wmtWifi/wmtWifi/dev
for i in $(seq 1 30); do
    [ -e /sys/class/wmtWifi/wmtWifi/dev ] && break
    sleep 0.1
done

# 4. Create wmtWifi character devices dynamically
if [ -e /sys/class/wmtWifi/wmtWifi/dev ]; then
    dev=$(cat /sys/class/wmtWifi/wmtWifi/dev)
    major=$(echo "$dev" | cut -d: -f1)
    minor=$(echo "$dev" | cut -d: -f2)
    rm -f /dev/wmtWifi /sysroot/dev/wmtWifi
    mknod /dev/wmtWifi c "$major" "$minor" 2>/dev/null || true
    mknod /sysroot/dev/wmtWifi c "$major" "$minor" 2>/dev/null || true
fi

# 5. Send NVRAM and Power On Wi-Fi chip via python helper
chroot /sysroot /bin/python3 /usr/bin/send_nvram.py > /tmp/wifi_init.log 2>&1

# 6. Wait for wlan0 netdev to appear
for i in $(seq 1 40); do
    [ -e /sys/class/net/wlan0 ] && break
    sleep 0.1
done

if [ -e /sys/class/net/wlan0 ]; then
    ip link set wlan0 up 2>/dev/null || true
    
    # 7. Generate udev record so NetworkManager manages wlan0
    ifindex=$(cat /sys/class/net/wlan0/ifindex 2>/dev/null || echo 36)
    mkdir -p /sysroot/run/udev/data /run/udev/data
    cat << EOF > /sysroot/run/udev/data/n${ifindex}
I:${ifindex}
E:DEVPATH=/devices/platform/18400000.wifi/net/wlan0
E:DEVTYPE=wlan
E:INTERFACE=wlan0
E:IFINDEX=${ifindex}
E:SUBSYSTEM=net
E:ID_NET_DRIVER=wlan
EOF
    cp -f /sysroot/run/udev/data/n${ifindex} /run/udev/data/n${ifindex} 2>/dev/null || true
fi

# 8. Start wpa_supplicant and NetworkManager
mkdir -p /sysroot/var/run/wpa_supplicant /sysroot/run/wpa_supplicant
if ! ps | grep -v grep | grep -q "/bin/wpa_supplicant"; then
    chroot /sysroot /bin/wpa_supplicant -u -B 2>/dev/null || true
fi

if ! ps | grep -v grep | grep -q "/bin/NetworkManager"; then
    chroot /sysroot /bin/NetworkManager 2>/dev/null || true
fi
