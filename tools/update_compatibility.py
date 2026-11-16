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
