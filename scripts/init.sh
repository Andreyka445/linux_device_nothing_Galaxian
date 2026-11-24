#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# 0. Essential virtual filesystem mounts
mkdir -p /dev /proc /sys /config /mnt /run /tmp
mountpoint -q /proc || mount -t proc proc /proc
mountpoint -q /sys || mount -t sysfs sys /sys
mountpoint -q /dev || mount -t devtmpfs devtmpfs /dev 2>/dev/null || mount -t tmpfs devtmpfs /dev
mountpoint -q /config || mount -t configfs configfs /config 2>/dev/null || true
rm -f /dev/null /dev/zero /dev/urandom /dev/random
mknod -m 666 /dev/null c 1 3
mknod -m 666 /dev/zero c 1 5
mknod -m 666 /dev/urandom c 1 9
mknod -m 666 /dev/random c 1 8

# Install busybox applets
/bin/busybox --install -s /bin 2>/dev/null
/bin/busybox-extras --install -s /bin 2>/dev/null || true
mkdir -p /dev/pts
mountpoint -q /dev/pts || mount -t devpts -o ptmxmode=0666,gid=5,mode=620 devpts /dev/pts 2>/dev/null || mount -t devpts devpts /dev/pts 2>/dev/null || true
[ -c /dev/pts/ptmx ] && chmod 666 /dev/pts/ptmx 2>/dev/null || true
[ -e /dev/ptmx ] || ln -sf pts/ptmx /dev/ptmx 2>/dev/null || true
[ -c /dev/ptmx ] && chmod 666 /dev/ptmx 2>/dev/null || true

log_kmsg() {
    echo "<6>[PMOS-STANDALONE] $1" > /dev/kmsg 2>/dev/null
    echo "[PMOS-STANDALONE] $1"
}

log_kmsg "=== STAGE 2: Standalone Init Started (Samsung/BOE + MTK RNDIS Edition) ==="

# 1. Start Watchdog immediately
if [ -f /modules/mtk_wdt.ko ]; then
    insmod /modules/mtk_wdt.ko 2>/dev/null
elif [ -f /lib/modules/mtk_wdt.ko ]; then
    insmod /lib/modules/mtk_wdt.ko 2>/dev/null
fi
(
    while true; do
        if [ -c /dev/watchdog ]; then
            echo 1 > /dev/watchdog 2>/dev/null
        fi
        sleep 2
    done
) &
log_kmsg "Watchdog thread running"

# 2. Critical early ADC & network dependencies (NO mtu3/xhci here before power domains!)
for m in \
    industrialio.ko kfifo_buf.ko industrialio_triggered_buffer.ko \
    mt6375_auxadc.ko mt6375_adc.ko \
    rps_perf.ko mtk_u_ether.ko mtk_usb_f_rndis.ko \
    mtk-smi.ko mtk-smi-dbg.ko vcp_status.ko
do
    alt=$(echo "$m" | tr '-' '_')
    [ -f "/modules/$m" ] && insmod "/modules/$m" 2>/dev/null
    [ -f "/modules/$alt" ] && insmod "/modules/$alt" 2>/dev/null
done
insmod /modules/nt_usb_ts.ko 2>/dev/null

# Load remaining vendor modules
if [ -f /lib/modules/modules.load ]; then
    while read -r mod; do
        [ -n "$mod" ] || continue
        case "$mod" in
            *mmdvfs*|*mmqos*|*mminfra*|*pd9302a*|*nt_chg*|*mediatek-drm*|*panel-*|*ft3683g*|*eph861*|*vcp*) continue ;;
        esac
        [ -f "/lib/modules/$mod" ] && insmod "/lib/modules/$mod" 2>/dev/null
    done < /lib/modules/modules.load
fi

