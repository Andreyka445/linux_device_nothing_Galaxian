import sys
import os
import math
import struct
import threading
import subprocess
import time
import gi
gi.require_version('Gio', '2.0')
gi.require_version('GLib', '2.0')
from gi.repository import Gio, GLib

INTROSPECTION_XML = """
<node>
  <interface name="org.freedesktop.login1.Manager">
    <method name="GetSession">
      <arg type="s" name="id" direction="in"/>
      <arg type="o" name="session" direction="out"/>
    </method>
    <method name="GetSessionByPID">
      <arg type="u" name="pid" direction="in"/>
      <arg type="o" name="session" direction="out"/>
    </method>
    <method name="Inhibit">
      <arg type="s" name="what" direction="in"/>
      <arg type="s" name="who" direction="in"/>
      <arg type="s" name="why" direction="in"/>
      <arg type="s" name="mode" direction="in"/>
      <arg type="h" name="fd" direction="out"/>
    </method>
  </interface>
  <interface name="org.freedesktop.login1.Session">
    <method name="SetBrightness">
      <arg type="s" name="subsystem" direction="in"/>
      <arg type="s" name="name" direction="in"/>
      <arg type="u" name="brightness" direction="in"/>
    </method>
    <method name="TakeControl">
      <arg type="b" name="force" direction="in"/>
    </method>
    <method name="ReleaseControl">
    </method>
    <method name="Lock">
    </method>
    <method name="Unlock">
    </method>
    <property name="Id" type="s" access="read"/>
    <property name="Name" type="s" access="read"/>
    <property name="Active" type="b" access="read"/>
    <property name="State" type="s" access="read"/>
    <property name="Type" type="s" access="read"/>
    <property name="Class" type="s" access="read"/>
  </interface>
</node>
"""

# State management
screen_blanked = False
last_user_hw_brightness = 2600  # Default initial brightness
MIN_BRIGHTNESS = 120
MAX_BRIGHTNESS = 4095

def map_raw_to_hw(raw_val):
    """
    Phosh sends a non-linear value (roughly s^2 * 4095).
    We take sqrt to linearize the slider response, then map to [MIN_BRIGHTNESS, MAX_BRIGHTNESS].
    This ensures 50% slider corresponds to ~2100 (comfortable brightness),
    and brightness scales evenly across the full 0% - 100% range.
    """
    if raw_val <= 0:
        return 0
    norm = min(max(raw_val / 4095.0, 0.0), 1.0)
    linear_fraction = math.sqrt(norm)
    hw_val = int(MIN_BRIGHTNESS + (MAX_BRIGHTNESS - MIN_BRIGHTNESS) * linear_fraction)
    return min(max(hw_val, MIN_BRIGHTNESS), MAX_BRIGHTNESS)

def get_user_dbus_addr():
    try:
        p = subprocess.run(["pidof", "phosh"], capture_output=True, text=True)
        pid = p.stdout.strip().split()[0]
        with open(f"/proc/{pid}/environ", "rb") as f:
            for env in f.read().split(b"\0"):
                if env.startswith(b"DBUS_SESSION_BUS_ADDRESS="):
                    return env.split(b"=", 1)[1].decode()
    except:
        pass
    return None

def run_user_cmd(cmd):
    dbus_addr = get_user_dbus_addr()
    env_str = "export XDG_RUNTIME_DIR=/run/user/10000; "
    if dbus_addr:
        env_str += f"export DBUS_SESSION_BUS_ADDRESS='{dbus_addr}'; "
    full_cmd = f"su - user -c \"{env_str} {cmd}\""
    subprocess.run(full_cmd, shell=True)

def toggle_screen():
    global screen_blanked, last_user_hw_brightness
    if not screen_blanked:
        print(f"[power] Turning screen OFF. Preserved brightness: {last_user_hw_brightness}", flush=True)
        screen_blanked = True
        run_user_cmd("gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true")
        run_user_cmd("gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.Lock")
        try:
            with open("/sys/devices/platform/display_id/brightnessid", "w") as f:
                f.write("0\n")
        except:
            pass
    else:
        print(f"[power] Turning screen ON. Restoring brightness: {last_user_hw_brightness}", flush=True)
        try:
            with open("/sys/devices/platform/display_id/brightnessid", "w") as f:
                f.write(f"{last_user_hw_brightness}\n")
        except:
            pass
        run_user_cmd("gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false")
        screen_blanked = False

