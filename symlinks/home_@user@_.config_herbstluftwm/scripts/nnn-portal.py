#!/usr/bin/env python3
"""An xdg-desktop-portal FileChooser backend that opens nnn.

Every open, folder and save dialog runs nnn in the urxvt wrapper window through
nnn-wrap.sh --pick; whatever it writes to the output file is returned to the application.
"""
import os
import subprocess
import tempfile

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

BUS_NAME = "org.freedesktop.impl.portal.desktop.nnn"
OBJECT_PATH = "/org/freedesktop/portal/desktop"
WRAP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nnn-wrap.sh")
TERMINAL = os.environ.get("NNN_PORTAL_TERMINAL", "urxvt -name wrapper").split()

FILE_CHOOSER_XML = """
<node>
  <interface name="org.freedesktop.impl.portal.FileChooser">
    <method name="OpenFile">
      <arg type="o" name="handle" direction="in"/>
      <arg type="s" name="app_id" direction="in"/>
      <arg type="s" name="parent_window" direction="in"/>
      <arg type="s" name="title" direction="in"/>
      <arg type="a{sv}" name="options" direction="in"/>
      <arg type="u" name="response" direction="out"/>
      <arg type="a{sv}" name="results" direction="out"/>
    </method>
    <method name="SaveFile">
      <arg type="o" name="handle" direction="in"/>
      <arg type="s" name="app_id" direction="in"/>
      <arg type="s" name="parent_window" direction="in"/>
      <arg type="s" name="title" direction="in"/>
      <arg type="a{sv}" name="options" direction="in"/>
      <arg type="u" name="response" direction="out"/>
      <arg type="a{sv}" name="results" direction="out"/>
    </method>
  </interface>
</node>
"""

REQUEST_XML = """
<node>
  <interface name="org.freedesktop.impl.portal.Request">
    <method name="Close"/>
  </interface>
</node>
"""

DONE, CANCELLED, FAILED = 0, 1, 2

requests = {}


def path_option(options, key):
    value = options.get(key)
    if not value:
        return None
    return bytes(value).rstrip(b"\0").decode(errors="replace")


def reply(invocation, response, uris=()):
    results = {"uris": GLib.Variant("as", list(uris))} if uris else {}
    invocation.return_value(GLib.Variant("(ua{sv})", (response, results)))


def finish(handle, status):
    request = requests.pop(handle, None)
    if request is None:
        return
    response, uris = CANCELLED, []
    try:
        request["connection"].unregister_object(request["registration"])
        # nnn removes the output file itself when nothing was picked
        if os.path.exists(request["out"]):
            with open(request["out"], "rb") as f:
                lines = [line for line in f.read().decode(errors="replace").splitlines() if line]
            if not request["closed"] and lines and all(os.path.isabs(line) for line in lines):
                response, uris = DONE, [GLib.filename_to_uri(line, None) for line in lines]
    except Exception:
        response, uris = FAILED, []
    finally:
        try:
            os.unlink(request["out"])
        except FileNotFoundError:
            pass
        # the application waits for this reply, so it is always sent
        reply(request["invocation"], response, uris)


def on_request_call(connection, sender, object_path, interface, method, params, invocation):
    request = requests.get(object_path)
    if method == "Close" and request:
        request["closed"] = True
        request["process"].terminate()
    invocation.return_value(None)


def on_method_call(connection, sender, object_path, interface, method, params, invocation):
    handle, app_id, parent_window, title, options = params.unpack()

    if method == "SaveFile":
        mode = "save"
        start = path_option(options, "current_folder")
        current_file = path_option(options, "current_file")
        if not start and current_file:
            start = os.path.dirname(current_file)
        name = options.get("current_name") or (os.path.basename(current_file) if current_file else "")
    else:
        mode = "dir" if options.get("directory") else "file"
        start = path_option(options, "current_folder")
        name = ""

    if not start or not os.path.isdir(start):
        start = os.path.expanduser("~")

    fd, out = tempfile.mkstemp(prefix="nnn-portal-")
    os.close(fd)
    try:
        process = subprocess.Popen(
            [*TERMINAL, "-title", title or "nnn", "-e", WRAP, "--pick", mode, out, start, name]
        )
    except OSError:
        os.unlink(out)
        reply(invocation, FAILED)
        return

    registration = connection.register_object(
        handle, Gio.DBusNodeInfo.new_for_xml(REQUEST_XML).interfaces[0], on_request_call, None, None
    )
    requests[handle] = {
        "connection": connection,
        "registration": registration,
        "invocation": invocation,
        "process": process,
        "out": out,
        "closed": False,
    }
    GLib.child_watch_add(GLib.PRIORITY_DEFAULT, process.pid, lambda pid, status: finish(handle, status))


def on_bus_acquired(connection, name):
    connection.register_object(
        OBJECT_PATH, Gio.DBusNodeInfo.new_for_xml(FILE_CHOOSER_XML).interfaces[0], on_method_call, None, None
    )


def main():
    loop = GLib.MainLoop()
    Gio.bus_own_name(
        Gio.BusType.SESSION, BUS_NAME, Gio.BusNameOwnerFlags.NONE, on_bus_acquired, None, lambda c, n: loop.quit()
    )
    loop.run()


if __name__ == "__main__":
    main()
