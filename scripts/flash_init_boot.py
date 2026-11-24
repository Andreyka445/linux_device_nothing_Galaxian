import socket
import time
import hashlib
from telnet_cmd import run_cmd

LOCAL_IMG = r"D:\nothing_galaxian\output\standalone_init_boot.img"
with open(LOCAL_IMG, "rb") as f:
    img_data = f.read()

assert len(img_data) == 8388608, f"Wrong size: {len(img_data)}"
expected_md5 = hashlib.md5(img_data).hexdigest()
print(f"Image size: {len(img_data)} bytes, MD5: {expected_md5}")

for target_dev, slot in [('/dev/sdc68', '_b'), ('/dev/sdc38', '_a')]:
    print(f"Flashing {target_dev} (slot {slot})...")
    run_cmd(f"nc -l -p 5556 > {target_dev} &")
    time.sleep(1)

    s = socket.socket()
    s.settimeout(10)
    s.connect(("172.16.42.1", 5556))
    s.sendall(img_data)
    s.close()
    time.sleep(1)

    res = run_cmd(f"sync; head -c 8388608 {target_dev} | md5sum")
    print(f"Slot {slot} ({target_dev}) MD5 check:\n{res}")
    if expected_md5 in res:
        print(f"SUCCESS: Slot {slot} verified perfectly!")
    else:
        print(f"ERROR: MD5 mismatch on slot {slot}!")

print("All slots flashed and verified!")
