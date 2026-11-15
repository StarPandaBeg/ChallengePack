# Validation — 2.0.0 TEST BUILD

Target: Buckshot Roulette **2.2.0.6**, Steam Windows, Godot **4.1.1**.

## Automated checks

- Six isolated PowerShell installer scenarios: install/uninstall, idempotence, duplicate entries, other sections/mods, missing executable/script, Unicode/spaced paths.
- Adapter compilation, preserved exports and typed references, against extracted sources and installed Steam PCK.
- Persistent settings, invalid values, independent snapshots, cyclic choices, alternating/random starters, atomic failure on changed adapter anchors.
- Real menu configuration/focus/open/close, multiplayer button block and scene recreation, against extracted scene and installed PCK.
- Gameplay matrix: 36 combinations using real adapted spawning/loading methods with controlled camera/dialogue/AI dependencies. Checks composition, displayed/loading order, exactly one starter, alternation, covers, theft/timeout, gestures, magnifying-glass data and cleanup. Normal/accelerated loading and normal/endless manager states are represented.
- Bundled cover mesh, textures and materials load without editor import.

Headless runs may emit unsupported cursor/mouse and dummy-renderer `mesh_get_surface_count` messages. These are not visual verification. The negative adapter test deliberately logs an anchor mismatch.

## Manual acceptance pending

- Install the packaged archive beside the Steam executable, launch normally, uninstall, check other configuration entries.
- Complete standard and Double or Nothing games, death/defibrillator, menu return and another game. Check dealer-first permissions, cuffs and actual AI/item interactions.
- Visually inspect both covers from gameplay cameras; test theft completion/cancel/timeout and single-frame initial-charge leaks.
- Listen to Quantity/Hidden with normal/accelerated loading; confirm eight gestures/sounds in Hidden and language-specific hints/intro dialogue.
- Test mouse, keyboard, physical controller, device switching, Escape/Back and restored focus.
- Exercise phone, magnifying glass, inverter, beer and other information-changing actions in real play.
- Try real Steam invitations/lobby links and verify no lobby creation/join; confirm an actual Double or Nothing ending does not upload a score.

Until recorded, label releases **TEST BUILD**. The matrix does not mean 36 manually completed games.
