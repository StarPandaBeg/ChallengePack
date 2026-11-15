"""Run the Windows GUI-subsystem Godot binary synchronously with captured logs."""
import subprocess
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
repo = Path(__file__).resolve().parents[1]
exe = repo.parent / "godot" / "Godot_v4.1.1-stable_win64.exe"
try:
    result = subprocess.run([str(exe), "--headless", *sys.argv[1:]],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=90)
    output = result.stdout.decode("utf-8", errors="replace")
    print(output, end="")
    sys.exit(result.returncode or (1 if "SCRIPT ERROR:" in output else 0))
except subprocess.TimeoutExpired as exc:
    print((exc.stdout or b"").decode("utf-8", errors="replace"))
    print("Godot timed out", file=sys.stderr)
    sys.exit(1)