def input_listener(dev_path):
    print(f"[input] Monitoring {dev_path}...", flush=True)
    fmt = "qqHHi"
    event_size = struct.calcsize(fmt)
    try:
        with open(dev_path, "rb") as fd:
            while True:
                data = fd.read(event_size)
                if len(data) < event_size:
                    break
                _, _, ev_type, ev_code, ev_val = struct.unpack(fmt, data)
                if ev_type == 1: # EV_KEY
                    if ev_code == 115 and ev_val in (1, 2): # KEY_VOLUMEUP
                        print("[input] KEY_VOLUMEUP -> +5%", flush=True)
                        run_user_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%")
                    elif ev_code == 114 and ev_val in (1, 2): # KEY_VOLUMEDOWN
                        print("[input] KEY_VOLUMEDOWN -> -5%", flush=True)
                        run_user_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%")
                    elif ev_code == 116 and ev_val == 1: # KEY_POWER
                        print("[input] KEY_POWER press -> toggle_screen()", flush=True)
                        toggle_screen()
    except Exception as e:
        print(f"[input] Listener for {dev_path} stopped: {e}", flush=True)

class Login1Daemon:
    def __init__(self):
        self.node_info = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION_XML)
        self.mgr_iface = self.node_info.lookup_interface("org.freedesktop.login1.Manager")
        self.session_iface = self.node_info.lookup_interface("org.freedesktop.login1.Session")
        self.owner_id = Gio.bus_own_name(
            Gio.BusType.SYSTEM,
            "org.freedesktop.login1",
            Gio.BusNameOwnerFlags.REPLACE,
            self.on_bus_acquired,
            self.on_name_acquired,
            self.on_name_lost
        )

    def on_bus_acquired(self, conn, name):
        print(f"[login1] Bus acquired for {name}", flush=True)
        conn.register_object("/org/freedesktop/login1", self.mgr_iface, self.handle_mgr_call, None, None)
        for path in ["/org/freedesktop/login1/session/c1", "/org/freedesktop/login1/session/auto", "/org/freedesktop/login1/session/self"]:
            conn.register_object(path, self.session_iface, self.handle_session_call, self.handle_session_prop, None)

    def on_name_acquired(self, conn, name):
        print(f"[login1] Successfully acquired name: {name}", flush=True)

    def on_name_lost(self, conn, name):
        print(f"[login1] Name lost: {name}", flush=True)

    def handle_mgr_call(self, conn, sender, path, iface, method, params, invocation):
        if method in ["GetSession", "GetSessionByPID"]:
            invocation.return_value(GLib.Variant("(o)", ("/org/freedesktop/login1/session/c1",)))
        elif method == "Inhibit":
            r, w = os.pipe()
            fd_list = Gio.UnixFDList.new_from_array([r])
            invocation.return_value_with_unix_fd_list(GLib.Variant("(h)", (0,)), fd_list)
        else:
            invocation.return_value(None)

    def handle_session_call(self, conn, sender, path, iface, method, params, invocation):
        global screen_blanked, last_user_hw_brightness
        val = params.unpack()
        if method == "SetBrightness":
            subsystem, name, raw_brightness = val
            hw_brightness = map_raw_to_hw(raw_brightness)
            
            # If screen is active and user is sliding brightness, remember the setting
            if not screen_blanked and hw_brightness > 0:
                last_user_hw_brightness = hw_brightness
                print(f"[login1] SetBrightness raw={raw_brightness} -> hw={hw_brightness} (saved: {last_user_hw_brightness})", flush=True)
                try:
                    with open("/sys/devices/platform/display_id/brightnessid", "w") as f:
                        f.write(f"{hw_brightness}\n")
                except Exception as e:
                    print(f"[login1] Error writing brightness: {e}", flush=True)
            elif screen_blanked:
                print(f"[login1] Ignored SetBrightness raw={raw_brightness} while screen is blanked", flush=True)
            
            invocation.return_value(None)
        elif method in ["TakeControl", "ReleaseControl", "Lock", "Unlock"]:
            invocation.return_value(None)
        else:
            invocation.return_value(None)

    def handle_session_prop(self, conn, sender, path, iface, prop):
        props = {
            "Id": GLib.Variant("s", "c1"),
            "Name": GLib.Variant("s", "user"),
            "Active": GLib.Variant("b", True),
            "State": GLib.Variant("s", "active"),
            "Type": GLib.Variant("s", "wayland"),
            "Class": GLib.Variant("s", "user"),
        }
        return props.get(prop, None)

if __name__ == "__main__":
    import signal
    signal.signal(signal.SIGUSR1, lambda s, f: toggle_screen())
    d = Login1Daemon()
    
    t0 = threading.Thread(target=input_listener, args=("/dev/input/event0",), daemon=True)
    t1 = threading.Thread(target=input_listener, args=("/dev/input/event1",), daemon=True)
    t0.start()
    t1.start()
    
    loop = GLib.MainLoop()
    loop.run()
