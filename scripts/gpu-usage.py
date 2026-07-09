#!/usr/bin/env python3
"""Show a table of available GPUs and what is occupying them.

For each NVIDIA GPU it prints memory/utilization and the processes running on
it, resolving each process to its owning user and full command line. Works on
the local machine (default) or a remote host over SSH (--host).

No external dependencies -- uses nvidia-smi and ps.
"""
import argparse
import os
import shlex
import shutil
import subprocess
import sys
import time

# --- tiny color helper (auto-disabled when not a TTY or NO_COLOR set) ---------
_USE_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None

# Target host for data collection; None means run locally. Set from --host.
_HOST = None


def sh(argv):
    """Wrap a command list to run locally or on the remote host via SSH."""
    if _HOST:
        return ["ssh", "-o", "BatchMode=yes", _HOST,
                " ".join(shlex.quote(a) for a in argv)]
    return argv


def c(text, code):
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else str(text)


def bold(t):
    return c(t, "1")


def dim(t):
    return c(t, "2")


def run_smi(query, extra=None):
    """Run an nvidia-smi CSV query and return list of split, stripped rows."""
    cmd = ["nvidia-smi", f"--query-{query}", "--format=csv,noheader,nounits"]
    if extra:
        cmd += extra
    out = subprocess.check_output(sh(cmd), text=True, stderr=subprocess.PIPE)
    rows = []
    for line in out.splitlines():
        line = line.strip()
        if line:
            rows.append([f.strip() for f in line.split(",")])
    return rows


def lookup_procs(pids):
    """Map each pid -> (user, command) via a single ps call (local or remote).

    One ps invocation covers every pid, so a remote host is hit once rather
    than once per process. Pids that have exited are simply absent from the map.
    """
    pids = [str(p).strip() for p in pids if str(p).strip()]
    if not pids:
        return {}
    cmd = ["ps", "-ww", "-o", "pid=,user=,args=", "-p", ",".join(pids)]
    try:
        out = subprocess.check_output(sh(cmd), text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return {}  # ps exits non-zero when none of the pids are alive
    table = {}
    for line in out.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) >= 2:
            table[parts[0]] = (parts[1], parts[2] if len(parts) > 2 else "?")
    return table


def color_util(pct):
    try:
        v = float(pct)
    except (TypeError, ValueError):
        return str(pct)
    if v >= 80:
        return c(f"{v:.0f}%", "31")   # red
    if v >= 25:
        return c(f"{v:.0f}%", "33")   # yellow
    return c(f"{v:.0f}%", "32")       # green


def color_mem(used, total):
    try:
        frac = float(used) / float(total) if float(total) else 0
    except (TypeError, ValueError, ZeroDivisionError):
        frac = 0
    s = f"{float(used):,.0f} / {float(total):,.0f} MiB"
    if frac >= 0.8:
        return c(s, "31")
    if frac >= 0.25:
        return c(s, "33")
    return c(s, "32")


def render():
    """Build the full GPU status report as a string."""
    out = []

    def emit(line=""):
        out.append(line)

    try:
        gpu_rows = run_smi(
            "gpu=index,uuid,name,memory.total,memory.used,"
            "utilization.gpu,temperature.gpu,power.draw"
        )
    except subprocess.CalledProcessError as e:
        detail = (e.stderr or "").strip() or str(e)
        target = f"host {_HOST}" if _HOST else "local GPUs"
        return f"failed to query {target}: {detail}"

    # Map each GPU uuid -> its process list.
    procs_by_uuid = {}
    try:
        for uuid, pid, mem, pname in run_smi(
            "compute-apps=gpu_uuid,pid,used_memory,process_name"
        ):
            procs_by_uuid.setdefault(uuid, []).append((pid, mem, pname))
    except subprocess.CalledProcessError:
        pass

    ptable = lookup_procs(
        pid for plist in procs_by_uuid.values() for (pid, _m, _n) in plist
    )
    term_w = shutil.get_terminal_size((100, 24)).columns

    where = f" on {_HOST}" if _HOST else ""
    emit(bold("GPU status") + dim(f"{where}   ({len(gpu_rows)} device(s))"))
    emit("=" * min(term_w, 100))

    for row in gpu_rows:
        idx, uuid, name, mtot, mused, util, temp, power = (row + [""] * 8)[:8]
        emit(f"{bold('GPU ' + idx):<4}  {name}")
        emit(
            f"        mem {color_mem(mused, mtot)}   "
            f"util {color_util(util)}   "
            f"temp {temp}C   power {power}W"
        )

        procs = procs_by_uuid.get(uuid, [])
        if not procs:
            emit("        " + dim("(idle -- no compute processes)"))
        else:
            emit("        " + dim(f"{'PID':>7}  {'USER':<12} {'MEM':>9}  COMMAND"))
            for pid, mem, pname in procs:
                user, cmd = ptable.get(pid, ("?", pname))
                if cmd == "?":
                    cmd = pname  # fall back to nvidia-smi's process name
                # keep the whole line within the terminal width
                prefix = f"        {pid:>7}  {user:<12} {mem:>6} MiB  "
                avail = max(20, term_w - len(prefix))
                if len(cmd) > avail:
                    cmd = cmd[: avail - 1] + "…"
                emit(prefix + cmd)
        emit("-" * min(term_w, 100))

    return "\n".join(out)