# Two passes over /modules/*.ko to resolve forward dependencies
for pass in 1 2; do
    for m in /modules/*.ko; do
        [ -f "$m" ] || continue
        case "$m" in
            *mmdvfs*|*mmqos*|*mminfra*|*pd9302a*|*nt_chg*|*mediatek-drm*|*panel-*|*ft3683g*|*eph861*|*vcp*) continue ;;
        esac
        insmod "$m" 2>/dev/null
    done
done

# Populate device nodes
mdev -s 2>/dev/null

# 3. Hardware Feedback: Glyph Solid ON & Haptic
if [ -d /sys/class/leds/noth_leds ]; then
    echo 1 > /sys/class/leds/noth_leds/state 2>/dev/null
    echo 255 > /sys/class/leds/noth_leds/brightness 2>/dev/null
    log_kmsg "Glyph LED set to solid ON"
fi
(
    while true; do
        if [ -d /sys/class/leds/noth_leds ]; then
            echo 255 > /sys/class/leds/noth_leds/brightness 2>/dev/null
            echo 1 > /sys/class/leds/noth_leds/state 2>/dev/null
        fi
        sleep 0.5
    done
) &

for v in /sys/class/leds/vibrator /sys/class/timed_output/vibrator; do
    if [ -d "$v" ]; then
        echo 300 > "$v/duration" 2>/dev/null
        echo 1 > "$v/activate" 2>/dev/null
        echo 255 > "$v/brightness" 2>/dev/null
    fi
done

# 4. Turn On AMOLED Display & Set Brightness
echo 2600 > /sys/devices/platform/display_id/brightnessid 2>/dev/null || true
echo On > /sys/class/drm/card0-DSI-1/dpms 2>/dev/null || true

# 5. Persistent Logging to nt_log & metadata partitions
log_kmsg "Searching for nt_log & metadata partitions to write persistent boot log..."
NTLOG_DEV=""
for uevent in /sys/class/block/*/uevent; do
    if grep -q "PARTNAME=nt_log$" "$uevent" 2>/dev/null; then
        dev_name=$(grep "^DEVNAME=" "$uevent" | cut -d= -f2)
        [ -n "$dev_name" ] && NTLOG_DEV="/dev/$dev_name" && break
    fi
done
[ -z "$NTLOG_DEV" ] && [ -b /dev/block/by-name/nt_log ] && NTLOG_DEV="/dev/block/by-name/nt_log"
[ -z "$NTLOG_DEV" ] && [ -b /dev/block/sdc76 ] && NTLOG_DEV="/dev/block/sdc76"
[ -z "$NTLOG_DEV" ] && [ -b /dev/sdc76 ] && NTLOG_DEV="/dev/sdc76"

META_DEV=""
for m in /dev/block/by-name/metadata /dev/block/sdc16; do
    [ -b "$m" ] && META_DEV="$m" && break
done

if [ -n "$NTLOG_DEV" ]; then
    mkdir -p /mnt/nt_log
    mount -t ext4 "$NTLOG_DEV" /mnt/nt_log 2>/dev/null
    mkdir -p /mnt/nt_log/recovery_log/NTrecovery_99_pmos 2>/dev/null
    log_kmsg "Mounted persistent log partition: $NTLOG_DEV"
    dmesg > /mnt/nt_log/pmos_standalone_boot.log 2>/dev/null
    dmesg > /mnt/nt_log/recovery_log/pmos_standalone_boot.log 2>/dev/null
    dmesg > /mnt/nt_log/recovery_log/NTrecovery_99_pmos/recovery.log 2>/dev/null
    sync
fi

if [ -n "$META_DEV" ]; then
    mkdir -p /mnt/meta
    if mount "$META_DEV" /mnt/meta 2>/dev/null; then
        log_kmsg "Mounted persistent metadata partition: $META_DEV"
        dmesg > /mnt/meta/pmos_boot.log 2>/dev/null
        sync
    fi
fi

(
    while true; do
        if [ -d /mnt/nt_log ]; then
            dmesg > /mnt/nt_log/pmos_standalone_boot.log 2>/dev/null
            dmesg > /mnt/nt_log/recovery_log/pmos_standalone_boot.log 2>/dev/null
            dmesg > /mnt/nt_log/recovery_log/NTrecovery_99_pmos/recovery.log 2>/dev/null
        fi
        if mountpoint -q /mnt/meta 2>/dev/null; then
            dmesg > /mnt/meta/pmos_boot.log 2>/dev/null
        fi
        sync
        sleep 2
    done
) &

