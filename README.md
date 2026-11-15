# ChallengePack 2.0.0 — TEST BUILD

Standalone single-player challenges for **Buckshot Roulette 2.2.0.6 (Steam, Windows), Godot 4.1.1**. No AGO061/BRMLNeo loader or replacement executable required.

**Test build:** full games, visual/audio behavior and a physical controller still need manual acceptance. See [VALIDATION.md](VALIDATION.md). Other game versions and mods are not supported without testing.

## Rules

Single-player Start opens **game configuration**. Combine four settings:

| Setting | Choices |
| --- | --- |
| Shell visibility | **DEFAULT:** vanilla. **QUANTITY:** count visible, shells look blank, composition and sequence sounds suppressed. **HIDDEN:** closed compartment, no count/composition hints, compartment sounds suppressed, always eight loading gestures. |
| Items visibility | **DEFAULT:** vanilla. **HIDDEN:** two covers hide dealer items; disappear during adrenaline theft selection, return on completion/timeout. |
| Shuffle bullets | **YES:** vanilla. **NO:** random display order is generated once and loaded in that order, fixing the old live-then-blank sequence. |
| First turn | **ALWAYS FIRST:** player. **ROUND ROBIN:** player first, then alternating starters after each load. **RANDOM:** independently choose after each load. |

Real shells, damage, AI and information items retain game rules. Magnifying glasses and burner phones can reveal information during play. Preferences persist in `user://challengepack.cfg`, normally `%APPDATA%\Godot\app_userdata\Buckshot Roulette\challengepack.cfg`; rules are frozen on Start. Defaults are vanilla rules. Mouse, keyboard and controller UI actions are supported; Escape/Back returns to the menu.

## Installation

1. Use a clean **2.2.0.6** installation. Remove old loaders using their own instructions first; this installer does not remove them automatically.
2. Extract the archive so `ChallengePack/` sits next to `Buckshot Roulette.exe`.
3. Run `ChallengePack\install.bat`, then launch through Steam.

Keep all scripts, adapters and `assets/protectors.res` together. Only the `ChallengePack` autoload entry in `override.cfg` is added. Reinstalling updates its absolute path without duplicates; rerun after moving the folder. Other entries survive, but mod interoperability is not guaranteed.

Unknown game scripts disable challenge Start with an error. Do not edit `compatibility.json` just to bypass the check. Readable script resources are required and were verified in the supplied Steam build.

## Online, removal and logs

Multiplayer from the menu, Steam invitations, lobby links and command-line lobby entry is blocked while installed. Both leaderboard upload methods are blocked. Achievements are not intentionally disabled. The guard is independently implemented against game managers; no OneShotMod code is redistributed.

Run `ChallengePack\uninstall.bat`, then delete the folder to play online again. Only this mod's entry is removed; other mods remain. Preferences remain in user data; delete `challengepack.cfg` to reset them.

Find `[ChallengePack]` entries in `%APPDATA%\Godot\app_userdata\Buckshot Roulette\logs\godot.log`. Startup reports version, compatibility and attached managers. Include version, rules and errors in bug reports.

## Development

`ChallengePack/` is the distribution. `mods-unpacked/` retains historical 1.4.2 code and source artwork, excluded from archives. `tools/` contains builders; `tests/` contains checks.

From the parent workspace containing `game/`, `godot/` and this repo:

```powershell
python -m unittest discover -s ChallengePack/tests -p test_installer.py -v
python ChallengePack/tools/run_godot.py --path game --script C:/absolute/path/ChallengePack/tests/probe.gd
python ChallengePack/tools/run_godot.py --path game --script C:/absolute/path/ChallengePack/tests/settings_rules.gd
python ChallengePack/tools/run_godot.py --path game --script C:/absolute/path/ChallengePack/tests/smoke.gd
python ChallengePack/tools/run_godot.py --path game --script C:/absolute/path/ChallengePack/tests/gameplay.gd
python ChallengePack/tools/run_godot.py --path ChallengePack/tools --script res://build_assets.gd
python ChallengePack/tools/package.py
```

For installed-PCK tests, pass `--game-exe "D:/.../Buckshot Roulette.exe"` and omit `--path game`. This does not install the mod. Logs are captured in `tests/.scratch/`; runs time out automatically.

Compatibility hashes pin normalized source. Run `tools/update_compatibility.py` only after reviewing/adapting to changes. Runtime subclasses preserve scene exports before `_ready()` and derive changed method bodies from installed resources, without distributing game source.

## License

MIT; see [LICENSE](LICENSE). Unofficial fan mod, not affiliated with the developer. Requires a legitimate game copy. No game code or game assets are distributed.