def render_brief():
    """One tab-separated line per process, no colors, for downstream parsing.

    Columns:  gpu  util_pct  mem_used_mib  mem_total_mib  pid  user  proc_mib  command

    A GPU with several processes yields one line per process (gpu/util/mem
    repeated). An idle GPU yields a single line with `-` in the pid, user,
    proc_mib, and command columns. The delimiters tab and newline are stripped
    from the command so every line has exactly 8 tab-separated fields.
    """
    try:
        gpu_rows = run_smi(
            "gpu=index,uuid,memory.total,memory.used,utilization.gpu"
        )
    except subprocess.CalledProcessError as e:
        detail = (e.stderr or "").strip() or str(e)
        target = f"host {_HOST}" if _HOST else "local GPUs"
        return f"failed to query {target}: {detail}"

    procs_by_uuid = {}
    try:
        for uuid, pid, mem, pname in run_smi(
            "compute-apps=gpu_uuid,pid,used_memory,process_name"
        ):
            procs_by_uuid.setdefault(uuid, []).append((pid, mem, pname))
    except subprocess.CalledProcessError:
        pass

    ptable = lookup_procs(
        pid for plist in procs_by_uuid.values() for (pid, _m, _n) in plist
    )

    def clean(s):
        return s.replace("\t", " ").replace("\n", " ")

    lines = []
    for row in gpu_rows:
        idx, uuid, mtot, mused, util = (row + [""] * 5)[:5]
        gpu_cols = [idx, util, mused, mtot]
        procs = procs_by_uuid.get(uuid, [])
        if procs:
            for pid, mem, pname in procs:
                user, cmd = ptable.get(pid, ("?", pname))
                if cmd == "?":
                    cmd = pname
                lines.append("\t".join(gpu_cols + [pid, user, mem, clean(cmd)]))
        else:
            lines.append("\t".join(gpu_cols + ["-", "-", "-", "-"]))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(
        description="Show which processes/users are occupying each GPU."
    )
    ap.add_argument(
        "-w", "--watch", nargs="?", const=2.0, type=float, metavar="SECS",
        help="refresh continuously; optional interval in seconds (default 2)",
    )
    ap.add_argument(
        "-b", "--brief", action="store_true",
        help="one tab-separated line per process (gpu, util, mem_used, "
             "mem_total, pid, user, proc_mib, command) for easy parsing",
    )
    ap.add_argument(
        "-H", "--host", metavar="[USER@]HOST",
        help="query a remote host over SSH instead of the local machine",
    )
    args = ap.parse_args()

    global _HOST
    _HOST = args.host

    if _HOST is None and not shutil.which("nvidia-smi"):
        sys.exit("nvidia-smi not found -- no NVIDIA driver on this machine.")

    frame_fn = render_brief if args.brief else render

    if args.watch is None:
        print(frame_fn())
        return

    interval = max(0.25, args.watch)
    try:
        while True:
            frame = frame_fn()
            # Home cursor + clear-to-end so the screen updates without flicker;
            # hide the cursor while redrawing.
            sys.stdout.write("\033[H\033[J" if _USE_COLOR else "\n")
            stamp = time.strftime("%Y-%m-%d %H:%M:%S")
            sys.stdout.write(
                dim(f"refreshing every {interval:g}s  (Ctrl-C to quit)   {stamp}")
                + "\n"
            )
            sys.stdout.write(frame + "\n")
            sys.stdout.flush()
            time.sleep(interval)
    except KeyboardInterrupt:
        sys.stdout.write("\n")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        try:
            sys.stdout.close()
        except Exception:
            pass
