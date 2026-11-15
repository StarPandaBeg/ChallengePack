# Validation — 2.1.0

Target: Buckshot Roulette **2.2.0.6**, Steam Windows, Godot **4.1.1**.

## Automated checks

- Seven isolated installer scenarios: install/uninstall, idempotence, duplicate entries, other sections/mods, missing executable/script, Unicode/spaced paths and batch entrypoints calling the helper in `src/`.
- Adapter compilation, preserved exports and typed references, against extracted sources and installed Steam PCK.
- Persistent settings, invalid values, independent snapshots, cyclic choices, alternating/random starters, atomic failure on changed adapter anchors.
- Real menu configuration/focus/open/close, multiplayer button block and scene recreation, against extracted scene and installed PCK.
- Russian and English catalogs, regional locale matching, placeholders, English fallback and live menu updates when switching game language; vanilla action translations are reused.
- Gameplay matrix: 36 combinations using real adapted spawning/loading methods with controlled camera/dialogue/AI dependencies. Checks composition, displayed/loading order, exactly one starter, alternation, covers, theft/timeout, gestures, magnifying-glass data and cleanup. Normal/accelerated loading and normal/endless manager states are represented.
- Extended challenges: 60 combinations of health visibility, mirrored items, pocket limits and contracts. Real dealer distribution is checked with leftovers, duplicates, exact amount counters, full tables and consecutive copies. Health values remain unchanged; adrenaline shares its pocket slot; real round/player-turn methods reset limits; forbidden shooting opens a failure screen before damage and returns to the menu after confirmation. Tests isolate their fixtures from a mod already installed in the game directory.
- Contract HUD: English/Russian compact bounds and input passthrough, pocket exhaustion and scene cleanup. No-item rounds filter random contracts and suspend fixed item restrictions without announcing them; item rounds restore the selected rule.
- Heal bullets: six visibility/shuffle combinations, preserved live count/charge size/displayed order, normal/hidden loading, real player/dealer shot methods with controlled presentation/finalization, one-shell ejection, self-shot extra turns, HP cap/no revival/cut wires, handsaw independence, informed dealer choice, three-type deduction, phone/magnifier, inverter and beer.
- Failure screen: all three contract violations in English/Russian, game pause, unchanged HP/shells, blocked repeat actions, dismissal input guard, mouse/accept/back through the viewport, menu transition and pause cleanup. Compact HUD bounds are checked at an 8-pixel top-left inset.
- Contract frequency: 40,000 deterministic rolls cover the 30% activation rate in random/fixed modes, filtering without items, expiration and silent rounds. Existing rule/failure fixtures force successful rolls without changing the production probability.
- Two-column menu: all setting values fit in English/Russian; horizontal/vertical focus neighbors and the path to Start are checked. Localized hover tooltips cover every setting and both action buttons, including live language changes. Healing sound playback is checked only when HP increases (not at full health, zero HP or with cut wires).
- Bundled cover mesh, textures and materials load without editor import.

Headless runs may emit unsupported cursor/mouse and dummy-renderer `mesh_get_surface_count` messages. These are not visual verification. The negative adapter test deliberately logs an anchor mismatch.

## Manual acceptance pending

- Install the packaged archive beside the Steam executable, launch normally, uninstall, check other configuration entries.
- Complete standard and Double or Nothing games, death/defibrillator, menu return and another game. Check dealer-first permissions, cuffs and actual AI/item interactions.
- Visually inspect both covers from gameplay cameras; test theft completion/cancel/timeout and single-frame initial-charge leaks.
- Listen to Quantity/Hidden with normal/accelerated loading; confirm eight gestures/sounds in Hidden and language-specific hints/intro dialogue.
- Test mouse, keyboard, physical controller, device switching, Escape/Back and restored focus.
- Exercise phone, magnifying glass, inverter, beer and other information-changing actions in real play.
- Check hidden health through bootup, healing, flickering digits, defibrillation and final-showdown wire cuts. Play contracts and pocket limits through actual item animations, theft timeouts, blank self-shots and cuffs; inspect the failure screen (including physical controller input), nine-option menu and compact top-left HUD at 960×540 with both languages and controller input.
- Visually inspect green shells and their higher-pitched blank indicator in Default, then initial concealment in Quantity/Hidden. Play healing shots with cuffs, sawed-off barrels and last-shell reloads in both game modes; verify turn continuation and health updates during real animations.
- Try real Steam invitations/lobby links and verify no lobby creation/join; confirm an actual Double or Nothing ending does not upload a score.

The matrix does not mean 36 manually completed games.