# 6. Setup USB Gadget (mtk_rndis for Windows compatibility)
log_kmsg "Setting up USB mtk_rndis gadget..."
setup_usb() {
    CFG="/config/usb_gadget/g1"
    mkdir -p "$CFG" 2>/dev/null
    cd "$CFG" || return 1

    echo "" > UDC 2>/dev/null || true

    # Точные параметры MediaTek/Nothing из init.mt6878.usb.rc
    echo 0x0e8d > idVendor 2>/dev/null
    echo 0x2004 > idProduct 2>/dev/null
    echo 0x0200 > bcdUSB 2>/dev/null
    echo 0x00 > bDeviceClass 2>/dev/null
    echo 0x00 > bDeviceSubClass 2>/dev/null
    echo 0x00 > bDeviceProtocol 2>/dev/null

    mkdir -p strings/0x409 configs/b.1/strings/0x409 2>/dev/null
    echo "0123456789ABCDEF" > strings/0x409/serialnumber 2>/dev/null
    echo "Nothing" > strings/0x409/manufacturer 2>/dev/null
    echo "Phone (3a) Lite" > strings/0x409/product 2>/dev/null
    echo "rndis" > configs/b.1/strings/0x409/configuration 2>/dev/null
    echo 500 > configs/b.1/MaxPower 2>/dev/null

    # Родное имя функции из init.mt6878.usb.rc: mtk_rndis.gs4
    FUNC=""
    for cand in mtk_rndis.gs4 ncm.gs6 rndis.usb0 ncm.usb0; do
        if mkdir -p "functions/$cand" 2>/dev/null; then
            FUNC="functions/$cand"
            break
        fi
    done

    [ -n "$FUNC" ] || return 1
    ln -sf "$CFG/$FUNC" "$CFG/configs/b.1/f1" 2>/dev/null
    log_kmsg "Configured USB gadget function: $FUNC"

    # Ensure Nothing USB switch and Type-C mux drivers are active (nt_usb_ts without nt_chg)
    for m in charger_class.ko adapter_class.ko mtk_charger_algorithm_class.ko pd_dbg_info.ko tcpc_class.ko tcpc_mt6375.ko phy-mtk-xsphy.ko mtu3.ko mt6375-charger.ko mt6375_charger.ko mtk_charger_framework.ko extcon-mtk-usb.ko extcon_mtk_usb.ko nt_usb_ts.ko; do
        [ -f "/modules/$m" ] && insmod "/modules/$m" 2>/dev/null
    done
    echo "usb_ts" > /sys/bus/platform/drivers/usb_ts/bind 2>/dev/null || true

    # Force USB controller & PHY power and mode
    echo 1 > /sys/devices/platform/soc/11201000.usb0/mode 2>/dev/null || true
    echo "11280000.i2c:mt6375@34:adc" > /sys/bus/platform/drivers/mt6375-adc/bind 2>/dev/null || true
    echo "11280000.i2c:mt6375@34:tcpc" > /sys/bus/platform/drivers/mt6375-tcpc/bind 2>/dev/null || true
    echo "11280000.i2c:mt6375@34:chg" > /sys/bus/platform/drivers/mt6375-chg/bind 2>/dev/null || true
    echo "extcon-usb" > /sys/bus/platform/drivers/mtk-extcon-usb/bind 2>/dev/null || true
    echo "11201000.usb0" > /sys/bus/platform/drivers/mtu3/bind 2>/dev/null || true

    UDC_NAME=$(ls /sys/class/udc 2>/dev/null | head -n 1)

    # Отключаем saving у mtu3 перед привязкой UDC (обязательно из init.mt6878.usb.rc!)
    echo 0 > "/sys/class/udc/$UDC_NAME/device/saving" 2>/dev/null || true
    echo "device" > /sys/class/usb_role/11201000.usb0-role-switch/role 2>/dev/null || true
    sleep 0.3

    echo "$UDC_NAME" > UDC 2>/dev/null
    log_kmsg "Successfully bound UDC: $UDC_NAME"
    cd /

    sleep 1
    ifconfig lo 127.0.0.1 up 2>/dev/null || true
    ACTIVE_IF="rndis0"
    for try in $(seq 1 20); do
        for iface in rndis0 usb0 eth0; do
            if [ -d "/sys/class/net/$iface" ]; then
                ACTIVE_IF="$iface"
                break 2
            fi
        done
        sleep 0.5
    done
    ifconfig "$ACTIVE_IF" 172.16.42.1 netmask 255.255.255.0 up 2>/dev/null
    log_kmsg "Network $ACTIVE_IF is UP (172.16.42.1)"

    mkdir -p /var/lib/misc /tmp /dev/pts
    mountpoint -q /dev/pts || mount -t devpts -o ptmxmode=0666,gid=5,mode=620 devpts /dev/pts 2>/dev/null || mount -t devpts devpts /dev/pts 2>/dev/null || true
    [ -c /dev/pts/ptmx ] && chmod 666 /dev/pts/ptmx 2>/dev/null || true
    [ -e /dev/ptmx ] || ln -sf pts/ptmx /dev/ptmx 2>/dev/null || true
    [ -c /dev/ptmx ] && chmod 666 /dev/ptmx 2>/dev/null || true
    touch /var/lib/misc/udhcpd.leases

    # БЕЗ opt router и opt dns — чтобы на ноутбуке НЕ пропадал интернет по Wi-Fi!
    cat << EOF_DHCP > /tmp/udhcpd.conf
start 172.16.42.2
end 172.16.42.10
interface $ACTIVE_IF
opt subnet 255.255.255.0
EOF_DHCP

    (/bin/busybox udhcpd -S /tmp/udhcpd.conf 2>/dev/null || /bin/busybox-extras udhcpd -S /tmp/udhcpd.conf 2>/dev/null || udhcpd -S /tmp/udhcpd.conf 2>/dev/null) &

    # 1. Полноценный Telnet-сервер на стандартном порту 23
    /bin/busybox-extras telnetd -p 23 -l /bin/sh 2>/dev/null || /bin/busybox telnetd -p 23 -l /bin/sh 2>/dev/null &

    # 2. Резервный Telnet-сервер на порту 2324
    /bin/busybox-extras telnetd -p 2324 -l /bin/sh 2>/dev/null || /bin/busybox telnetd -p 2324 -l /bin/sh 2>/dev/null &

    # 3. Супервизор: гарантирует постоянный перезапуск telnetd на порту 23
    (
        while true; do
            if ! pidof telnetd >/dev/null 2>&1; then
                /bin/busybox-extras telnetd -p 23 -l /bin/sh 2>/dev/null || /bin/busybox telnetd -p 23 -l /bin/sh 2>/dev/null || telnetd -p 23 -l /bin/sh 2>/dev/null
            fi
            sleep 2
        done
    ) &

    # 4. Сырой командный сокет на порту 2323 (для скриптов и автоматизации)
    /bin/busybox-extras tcpsvd 0.0.0.0 2323 /bin/sh 2>/dev/null &
    (
        while true; do
            /bin/busybox nc -ll -p 2323 -e /bin/sh 2>/dev/null || /bin/busybox-extras nc -ll -p 2323 -e /bin/sh 2>/dev/null || nc -ll -p 2323 -e /bin/sh 2>/dev/null || sleep 2
        done
    ) &

    log_kmsg "udhcpd, telnetd (ports 23, 2324), and raw shell (2323) started on $ACTIVE_IF"
}
setup_usb

