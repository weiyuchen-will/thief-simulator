#!/usr/bin/env python3
"""Run engine-level acceptance checks; no third-party Python dependencies."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CANDIDATES = [
    shutil.which("godot"),
    Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot",
    Path("/Applications/Godot.app/Contents/MacOS/Godot"),
]
ENGINE = next((str(p) for p in CANDIDATES if p and Path(p).is_file()), None)
if ENGINE is None:
    sys.exit("Godot 4 is required. Add godot to PATH.")

CHECKS = [
    ("flow", ["--", "--qa=flow"], "QA_FLOW_PASS"),
    ("weapons", ["--script", "res://tests/weapons_smoke.gd"], "ARSENAL_SMOKE_OK"),
    ("hud", ["--script", "res://tests/hud_smoke.gd"], "AGENT SIMULATOR HUD CHECKS PASSED"),
    ("gestures", ["--script", "res://tests/gesture_smoke.gd"], "GESTURE_SMOKE_OK"),
    ("missions", ["--script", "res://tests/missions_smoke.gd"], "MISSIONS_SMOKE_OK"),
    ("progress", ["--script", "res://tests/progress_smoke.gd"], "PROGRESS_SMOKE_OK"),
    ("world", ["--fixed-fps", "60", "--script", "res://tests/world_smoke.gd"], "WORLD_SMOKE_OK"),
    ("skins", ["--script", "res://tests/skins_smoke.gd"], "SKINS_SMOKE_OK"),
    ("soundtrack", ["--script", "res://tests/soundtrack_smoke.gd"], "SOUNDTRACK_SMOKE_OK"),
]


def run(check):
    name, args, marker = check
    command = [ENGINE, "--headless", "--path", str(ROOT), "--max-fps", "120", *args]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=35)
    except subprocess.TimeoutExpired:
        return name, False, "Timed out after 35 seconds"
    log = result.stdout + result.stderr
    passed = result.returncode == 0 and marker in log and "SCRIPT ERROR" not in log and "\nERROR:" not in log
    return name, passed, log


if __name__ == "__main__":
    failed = False
    with ThreadPoolExecutor(max_workers=4) as executor:
        for name, passed, log in executor.map(run, CHECKS):
            print(f"{'PASS' if passed else 'FAIL'} {name}")
            if not passed:
                print(log)
                failed = True
    sys.exit(1 if failed else 0)
