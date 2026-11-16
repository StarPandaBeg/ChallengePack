"""Run the regression suite with isolated logs and a machine-readable summary."""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = (
    "settings_rules", "localization", "probe", "gameplay", "contract_rules", "contract_chance",
    "contract_editor", "challenges", "shot_contracts", "heal_bullets",
    "lethal_bullets", "hidden_items", "protectors", "failure_screen",
    "contract_hud", "contract_effects", "whats_new", "smoke",
    "multiplayer", "multiplayer_protocol", "multiplayer_scene", "behavior_trace", "architecture",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scenarios", nargs="*", choices=SCENARIOS)
    parser.add_argument("--game-exe")
    parser.add_argument("--skip-installer", action="store_true")
    args = parser.parse_args()
    logs = ROOT / "tests/.scratch/check"
    logs.mkdir(parents=True, exist_ok=True)
    results = []
    commands = []
    for name in args.scenarios or SCENARIOS:
        command = [sys.executable, str(ROOT / "tools/run_godot.py"), "--timeout", "240"]
        command += (["--game-exe", args.game_exe] if args.game_exe
                    else ["--path", str(ROOT.parent / "game")])
        command += ["--script", str(ROOT / f"tests/{name}.gd")]
        commands.append((name, command))
    if not args.skip_installer:
        commands.append(("installer", [sys.executable, "-m", "unittest", "discover",
                                      "-s", "tests", "-p", "test_installer.py"]))
    for name, command in commands:
        start = time.monotonic()
        with (logs / f"{name}.log").open("wb") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        results.append(dict(name=name, passed=result.returncode == 0,
                            seconds=round(time.monotonic() - start, 3)))
        print(f"{'PASS' if result.returncode == 0 else 'FAIL'} {name}", flush=True)
    (logs / "summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    return int(any(not row["passed"] for row in results))


if __name__ == "__main__":
    raise SystemExit(main())
