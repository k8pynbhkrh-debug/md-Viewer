#!/usr/bin/env python3
"""Capture the md Viewer (Mac Catalyst debug build) window by CGWindow id.
Usage: wincap.py <pid> <out.png>"""
import sys, subprocess, Quartz

pid = int(sys.argv[1])
out = sys.argv[2]
wins = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements, Quartz.kCGNullWindowID)
cand = []
for w in wins:
    if w.get("kCGWindowOwnerPID") == pid and w.get("kCGWindowLayer", 0) == 0:
        b = w["kCGWindowBounds"]
        cand.append((b["Width"] * b["Height"], int(w["kCGWindowNumber"]), b))
if not cand:
    print("no window for pid", pid); sys.exit(1)
cand.sort(reverse=True)
_, wid, b = cand[0]
print(f"window {wid} {int(b['Width'])}x{int(b['Height'])} @ {int(b['X'])},{int(b['Y'])}")
subprocess.run(["screencapture", "-x", "-o", "-l", str(wid), out], check=True)
