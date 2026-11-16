"""Explicitly re-pin supported game scripts; review changes before running."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parent / "game"
TARGETS = ("ShellSpawner", "ShellLoader", "ItemManager", "MenuManager", "LeaderboardManager",
           "HealthCounter", "RoundManager", "ItemInteraction", "ShotgunShooting",
           "DealerIntelligence", "ShellEjectManager", "ShellExamine", "BurnerPhone", "HandManager")
manifest = {
    name: hashlib.sha256((GAME / "scripts" / f"{name}.gd").read_text(encoding="utf-8").encode()).hexdigest()
    for name in TARGETS
}
(ROOT / "ChallengePack" / "src" / "compatibility.json").write_text(
    json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
)

# Keep the multiplayer manifest separate: a rejected network adapter must not
# prevent the independent single-player compatibility check.
import re
mp_factory = (ROOT / "ChallengePack/src/multiplayer/factory.gd").read_text(encoding="utf-8")
mp_paths = dict(re.findall(r'"(\w+)": "res://([^"\n]+)"', mp_factory))
mp_manifest = {
    name: hashlib.sha256((GAME / path).read_text(encoding="utf-8").encode()).hexdigest()
    for name, path in mp_paths.items()
}
(ROOT / "ChallengePack/src/multiplayer/compatibility.json").write_text(
    json.dumps(mp_manifest, indent=2) + "\n", encoding="utf-8"
)
