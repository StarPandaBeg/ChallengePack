<br />
<p align="center">
   <a href="https://github.com/StarPandaBeg/ChallengePack">
    <img src=".github/logo.png" alt="Logo" width="128" height="128" />
   </a>

   <h3 align="center">Challenge Pack - Mod for Buckshot Roulette</h3>

   <p align="center">
    Now I keep even more secrets. <b>Shall we play?</b>
   </p>
</p>

---

> **ChallengePack 2.0.0 — TEST BUILD** for **Buckshot Roulette 2.2.0.6 (Steam, Windows)**, Godot **4.1.1**. Single-player only; multiplayer and leaderboard uploads are disabled while installed.

<div align="center">
  <img src=".github/promo.png" alt="Challenge Pack">
</div>
<br/>

<p align="center">
Play a real game with the <b>devil</b>! No mercy, now the game becomes really hard! Test your luck dancing on the edge of life and death!
</p>

## Features

Combine four independent settings for more challenging gameplay in the standard game and Double or Nothing.

#### Shell Visibility:

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Default_ - Shells are shown as in the original game.

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Quantity_ - Only the total number of shells is visible. All displayed shells look blank, and composition and sequence sounds are suppressed. Guess which shells are live!

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Hidden_ - No initial information about the number or types of shells. The compartment stays closed and the dealer always performs eight loading gestures. Test your luck!

#### Items Visibility:

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Default_ - Items are visible as in the original game.

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Hidden_ - The dealer can keep secrets: two covers hide his items. Covers temporarily disappear when choosing an item to steal with adrenaline, then return after selection or timeout.

#### Shuffle Bullets:

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Yes_ - Shells are shuffled using the original game's rules.

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _No_ - A random arrangement is generated once, then shells are loaded in the same order as they lie on the table.

#### First turn:

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Always First_ - The player always starts after loading, as in the original game.

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Round Robin_ - The player starts the first load, then the player and dealer alternate starting after each reload.

<img src=".github/icon_1.png" alt="*" width="16" height="16" /> _Random_ - The starting player is chosen independently after each reload.

Settings are saved between launches and applied when starting a game. Mouse, keyboard and controller UI navigation are supported; Escape/Back returns to the main menu. Magnifying glasses and burner phones still reveal information according to the game's rules.

## Installation

1. Download the **2.0.0 test build** archive from [releases](https://github.com/StarPandaBeg/ChallengePack/releases), or build it from source using the instructions below.
2. Open the folder containing `Buckshot Roulette.exe` through Steam: **Manage → Browse local files**, then open `Buckshot Roulette_windows`.
3. Extract the entire `ChallengePack` folder next to the executable:

   ```text
   Buckshot Roulette_windows/
     Buckshot Roulette.exe
     ChallengePack/
       challengepack.gd
       install.bat
       uninstall.bat
       modcfg.ps1
       ...other scripts and assets...
   ```

4. Run `ChallengePack\install.bat`.
5. Launch the game through Steam, select the single-player Start button, configure your challenge, and enjoy!

No separate mod loader is required. The installer adds only the `ChallengePack` autoload entry to `override.cfg`; repeating installation updates that entry without duplicates. Keep all mod files together and rerun the installer after moving the game folder. Other configuration entries are preserved, but compatibility with other mods is not established.

This build supports only **2.2.0.6**. If the installed scripts do not match, challenge Start is disabled with an explanation. Do not edit `compatibility.json` merely to bypass that check.

### Uninstallation

Run `ChallengePack\uninstall.bat`, then delete the mod folder. Other mods and configuration entries remain installed. Uninstall ChallengePack to play online again.

Preferences remain in `%APPDATA%\Godot\app_userdata\Buckshot Roulette\challengepack.cfg`; delete that file to reset them. Multiplayer entry and leaderboard uploads are blocked while the mod is installed; Steam achievements are not intentionally disabled.

### Troubleshooting

Look for `[ChallengePack]` in `%APPDATA%\Godot\app_userdata\Buckshot Roulette\logs\godot.log`. The log reports the mod version, compatibility result and attached managers. Include the game version, selected settings and relevant errors in bug reports.

## Building from source

Use Python 3, Windows PowerShell and Godot **4.1.1**. The development tools expect this workspace layout:

```text
workspace/
  ChallengePack/                  # this repository
  game/                          # extracted game project, with project.godot
  godot/
    Godot_v4.1.1-stable_win64.exe
```

Run from the repository root:

```powershell
python tools/run_godot.py --path tools --script res://build_assets.gd
python tools/package.py
```

The first command builds `ChallengePack/assets/protectors.res` from the mesh and textures in `assets/protectors/`. The second creates `dist/ChallengePack-2.0.0-test-win64.zip` and its SHA-256 checksum. The archive contains the installable mod and documentation; Python and the Godot editor are not required to play.

### Validation

Run the installer and engine checks from the repository root:

```powershell
python -m unittest discover -s tests -p test_installer.py -v
$repoPath = (Get-Location).Path
foreach ($scenario in @('probe', 'settings_rules', 'smoke', 'gameplay')) {
    python tools/run_godot.py --path ../game --script "$repoPath/tests/$scenario.gd"
    if ($LASTEXITCODE -ne 0) { throw "Check failed: $scenario" }
}
```

For checks against the installed game's embedded resources, pass `--game-exe "D:/.../Buckshot Roulette.exe"` to the runner and omit `--path ../game`. Checks do not install the mod. Logs are written under `tests/.scratch/`, and runs time out automatically.

Compatibility hashes pin the supported game scripts. Update them with `python tools/update_compatibility.py` only after reviewing changes and adapting the mod. See [VALIDATION.md](VALIDATION.md) for automated coverage and manual acceptance checks.

## Screenshots

<div align="center">
  <img src=".github/1.png" alt="Challenge configuration">
  <img src=".github/2.png" alt="Shell visibility challenge">
  <img src=".github/3.png" alt="Hidden items challenge">
</div>

Menu layout may differ in the test build.

<br/>

# License

Distributed under the MIT License.

See [LICENSE](LICENSE) for more information.

# Disclaimer

This is an unofficial fan modification, not affiliated with the game developer, and requires a legitimate copy of Buckshot Roulette. No game code or game assets are distributed.

This is a **test build**: complete games, visual/audio behavior, physical controller input and real Steam invitations still require manual acceptance. It may contain errors or inaccuracies. Feedback and bug reports are welcome! 💗
