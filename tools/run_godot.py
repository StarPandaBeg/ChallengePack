"""Run the Windows GUI-subsystem Godot binary synchronously with captured logs."""
import subprocess
import sys
import os
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
repo = Path(__file__).resolve().parents[1]
exe = repo.parent / "godot" / "Godot_v4.1.1-stable_win64.exe"
if "--game-exe" in sys.argv:
    index = sys.argv.index("--game-exe")
    exe = Path(sys.argv[index + 1])
    del sys.argv[index:index + 2]
log = repo / "tests" / ".scratch" / ("godot-%s.log" % os.getpid())
log.parent.mkdir(exist_ok=True)
with log.open("wb") as stream:
    process = subprocess.Popen([str(exe), "--headless", *sys.argv[1:]],
                               stdout=stream, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        code = 1
        print("Godot timed out", file=sys.stderr)
output = log.read_text(encoding="utf-8", errors="replace")
print(output, end="")
sys.exit(code or (1 if "SCRIPT ERROR:" in output else 0))
