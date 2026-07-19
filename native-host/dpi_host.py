#!/usr/bin/env python3
"""FALLBACK native messaging host (Python). The default host is PowerShell
(dpi_host.ps1), which needs no dependencies. If the PowerShell host misbehaves
on your machine and you have Python installed, edit dpi_host.bat to call this
file instead:  python "%~dp0dpi_host.py"

Protocol (Chrome native messaging): 4-byte little-endian length + UTF-8 JSON.
"""
import sys, os, json, struct, shlex, subprocess, time, signal

BASE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(BASE, "ciadpi.pid")
LOG = os.path.join(BASE, "host.log")
ERRLOG = os.path.join(BASE, "ciadpi.err")  # captured stderr of the last launch
IS_WIN = os.name == "nt"


def log(*a):
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(" ".join(str(x) for x in a) + "\n")
    except OSError:
        pass


def read_message():
    raw_len = sys.stdin.buffer.read(4)
    if len(raw_len) < 4:
        return None
    (length,) = struct.unpack("<I", raw_len)
    return json.loads(sys.stdin.buffer.read(length).decode("utf-8"))


def send_message(obj):
    data = json.dumps(obj).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def find_exe():
    exe_name = "ciadpi.exe" if IS_WIN else "ciadpi"
    for c in [os.environ.get("CIADPI_EXE"), os.path.join(BASE, exe_name),
              os.path.join(BASE, "..", "backend", exe_name)]:
        if c and os.path.isfile(c):
            return os.path.abspath(c)
    return None


def read_state():
    try:
        with open(STATE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def write_state(pid, port):
    with open(STATE, "w", encoding="utf-8") as f:
        json.dump({"pid": pid, "port": port}, f)


def clear_state():
    try:
        os.remove(STATE)
    except OSError:
        pass


def is_alive(pid):
    if not pid:
        return False
    if IS_WIN:
        import ctypes
        k = ctypes.windll.kernel32
        h = k.OpenProcess(0x1000, False, int(pid))
        if not h:
            return False
        try:
            code = ctypes.c_ulong()
            if not k.GetExitCodeProcess(h, ctypes.byref(code)):
                return False
            return code.value == 259
        finally:
            k.CloseHandle(h)
    try:
        os.kill(int(pid), 0)
        return True
    except OSError:
        return False


def kill(pid):
    if not pid:
        return
    if IS_WIN:
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       creationflags=0x08000000)
        return
    # ciadpi ignores SIGTERM on macOS/Linux, so a plain TERM leaves the proxy
    # bound to the port and the next start fails with "Address already in use".
    # Send TERM first (graceful), then escalate to KILL if it's still alive.
    try:
        os.kill(int(pid), signal.SIGTERM)
    except OSError:
        return
    for _ in range(5):
        time.sleep(0.1)
        try:
            os.kill(int(pid), 0)
        except OSError:
            return  # exited
    try:
        os.kill(int(pid), signal.SIGKILL)
    except OSError:
        pass


def reap_orphans(exe):
    """Kill any lingering ciadpi we started earlier but no longer track.

    The common failure is an orphaned instance still bound to the proxy port:
    the next launch then dies with "bind: Address already in use" (rc 255).
    We only ever match OUR own binary path, so nothing else is touched.
    """
    if IS_WIN:
        subprocess.run(["taskkill", "/IM", os.path.basename(exe), "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       creationflags=0x08000000)
        return
    # SIGTERM (pkill default) is ignored by ciadpi, so force-kill by binary path.
    try:
        subprocess.run(["pkill", "-9", "-f", exe],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass  # pkill absent — best effort


def start_ciadpi(user_args, port):
    exe = find_exe()
    if not exe:
        return {"ok": False, "error": "ciadpi.exe not found"}
    st = read_state()
    if st and is_alive(st.get("pid")):
        kill(st.get("pid"))
        time.sleep(0.3)
    reap_orphans(exe)   # free the port from any untracked previous launch
    time.sleep(0.3)
    cmd = [exe, "-i", "127.0.0.1", "-p", str(int(port))] + shlex.split(user_args or "")
    # Capture stderr so a startup failure (bad arg, port in use, ...) is visible
    # to the extension instead of a bare exit code.
    try:
        errf = open(ERRLOG, "w", encoding="utf-8")
    except OSError:
        errf = subprocess.DEVNULL
    if IS_WIN:
        flags = 0x00000008 | 0x00000200 | 0x08000000
        p = subprocess.Popen(cmd, creationflags=flags, close_fds=True,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=errf, cwd=os.path.dirname(exe))
    else:
        p = subprocess.Popen(cmd, start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=errf, cwd=os.path.dirname(exe))
    time.sleep(0.4)
    if hasattr(errf, "close"):
        errf.close()
    if p.poll() is not None:
        stderr_tail = read_errlog()
        log("start failed rc", p.returncode, "cmd", cmd, "stderr", stderr_tail)
        msg = "ciadpi exited immediately (rc=%s)" % p.returncode
        if stderr_tail:
            msg += ": " + stderr_tail
        return {"ok": False, "error": msg, "rc": p.returncode, "cmd": cmd, "stderr": stderr_tail}
    write_state(p.pid, int(port))
    log("started", exe, "pid", p.pid, "cmd", cmd)
    return {"ok": True, "running": True, "pid": p.pid, "exe": exe}


def read_errlog():
    try:
        with open(ERRLOG, "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip()[-500:]
    except OSError:
        return ""


def stop_ciadpi():
    st = read_state()
    if st and st.get("pid"):
        kill(st["pid"])
    clear_state()
    return {"ok": True, "running": False}


def status():
    st = read_state()
    if st and is_alive(st.get("pid")):
        return {"ok": True, "running": True, "pid": st.get("pid"), "port": st.get("port")}
    return {"ok": True, "running": False}


def handle(msg):
    cmd = (msg or {}).get("cmd")
    if cmd == "start":
        return start_ciadpi(msg.get("args", ""), msg.get("port", 1080))
    if cmd == "stop":
        return stop_ciadpi()
    if cmd == "status":
        return status()
    if cmd == "ping":
        return {"ok": True, "version": "1.0.0", "exe": find_exe()}
    return {"ok": False, "error": "unknown cmd: %s" % cmd}


def main():
    try:
        msg = read_message()
        if msg is None:
            return
        send_message(handle(msg))
    except Exception as e:  # noqa: BLE001
        log("ERROR", repr(e))
        try:
            send_message({"ok": False, "error": str(e)})
        except Exception:
            pass


if __name__ == "__main__":
    main()
