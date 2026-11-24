import os
import sys
import time

def main():
    if os.path.exists('/sys/class/net/wlan0'):
        print("wlan0 already exists, Wi-Fi is already powered on.")
        return

    nvram_path = '/lib/firmware/WIFI_NVRAM'
    if not os.path.exists(nvram_path):
        nvram_path = '/sysroot/lib/firmware/WIFI_NVRAM'
    if not os.path.exists(nvram_path):
        nvram_path = '/tmp/WIFI'

    if not os.path.exists(nvram_path):
        print(f"Error: NVRAM file not found at {nvram_path}")
        return

    with open(nvram_path, 'rb') as f:
        nvram_data = f.read()

    print(f"Read NVRAM data: {len(nvram_data)} bytes from {nvram_path}")

    header = b"WR-BUF:NVRAM"
    payload = header + nvram_data

    wmt_dev = '/dev/wmtWifi'
    if not os.path.exists(wmt_dev):
        print(f"Error: {wmt_dev} does not exist!")
        return

    try:
        with open(wmt_dev, 'wb', buffering=0) as f:
            written = f.write(payload)
            print(f"Written NVRAM to {wmt_dev}: {written} bytes")
    except Exception as e:
        print(f"Error writing NVRAM: {e}")
        return

    time.sleep(0.5)

    print("Powering ON Wi-Fi...")
    try:
        with open(wmt_dev, 'wb', buffering=0) as f:
            f.write(b"1\n")
        print("Power ON sent successfully!")
    except Exception as e:
        print(f"Error sending Power ON: {e}")

if __name__ == '__main__':
    main()
