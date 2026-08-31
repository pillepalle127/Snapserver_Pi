#!/usr/bin/env python3
"""BlueZ Agent1 for a headless, speaker-like appliance.

New pairing requests are accepted only while the runtime flag exists. Service
requests from already paired devices remain authorized, allowing reconnects
after the three-minute pairing window has closed.
"""
import os
import sys
from gi.repository import GLib
import dbus
import dbus.service
import dbus.mainloop.glib

AGENT_PATH = "/com/pillepalle127/SnapserverPiAgent"
PAIRING_FLAG = "/run/snapserver-pi/pairing-open"
BLUEZ = "org.bluez"
AGENT_IFACE = "org.bluez.Agent1"
PROPS_IFACE = "org.freedesktop.DBus.Properties"

class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"

class Agent(dbus.service.Object):
    def __init__(self, bus, loop):
        self.bus, self.loop = bus, loop
        super().__init__(bus, AGENT_PATH)

    def pairing_open(self):
        return os.path.exists(PAIRING_FLAG)

    def is_paired(self, device):
        try:
            props = dbus.Interface(self.bus.get_object(BLUEZ, device), PROPS_IFACE)
            return bool(props.Get("org.bluez.Device1", "Paired"))
        except dbus.DBusException:
            return False

    def require_pairing_window(self):
        if not self.pairing_open():
            raise Rejected("Pairing window is closed")

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        GLib.idle_add(self.loop.quit)

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        self.require_pairing_window()
        return "0000"

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        self.require_pairing_window()
        return dbus.UInt32(0)

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        self.require_pairing_window()

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        if not (self.pairing_open() or self.is_paired(device)):
            raise Rejected("Device is not paired and pairing window is closed")

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        if not (self.pairing_open() or self.is_paired(device)):
            raise Rejected("Service authorization rejected")

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode): pass

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered): pass

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self): pass

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus, loop = dbus.SystemBus(), GLib.MainLoop()
    Agent(bus, loop)
    manager = dbus.Interface(bus.get_object(BLUEZ, "/org/bluez"), "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
    manager.RequestDefaultAgent(AGENT_PATH)
    print("snapserver-pi-agent: registered as default NoInputNoOutput agent", flush=True)
    loop.run()

if __name__ == "__main__":
    try: main()
    except dbus.DBusException as exc:
        print(f"snapserver-pi-agent: {exc}", file=sys.stderr)
        raise
