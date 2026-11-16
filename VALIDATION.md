# Validation — 2.2.0

Target: Buckshot Roulette **2.2.0.6**, Steam Windows, Godot **4.1.1**.

## Automated checks

- Seven isolated installer scenarios: install/uninstall, idempotence, duplicate entries, other sections/mods, missing executable/script, Unicode/spaced paths and batch entrypoints calling the helper in `src/`.
- Adapter compilation, preserved exports and typed references, against extracted sources and installed Steam PCK.
- Persistent settings, invalid values, independent snapshots, cyclic choices, alternating/random starters, atomic failure on changed adapter anchors.
- Real menu configuration/focus/open/close, fail-closed multiplayer compatibility and scene recreation, against extracted scene and installed PCK.
- Russian, English and Polish catalogs, regional locale matching, placeholders, English fallback and live menu updates when switching game language; vanilla action translations are reused.
- Gameplay matrix: 36 combinations using real adapted spawning/loading methods with controlled camera/dialogue/AI dependencies. Checks composition, displayed/loading order, exactly one starter, alternation, covers, theft/timeout, gestures, magnifying-glass data and cleanup. Normal/accelerated loading and normal/endless manager states are represented.
- Extended challenges: 168 combinations of health visibility, mirrored items, pocket limits and contracts. Real dealer distribution is checked with leftovers, duplicates, exact amount counters, full tables and consecutive copies. Health values remain unchanged; adrenaline shares its pocket slot; real round/player-turn methods reset limits; forbidden shooting opens a failure screen before damage and returns to the menu after confirmation. Tests isolate their fixtures from a mod already installed in the game directory.
- Contract HUD: English/Russian compact bounds and input passthrough, pocket exhaustion and scene cleanup. No-item rounds filter random contracts and suspend fixed item restrictions without announcing them; item rounds restore the selected rule.
- Heal bullets: six visibility/shuffle combinations, preserved live count/charge size/displayed order, normal/hidden loading, real player/dealer shot methods with controlled presentation/finalization, one-shell ejection, self-shot extra turns, HP cap/no revival/cut wires, doubled handsaw healing, informed dealer choice, shell-type deduction, phone/magnifier, both inverter pairs and beer.
- Failure screen: all three contract violations in English/Russian, game pause, unchanged HP/shells, blocked repeat actions, dismissal input guard, mouse/accept/back through the viewport, menu transition and pause cleanup. Compact HUD bounds are checked at an 8-pixel top-left inset.
- Contract frequency: 112,000 deterministic rolls cover the 30% activation rate, equal weighting of twelve contracts (three available without items), fixed modes, filtering without items, expiration and silent rounds. The probability fixture explicitly uses the saved 30% default; subset and 0%/100% behavior are checked separately.
- Two-column menu: all setting values fit in English/Russian/Polish; horizontal/vertical focus neighbors and the path to Start are checked. Localized hover tooltips cover every setting and both action buttons, including live language changes. Healing sound playback is checked only when HP increases (not at full health, zero HP or with cut wires).
- Retractable covers: initially hidden below the table; the real adapted room-entry method starts one rise and calls the original game method. Check intermediate/final positions, installed mechanical sound playback/stop, repeated-entry idempotence, theft during/after motion, direct-at-table startup, scene recreation and interruption cleanup. Geometry resources remain unchanged.
- Hidden dealer inventory: all nine actual item models and their child meshes are concealed on spawn and for existing leftovers. Player intake stays visible before placement. Actual dealer pickup reveals only its selected item; actual player theft keeps the chosen item visible after the covers return. Theft timeout, mirrored distribution, default mode and scene cleanup are covered.
- Black shells: green ↔ black inverter pair, 24 actual adapted player/dealer shot cases at different HP/saw states, zero HP before the death handler, one ejection, live-shot effects and unchanged future damage. Dealer recognizes and creates black shells with an inverter; phone/magnifier/ejection use the black type/material. Beer safely ejects them, and fresh charges never contain them. Death presentation dependencies are controlled in fixtures; actual death/revival camera sequences still require manual play.
- Bundled cover mesh, textures and materials load without editor import.
- What's new: first-entry timing after the intro, version-specific persistence in an isolated config, forced launch previews, scene recreation, modal input and restored menu focus. All nine cards fit horizontally in English/Russian/Polish; scrolling follows card focus and the close button stays visible. Optional PNG screenshots load without editor import.
- Contract rules: 216 item/theft cases cover all twelve contracts. No Safety Net checks both orders, repeated use of one type, stolen items, persistent history across turns/self-shots, pocket rejection, shared adrenaline accounting, next-charge reset and scene cleanup. All fourteen legacy choices migrate to On/Off plus the corresponding checkbox pool; contract IDs remain stable. English/Russian checkbox tooltips explain every contract, and the compact insurance HUD changes to the remaining prohibition.
- Contract presentation: arming beep only for an active contract; bomb at the HUD's bottom right, hidden for suspended contracts and pocket-only rules. Ten actual room-scene violations play the real grab/self-shot animations, breach warning, installed live gunshot, flash and fade before the result, with normal/endless manager states represented. Repeat actions cannot restart the sequence; HP, shells and statistics remain unchanged, with no revival or next turn. Scene interruption/mod removal cancels the sequence and restores pause/process modes. Bundled PNG/PCM sounds load without editor import.