# 7. Discover super partition & Map pmos_root
log_kmsg "Discovering super partition..."
SUPER_DEV=""

for attempt in $(seq 1 30); do
    mdev -s 2>/dev/null
    if [ -b /dev/block/by-name/super ]; then
        SUPER_DEV="/dev/block/by-name/super"
        break
    fi
    if [ -b /dev/block/sdc83 ]; then
        SUPER_DEV="/dev/block/sdc83"
        break
    fi
    for uevent in /sys/class/block/*/uevent; do
        if grep -q "PARTNAME=super$" "$uevent" 2>/dev/null; then
            dev_name=$(grep "^DEVNAME=" "$uevent" | cut -d= -f2)
            if [ -n "$dev_name" ]; then
                SUPER_DEV="/dev/$dev_name"
                [ -b "$SUPER_DEV" ] || mknod "$SUPER_DEV" b $(grep "^MAJOR=" "$uevent" | cut -d= -f2) $(grep "^MINOR=" "$uevent" | cut -d= -f2) 2>/dev/null
                break
            fi
        fi
    done
    [ -n "$SUPER_DEV" ] && break
    sleep 0.2
done

log_kmsg "Super dev: $SUPER_DEV"

MOUNT_SUCCESS=0
mkdir -p /sysroot /dev/mapper
[ -c /dev/mapper/control ] || mknod /dev/mapper/control c 10 236 2>/dev/null

if [ -n "$SUPER_DEV" ]; then
    log_kmsg "Mapping dm-linear device pmos_root (4800000 sectors at 13914592)..."
    dmsetup create pmos_root --table "0 4800000 linear $SUPER_DEV 13914592" 2>/dev/null
    mdev -s 2>/dev/null

    TARGET_DEV=""
    if [ -b /dev/mapper/pmos_root ]; then
        TARGET_DEV="/dev/mapper/pmos_root"
        log_kmsg "Device-mapper target ready: $TARGET_DEV"
    else
        log_kmsg "dmsetup mapping failed, trying losetup fallback (offset 7124271104)..."
        losetup -o 7124271104 /dev/loop0 "$SUPER_DEV" 2>/dev/null
        [ -b /dev/loop0 ] && TARGET_DEV="/dev/loop0"
    fi

    if [ -n "$TARGET_DEV" ]; then
        log_kmsg "Mounting rootfs from $TARGET_DEV on /sysroot..."
        if mount -t ext4 -o rw,noatime "$TARGET_DEV" /sysroot 2>/dev/null || \
           mount -t ext4 -o ro "$TARGET_DEV" /sysroot 2>/dev/null || \
           mount "$TARGET_DEV" /sysroot 2>/dev/null; then
            log_kmsg "SUCCESS: postmarketOS rootfs mounted on /sysroot!"
            mkdir -p /sysroot/etc/modprobe.d /sysroot/proc /sysroot/sys /sysroot/dev /sysroot/dev/shm /dev/shm 2>/dev/null
            mount --bind /proc /sysroot/proc 2>/dev/null || true
            mount --bind /sys /sysroot/sys 2>/dev/null || true
            mount --bind /dev /sysroot/dev 2>/dev/null || true
            mount -t tmpfs tmpfs /sysroot/dev/shm 2>/dev/null || true
            mount -t tmpfs tmpfs /dev/shm 2>/dev/null || true
            chmod 1777 /sysroot/dev/shm /dev/shm 2>/dev/null || true
            echo "blacklist vcp" > /sysroot/etc/modprobe.d/no-vcp.conf 2>/dev/null || true
            MOUNT_SUCCESS=1
        else
            log_kmsg "ERROR: Failed to mount rootfs from $TARGET_DEV!"
        fi
    else
        log_kmsg "ERROR: Neither dm-linear nor loop device could be initialized!"
    fi
else
    log_kmsg "ERROR: super partition not detected!"
fi

# Re-check network interfaces in case UDC settled
for iface in rndis0 usb0 eth0; do
    if [ -d "/sys/class/net/$iface" ]; then
        ifconfig "$iface" 172.16.42.1 netmask 255.255.255.0 up 2>/dev/null
    fi
done

# Synchronous log save to nt_log
if [ -d /mnt/nt_log ]; then
    log_kmsg "Flushing early dmesg to /mnt/nt_log/pmos_standalone_boot.log..."
    dmesg > /mnt/nt_log/pmos_standalone_boot.log 2>/dev/null
    sync
fi

# 9. STAGE 2 DEBUG MODE: switch_root disabled to keep Telnet & logging active
log_kmsg "=== STAGE 2 DEBUG MODE: Staying in Stage 2 with Telnet 172.16.42.1:23 ==="

# 1. Дожидаемся полного завершения mdev -s и монтирования разделов
sleep 2

# 2. Последовательно грузим модули дисплея (как в рабочем тесте HELLO PMOS)
log_kmsg "Loading MediaTek DRM display stack + Panel drivers sequentially..."

SYS_MOD="/sysroot/lib/modules/6.1.162-android14-11-ga92e11aaa8fc-dirty"

load_mod() {
    for d in /modules /lib/modules "$SYS_MOD"; do
        if [ -f "$d/$1" ]; then
            insmod "$d/$1" 2>/dev/null && return 0
        fi
    done
    return 1
}

DEPS="cmdq_helper_inf.ko cmdq-platform-mt6878.ko mtk-cmdq-drv-ext.ko drm_display_helper.ko mrdump.ko aee_aed.ko clk-common.ko mtk_disp_notify.ko mtk_panel_ext.ko drm_dma_helper.ko system_heap.ko iommu_debug.ko mtk-afe-external.ko vcp_status.ko mtk_sync.ko mtk_slbc.ko mtk-mbox.ko mtk_rpmsg_mbox.ko mtk_tinysys_ipi.ko scpsys-dummy.ko mtk-dvfsrc.ko emi.ko mtk-smi.ko mtk-smi-dbg.ko mtk_dramc.ko mtk-icc-core.ko mtk_bp_thl.ko leds-mtk.ko device-apc-common.ko nothing_error_report.ko mmprofile.ko irq-dbg.ko tinysys-scmi.ko mtk-mminfra-debug.ko"

for pass in 1 2 3; do
    for m in $DEPS; do
        load_mod "$m"
    done
    [ -c /dev/watchdog ] && echo 1 > /dev/watchdog 2>/dev/null || true
done

load_mod "mtk-mmdvfs-ftrace-safe.ko" && log_kmsg "FTRACE_OK"
load_mod "mtk-mmdvfs.ko"
load_mod "mtk-mmdvfs-v3.ko"
load_mod "mtk-mmdvfs-debug-safe.ko" && log_kmsg "DBG_OK"
load_mod "mmqos-common.ko" && log_kmsg "MMQOS_OK"
load_mod "mmqos-mt6878.ko" && log_kmsg "MMQOS_MT6878_OK"
load_mod "mtk-mminfra-debug.ko"
load_mod "mtk-mml.ko" && log_kmsg "MML_OK"
load_mod "mtk-mml-mt6878.ko" && log_kmsg "MML_MT6878_OK"
load_mod "mdp_drv_mt6878.ko" && log_kmsg "MDP_MT6878_OK"

load_mod "mediatek-drm-safe.ko" && log_kmsg "DRM_SAFE_OK"
load_mod "mediatek-drm-gateic.ko" && log_kmsg "GATEIC_OK"
load_mod "mediatek-drm-panel-drv.ko" && log_kmsg "PANEL_DRV_OK"

load_mod "panel-rm69220-boe.ko" && log_kmsg "BOE_OK"
load_mod "panel-rm69220-vxn.ko" && log_kmsg "VXN_OK"
load_mod "panel-epd8820-boe.ko" && log_kmsg "EPD_OK"

[ -c /dev/watchdog ] && echo 1 > /dev/watchdog 2>/dev/null || true
sleep 1
echo 1401a000.dsi0 > /sys/bus/platform/drivers_probe 2>/dev/null || true
[ -c /dev/watchdog ] && echo 1 > /dev/watchdog 2>/dev/null || true
sleep 1

mkdir -p /dev/dri
mknod /dev/dri/card0 c 226 0 2>/dev/null
mknod /dev/dri/renderD128 c 226 128 2>/dev/null

echo 2600 > /sys/devices/platform/display_id/brightnessid 2>/dev/null || true

mdev -s 2>/dev/null
log_kmsg "DRM card0 status: $(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null || echo 'unknown')"
log_kmsg "DRM card0 modes: $(cat /sys/class/drm/card0-DSI-1/modes 2>/dev/null || echo 'none')"

load_mod "bootinfo.ko" && log_kmsg "BOOTINFO_OK"
load_mod "ft3683g.ko" && log_kmsg "TOUCH_FT3683G_OK"
load_mod "eph861.ko" && log_kmsg "TOUCH_EPH861_OK"

# GPU Power & Panthor Driver Initialization
chroot /sysroot modprobe mtk_gpufreq_mt6878 2>/dev/null || true
echo power_on > /proc/gpufreqv2/mfgsys_power_control 2>/dev/null || true
load_mod "gpu-sched.ko"
load_mod "panthor.ko" && log_kmsg "PANTHOR_GPU_OK"
load_mod "galaxian_backlight.ko" && log_kmsg "GALAXIAN_BACKLIGHT_OK"

for i in $(seq 1 30); do
    if [ -e /sys/class/drm/renderD128 ]; then
        break
    fi
    sleep 0.1
done

mknod /dev/dri/card1 c 226 1 2>/dev/null
mknod /dev/dri/renderD128 c 226 128 2>/dev/null
mknod /sysroot/dev/dri/card1 c 226 1 2>/dev/null
mknod /sysroot/dev/dri/renderD128 c 226 128 2>/dev/null
chmod 666 /dev/dri/* /sysroot/dev/dri/* 2>/dev/null
chmod 666 /dev/uinput /sysroot/dev/uinput 2>/dev/null || true
chmod 666 /sys/class/backlight/panel/brightness /sysroot/sys/class/backlight/panel/brightness 2>/dev/null || true
chmod 666 /dev/input/* /sysroot/dev/input/* 2>/dev/null || true

# 3. Запуск DRM Boot Splash
if [ -x /bin/drm_splash ]; then
    log_kmsg "Starting DRM Boot Splash..."
    /bin/drm_splash &
fi

# 3.5. Deploy Galaxian system scripts and configuration to sysroot
if [ -d /etc/galaxian ]; then
    log_kmsg "Deploying Galaxian scripts and configs to /sysroot..."
    mkdir -p /sysroot/usr/bin /sysroot/etc/polkit-1/rules.d 2>/dev/null
    cp -f /etc/galaxian/start_phosh_direct.sh /sysroot/usr/bin/start_phosh_direct.sh 2>/dev/null || true
    cp -f /etc/galaxian/phosh_session_start.sh /sysroot/usr/bin/phosh_session_start.sh 2>/dev/null || true
    cp -f /etc/galaxian/galaxian_wifi_bringup.sh /sysroot/usr/bin/galaxian_wifi_bringup.sh 2>/dev/null || true
    cp -f /etc/galaxian/send_nvram.py /sysroot/usr/bin/send_nvram.py 2>/dev/null || true
    cp -f /etc/galaxian/galaxian_helper_daemon.py /sysroot/usr/bin/galaxian_helper_daemon.py 2>/dev/null || true
    cp -f /etc/galaxian/00-galaxian-user.rules /sysroot/etc/polkit-1/rules.d/00-galaxian-user.rules 2>/dev/null || true
    chmod 755 /sysroot/usr/bin/start_phosh_direct.sh /sysroot/usr/bin/phosh_session_start.sh /sysroot/usr/bin/galaxian_wifi_bringup.sh /sysroot/usr/bin/send_nvram.py /sysroot/usr/bin/galaxian_helper_daemon.py 2>/dev/null || true
    chmod 644 /sysroot/etc/polkit-1/rules.d/00-galaxian-user.rules 2>/dev/null || true
fi

# 4. Запуск Phosh Shell
if [ -x /sysroot/usr/bin/start_phosh_direct.sh ]; then
    log_kmsg "Launching Phosh Desktop Shell..."
    /sysroot/usr/bin/start_phosh_direct.sh &
fi

# 5. Далее идёт основной цикл while true (watchdog)
while true; do
    if [ -c /dev/watchdog ]; then
        echo 1 > /dev/watchdog 2>/dev/null
    fi
    if [ -d /sys/class/leds/noth_leds ]; then
        echo 255 > /sys/class/leds/noth_leds/brightness 2>/dev/null
        echo 1 > /sys/class/leds/noth_leds/state 2>/dev/null
    fi
    # Screen brightness and DPMS managed dynamically by Phosh
    if [ -d /mnt/nt_log ]; then
        dmesg > /mnt/nt_log/pmos_standalone_boot.log 2>/dev/null
        dmesg > /mnt/nt_log/recovery_log/pmos_standalone_boot.log 2>/dev/null
        dmesg > /mnt/nt_log/recovery_log/NTrecovery_99_pmos/recovery.log 2>/dev/null
    fi
    if mountpoint -q /mnt/meta 2>/dev/null; then
        dmesg > /mnt/meta/pmos_boot.log 2>/dev/null
    fi
    sync
    sleep 2
done
