#!/usr/bin/env python3
"""Run a command in a pty smaller than the terminal, leaving a blank margin on every side.

  pty_inset.py COMMAND [ARGS...]

The command sees a terminal M cells smaller on each side. Its output is shifted by M with the cursor
addressing rewritten, and the scroll region is pinned inside the margin; mouse and cursor reports
coming back are shifted the other way.
"""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import tty

M = 1

OUT = re.compile(rb"\x1b\[([0-9;]*)([Hfd`Gr])|\r|\x1bE|\x1b\[\?(?:1049|1047|47)[hl]")
OUT_PARTIAL = re.compile(rb"\x1b(\[[0-9;?]*)?$")
IN = re.compile(rb"\x1b\[<(\d+);(\d+);(\d+)([Mm])|\x1b\[(\d+);(\d+);(\d+)M|\x1b\[(\d+);(\d+)R|\x1b\[M([\x20-\xff])([\x20-\xff])([\x20-\xff])")

resized = True
child_rows = 0
pending = b""


def term_size():
    rows, cols = struct.unpack("HHHH", fcntl.ioctl(1, termios.TIOCGWINSZ, b"\0" * 8))[:2]
    return rows, cols


def set_size(fd, rows, cols):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


def region(rows):
    return f"\x1b[{M + 1};{rows - M}r".encode()


def num(s, default):
    n = int(s) if s else default
    return n or default


def fix_out(m):
    text = m.group(0)
    if m.group(2) is None:
        if text == b"\r":
            return f"\x1b[{M + 1}G".encode()
        if text == b"\x1bE":
            return f"\x1bD\x1b[{M + 1}G".encode()
        return text + region(child_rows + 2 * M)
    parts = m.group(1).decode().split(";")
    final = m.group(2).decode()
    if final in "Hf":
        row = num(parts[0], 1)
        col = num(parts[1] if len(parts) > 1 else "", 1)
        return f"\x1b[{row + M};{col + M}H".encode()
    if final == "d":
        return f"\x1b[{num(parts[0], 1) + M}d".encode()
    if final in "G`":
        return f"\x1b[{num(parts[0], 1) + M}G".encode()
    top = num(parts[0], 1)
    bottom = num(parts[1] if len(parts) > 1 else "", child_rows)
    return f"\x1b[{top + M};{bottom + M}r".encode()


def out_filter(data):
    global pending
    data = pending + data
    pending = b""
    tail = OUT_PARTIAL.search(data)
    if tail:
        pending, data = data[tail.start():], data[:tail.start()]
    return OUT.sub(fix_out, data)


def back(n):
    return max(1, n - M)


def fix_in(m):
    g = m.groups()
    if g[0] is not None:
        return f"\x1b[<{g[0].decode()};{back(int(g[1]))};{back(int(g[2]))}{g[3].decode()}".encode()
    if g[4] is not None:
        return f"\x1b[{g[4].decode()};{back(int(g[5]))};{back(int(g[6]))}M".encode()
    if g[7] is not None:
        return f"\x1b[{back(int(g[7]))};{back(int(g[8]))}R".encode()
    cx, cy = g[10][0], g[11][0]
    return b"\x1b[M" + g[9] + bytes([max(33, cx - M), max(33, cy - M)])


def write_all(fd, data):
    while data:
        data = data[os.write(fd, data):]


def on_winch(*_):
    global resized
    resized = True


def main():
    global resized, child_rows
    cmd = sys.argv[1:]
    if not cmd:
        sys.exit("usage: pty_inset.py COMMAND [ARGS...]")
    rows, cols = term_size()
    child_rows = rows - 2 * M
    pid, fd = pty.fork()
    if pid == 0:
        set_size(0, child_rows, cols - 2 * M)
        attrs = termios.tcgetattr(0)
        attrs[1] = (attrs[1] & ~termios.TABDLY) | termios.TAB3     # curses then avoids tabs, whose stops would be off by M
        termios.tcsetattr(0, termios.TCSANOW, attrs)
        try:
            os.execvp(cmd[0], cmd)
        except OSError as e:
            print(f"{cmd[0]}: {e.strerror}", file=sys.stderr)
            os._exit(127)
    signal.signal(signal.SIGWINCH, on_winch)
    saved = termios.tcgetattr(0)
    tty.setraw(0)
    try:
        while True:
            if resized:
                resized = False
                rows, cols = term_size()
                child_rows = rows - 2 * M
                set_size(fd, child_rows, cols - 2 * M)
                write_all(1, region(rows) + f"\x1b[{M + 1};{M + 1}H".encode())
            try:
                ready = select.select([0, fd], [], [], 0.2)[0]
            except InterruptedError:
                continue
            if 0 in ready:
                data = os.read(0, 65536)
                if not data:
                    break
                write_all(fd, IN.sub(fix_in, data))
            if fd in ready:
                try:
                    data = os.read(fd, 65536)
                except OSError:
                    break
                if not data:
                    break
                write_all(1, out_filter(data))
    finally:
        termios.tcsetattr(0, termios.TCSADRAIN, saved)
        write_all(1, b"\x1b[r\x1b[?25h")
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status))


if __name__ == "__main__":
    main()