- Shot contracts: 96 actual adapted player/dealer shots cover live, blank, green and black shells, both selected targets, normal/sawed barrels, double damage/healing without stacking, player-only target reversal, matching animation and extra-turn decisions, exactly one ejection/death handler and expiry on the next charge. Healing caps, cut wires and no revival remain covered. Localized contract probability is injected from code; menu and tooltip are checked at 0%, 30% and 100% in both languages.

- Contract editor: compact English/Russian/Polish menu and modal bounds, On/Off edit-button visibility, twelve checkbox explanations, mouse and accept/back input, keyboard slider changes, select/deselect all, empty-selection explanation, immediate persistence and restored parent focus. Config migration covers all old modes; pool/chance validation, duplicate normalization, immutable party snapshots, uniform selected-subset rolls and no-item filtering are checked against extracted and installed game resources.

Headless runs may emit unsupported cursor/mouse and dummy-renderer `mesh_get_surface_count` messages. These are not visual verification. The negative adapter test deliberately logs an anchor mismatch.

## Manual acceptance pending

- Install the packaged archive beside the Steam executable, launch normally, uninstall, check other configuration entries.
- Complete standard and Double or Nothing games, death/defibrillator, menu return and another game. Check dealer-first permissions, cuffs and actual AI/item interactions.
- Visually inspect both covers rising during the room-entry camera animation and listen for the mechanism; test theft completion/cancel/timeout and single-frame initial-charge leaks.
- Listen to Quantity/Hidden with normal/accelerated loading; confirm eight gestures/sounds in Hidden and language-specific hints/intro dialogue.
- Test mouse, keyboard, physical controller, device switching, Escape/Back and restored focus. Inspect the compact Russian menu and contract editor at normal display scaling; change checkboxes and probability, select/deselect all, restart and verify persistence.
- Inspect the What's New screen at first entry in both languages, scroll with mouse/keyboard/controller, close it and restart to confirm it stays dismissed. Add real screenshots to the reserved rectangles and inspect their aspect ratio. Set `FORCE_SHOW = 1` in `src/whats_new.gd` to repeat the first-entry preview on each launch; restore `0` before release.
- Listen to contract activation/breach sounds and visually inspect the bottom-right bomb, aiming, self-shot, flash and fade before the result. Test violations from the table, while holding the shotgun, while stealing and with cuffs in both game modes. Check game volume/mute, normal speed, return to menu and restarting a run; headless animation checks do not establish visual/audio quality.
- Exercise phone, magnifying glass, inverter, beer and other information-changing actions in real play.
- Check hidden health through bootup, healing, flickering digits, defibrillation and final-showdown wire cuts. Play contracts and pocket limits through actual item animations, theft timeouts, blank self-shots and cuffs; inspect the failure screen (including physical controller input), nine-option menu and compact top-left HUD at 960×540 with both languages and controller input.
- Visually inspect green shells and their higher-pitched blank indicator in Default, then initial concealment in Quantity/Hidden. Play healing/black shots with cuffs, sawed-off barrels and last-shell reloads in both game modes; verify turn continuation and health updates during real animations.
- Try real Steam invitations/lobby links and verify that only compatible modded lobbies can be joined; confirm an actual Double or Nothing ending does not upload a score.

- Manually check both shotgun contracts at normal speed with and without items, on the last shell, with cuffs and during normal/Double or Nothing games. Confirm the selected target reverses only for the player, saw boosts never stack, green shells heal up to the round maximum, and the next charge restores ordinary behavior.

The matrix does not mean 36 manually completed games.

## Multiplayer acceptance

**Implemented for 2–4 players; real multi-account Steam matches are not yet verified.** Local transport fixtures and four instantiated players do not establish network playability. Keep multiplayer marked experimental until the checks below pass.

Automated coverage added:

- Healing-shell probability: 0/30/100% per load in solo and multiplayer, preference persistence and migration, localized modal bounds, slider keyboard input, and lobby host-only editing. Chance is authoritative on the host and included in synchronized settings; existing healing and inversion rules remain unchanged.

- Independent multiplayer preferences, strict settings validation, all 2,304 public setting combinations for each of 2/3/4 players, itemless eligibility, twelve contracts, allowed/forbidden owned and stolen items, both jammer/glass orders, random target reversal and table-wide mirror limits.
- In-memory handshake and rule synchronization, readiness invalidation, guest preference isolation, session/revision checks, sender-to-seat binding, replay rejection, invalid/dead targets and forged inventory slots. This transport sends no Steam packets.
- Startup regression from the first two-client Steam log: verified `member joined list` packets reach the native waiting-player counter, duplicates and forged/stale arrivals are rejected, and the stock `packat alias` typo is normalized. Startup now has a 30-second timeout and stage diagnostics. Retest a real two-client match with the rebuilt archive; these local checks do not establish successful Steam gameplay.
- Actual lobby and game scenes: English/Russian/Polish bounds for nine settings and twelve contract checkboxes, four player instances, typed manager links, mirrored inventories, hidden rival items without covers, import-free resources, redacted hidden charge and snapshot round trip.
- Multiplayer presentation regressions: only the local contract has a solo-style corner card with a 14×14 icon and a brief localized reminder; rival contracts appear above their native nicknames as a small bomb and title in the nickname font; multiplayer uses no physical covers, while rival inventory meshes remain hidden for each local seat. Repeat with separate Steam clients. The local card fits in English/Russian/Polish; rival labels follow the nickname transform and visibility, disappear on death/expiration, and return for living players with a contract. Insurance reminders update after item use. The gameplay title is hidden (F8 still opens rules), special shell hulls discard the incompatible red albedo texture, and hidden loading skips the showcase camera/pause. The scene fixture exercises hidden loading against a 20-second stock display duration and requires completion within four seconds.
- Hidden HP keeps the round indicator and hides all HP groups even when the jammer flashes the screen. Jammer regressions cover invalid confirmation, stale targets, timeout cleanup, and release of the host action lock. Phase waits drain queued acknowledgments before checking deadlines; all mod synchronization deadlines use 30 seconds. Repeat short minimize/restore on host and guest, jammer success/cancellation/timeout, and controller input on separate Steam clients.
- Actual first/third-person animation tracks: doubled green healing, preserved self-shot turn and pocket count, exactly one shell consumed, black-shell death, contract execution and unchanged charge during punishment.
- All multiplayer adapters compile against extracted sources and the installed Steam game resources. The extracted release archive also passes `release_probe.gd` through the Steam executable without editor import. Runtime compilation and anchor checks are atomic; score upload remains blocked independently.

Required real-network checks:

1. Install the archive on 2, 3 and 4 separate Steam clients with the supported game version. Check create/search/join, ID paste, invitations and lobby links. Reject missing mods and mismatched fingerprints; check the 30-second handshake timeout.
2. Have every player press Ready directly in the lobby beside ChallengePack, then change either ChallengePack or vanilla match settings. Readiness must reset. Verification/readiness labels appear to the right of the native player rows, outside the settings modal. ChallengePack and Ready are hidden without lobby membership; leaving closes open settings. Buttons use a filled focus highlight without a border. The readiness action is absent from the settings submenu and during a match. Verify guest controls stay read-only and guests keep their own saved preferences.
3. Finish representative matches with every mode, all twelve contracts, every shell type and all multiplayer items. Check last shells, timeouts, stealing, direction reversal, skipped turns, simultaneous deaths and round wins.
4. Inspect hidden shells/items/health during intro, loading, free look, controller selection, theft cancellation/timeout, item use and spectating. Verify rival items stay invisible without covers and owned/held items remain visible from every seat.
5. Introduce latency/disconnection. Verify phase acknowledgments, no duplicate effects, resynchronization and timeout exit. A guest leaving must not reset the surviving match's session. Host departure ends the match; host change in a lobby requires renewed confirmation.
6. Confirm the local corner contract, rival overhead bomb/title labels, beep/bomb, fatal penalty and spectating until the next round. Green healing and target reversal must follow the actual target on every screen.
7. Repeat menu return/start, install/uninstall and ordinary solo/Double or Nothing runs. Removing the mod restores access to vanilla lobbies.

Run the multiplayer checks with the same runner as the single-player fixtures:

```powershell
foreach ($scenario in @('multiplayer', 'multiplayer_protocol', 'multiplayer_scene')) {
    python tools/run_godot.py --path ../game --script "$((Get-Location).Path)/tests/$scenario.gd"
    if ($LASTEXITCODE -ne 0) { throw "Check failed: $scenario" }
}
```

Pass `--game-exe "D:/.../Buckshot Roulette.exe"` instead of `--path ../game` to use installed Steam resources. These checks do not create or join Steam lobbies. Repeated real-room cinematic fixtures may need `--timeout 240`; the runner defaults to 90 seconds.

## Developer reference

### Logs and saved settings

Look for `[ChallengePack]` in `%APPDATA%\Godot\app_userdata\Buckshot Roulette\logs\godot.log`. The log reports the mod version, compatibility result and attached managers. Include the game version, selected settings and relevant errors in bug reports.

Solo preferences remain in `%APPDATA%\Godot\app_userdata\Buckshot Roulette\challengepack.cfg`; multiplayer preferences use `challengepack_multiplayer.cfg` beside it. Delete the relevant file to reset that mode’s preferences.

### Building from source

Use Python 3, Windows PowerShell and Godot **4.1.1**. The development tools expect this workspace layout:

```text
workspace/
  ChallengePack/                  # this repository
  game/                          # extracted game project, with project.godot
  godot/
    Godot_v4.1.1-stable_win64.exe
```

Run `build.bat` from the repository root, or double-click it in Explorer. To skip the final pause:

```powershell
.\build.bat /q
```

The script rebuilds `ChallengePack/src/assets/protectors.res` from the mesh and textures in `assets/protectors/`, then creates `dist/ChallengePack-2.2.0-win64.zip` and its SHA-256 checksum. It stops if either step fails. Only `install.bat` and `uninstall.bat` sit at the top of the installable mod folder; its scripts and resources are kept in `src/`. The archive contains the installable mod and documentation; Python and the Godot editor are not required to play.

### Translation catalogs

Mod-specific text follows the language selected in the game. Russian and Polish are included; other languages fall back to English. Start, Return, Yes and No reuse the game's translations.

Translation catalogs are UTF-8 JSON files in `ChallengePack/src/locales/`: `en.json` contains the base messages; `ru.json` and `pl.json` contain Russian and Polish translations. To add a language, copy the keys into `<language>.json` using its lowercase language code (for example, `de.json`). Keep `%s` placeholders in the same order. Missing or empty entries fall back to English. Regional locales such as `ru_RU` use their language catalog. Restart the game after editing a catalog; switching the game's language updates the menu automatically.

### What's new screen

The first visit to the main menu shows a scrollable introduction to the challenges, once per mod version. Close it with the button or Escape/Back. Mouse wheel, Tab and controller/arrow navigation can browse the cards. Its read state is saved separately in `user://challengepack_news.cfg`.

For testing, set `const FORCE_SHOW = 1` at the top of `ChallengePack/src/whats_new.gd`. The screen will appear on every game launch, even if already read; returning to the menu during the same launch does not reopen it. Set it back to `0` before packaging a release.

To replace the screenshot placeholders, put PNG files in `ChallengePack/src/assets/news/`: `shells.png`, `items.png`, `shuffle.png`, `turn.png`, `health.png`, `mirror.png`, `pocket.png`, `contract.png`, `heal.png`. Images keep their aspect ratio inside the rectangles (180 × 106); editor import is unnecessary. Missing images keep the placeholder. News text uses the `CP_NEWS_*` localization keys.

### Running checks

Run the installer and engine checks from the repository root:

```powershell
python -m unittest discover -s tests -p test_installer.py -v
$repoPath = (Get-Location).Path
foreach ($scenario in @('probe', 'settings_rules', 'localization', 'smoke', 'gameplay', 'challenges', 'contract_hud', 'heal_bullets', 'failure_screen', 'contract_chance', 'protectors', 'hidden_items', 'lethal_bullets', 'whats_new', 'contract_effects', 'contract_rules', 'shot_contracts', 'contract_editor')) {
    python tools/run_godot.py --path ../game --script "$repoPath/tests/$scenario.gd"
    if ($LASTEXITCODE -ne 0) { throw "Check failed: $scenario" }
}
```

For checks against the installed game's embedded resources, pass `--game-exe "D:/.../Buckshot Roulette.exe"` to the runner and omit `--path ../game`. Checks do not install the mod. Logs are written under `tests/.scratch/`, and runs time out automatically.

Compatibility hashes pin the supported game scripts. Update them with `python tools/update_compatibility.py` only after reviewing changes and adapting the mod. See the coverage and manual acceptance checks above.
