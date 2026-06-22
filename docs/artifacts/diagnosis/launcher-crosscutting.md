# Diagnosis — launcher + cross-cutting UI/state

Area: launcher shell, cross-cutting UI (controls/options/pause/HUD), mouse-capture
handoff, global/persistent state (autoloads). DIAGNOSE ONLY — no fixes applied.

Files inspected:
- `scripts/launcher.gd`, `scenes/launcher.tscn`
- `scripts/ui/{pause_menu,options_menu,controls_menu,controls_overlay,crosshair}.gd`
- `scripts/{game_settings,input_settings}.gd` (autoloads)
- `scripts/body/character_creator.gd`, `scripts/body/creator_io.gd`
- `scripts/text_sandbox.gd`
- `scenes/test_level.tscn`, `project.godot`

---

## 1. Duplicated app name / title rendered twice  — **fix** (CONFIRMED)

The app advertises "aeriea" in two stacked surfaces at once when the Character
Creator mode is active (the default mode, `launcher.gd:28`):

- Launcher top bar title — `scripts/launcher.gd:64`:
  `title.text = "  aeriea  "` (a `Label` on the always-on-top `TopBar` CanvasLayer,
  `layer = 128`, built in `_build_top_bar`, lines 48–66).
- Character creator panel header — `scripts/body/character_creator.gd:594`:
  `title.text = "aeriea — character creator"` (a `Label` at the top of the
  top-left slider `PanelContainer`, built in `_build_ui`).

Both are visible simultaneously: the bar renders above all mode content
(`layer = 128`, comment at `launcher.gd:46-47`), and the creator panel sits at
`position = Vector2(16, 16)` (`character_creator.gd:585`) directly beneath it. The
word "aeriea" appears twice on screen, and the mode is named twice ("Character
Creator" tab button at `launcher.gd:23` + "— character creator" in the panel
header). Redundant self-advertisement.

What good requires: one authoritative app-name surface (the bar). Mode scenes
should not re-print the app name; at most a mode-local subtitle, or nothing (the
active tab already names the mode).

---

## 2. No design system — typography inconsistent across scenes — **redesign** (CONFIRMED)

There is no shared `Theme` resource anywhere (no `.tres` theme, no
`theme = ...` assignment, no `default_theme`). Every font size is a one-off
inline override. Distinct sizes in use across the UI:

Scene `.tscn` overrides (`theme_override_font_sizes/font_size`):
- 14 — `scenes/ui/controls_overlay.tscn:18`
- 16 — `scenes/ui/controls_overlay.tscn:49`
- 24 — `scenes/ui/options_menu.tscn:36`, `scenes/ui/controls_menu.tscn:36`
- 28 — `scenes/ui/pause_menu.tscn:41`

Script inline overrides (`add_theme_font_size_override`) — all in
`scripts/body/character_creator.gd`:
- 9  — lines 1056, 1082
- 10 — lines 750, 809, 922, 957, 1088
- 11 — lines 737, 857, 882, 888, 892, 1049

Plus two titles at engine-default size (no override): `launcher.gd:64`,
`character_creator.gd:594`.

=> **7 distinct font sizes (9, 10, 11, 14, 16, 24, 28)** plus default, none
sourced from a shared scale. The creator uses a tiny 9–11px cluster; the menus
use a large 24–28px cluster; the overlay uses 14–16. No common control sizing,
no color tokens (the only colors are ad-hoc, e.g. the title tint
`Color(0.6,0.8,1.0)` at `launcher.gd:65` and the env colors in the creator).
Switching scenes is a visible typographic jolt.

What good requires: one project `Theme` (autoloaded / set on the launcher root so
it inherits to all mode scenes) defining a type scale (e.g. caption/body/title)
and control defaults; mode scenes consume tokens, not raw px. Inline
`add_theme_font_size_override` calls retire in favor of theme type variations.

---

## 3. Character / sim state is LOST on scene switch AND on app restart — **fix/redesign** (CONFIRMED)

`launcher.switch_to` frees the outgoing mode scene unconditionally:
`scripts/launcher.gd:87-89` (`_current_scene.queue_free()`). There is NO
save-before-free and NO restore-after-instance anywhere in the launcher.

The character creator holds all edit state in instance vars on the freed node:
`_body_state`, `_history` (see `character_creator.gd`), and `_ready`
(`character_creator.gd:132-140`) ALWAYS reconstructs from scratch:
`_history = HistoryTreeScript.new(_body_state.to_dict(), "initial")` — it never
loads a prior session. So:

- Switch Creator → Parkour → Creator: all sculpting/history is gone (fresh body).
- Quit and relaunch: same — nothing restored.

The only persistence for creator state is USER-INITIATED EXPORT to
`user://creator_exports` via `CreatorIO.export_all` (`creator_io.gd:116`,
`EXPORT_DIR` at `creator_io.gd:26`) — files the player must explicitly write and
re-import. There is no autosave and no import-on-ready.

Likewise the text sandbox: `scripts/text_sandbox.gd` has no `user://` save of the
transcript (grep for `user://`/`FileAccess.WRITE`/`save` in that file: no hits;
the only "persist" mention is a comment at line 188 about in-process NPC memory).

By contrast, the SETTINGS autoloads DO persist correctly and survive switches
(they are autoloads, never freed): `GameSettings` → `user://game_settings.cfg`
(`game_settings.gd:16`, `_save`/`_load` lines 109–106), `InputSettings` →
`user://input_bindings.cfg` (`input_settings.gd:29`). So the persistence
machinery exists; it is simply not wired to character/sim state.

What good requires: cross-scene state must outlive the freed mode node — either
an autoload holding the authoritative `BodyState`/history that modes read on
`_ready` and write on `_exit_tree`, or launcher-level
save-before-free / restore-after-instance. Per CLAUDE.md "deterministic seeded
simulation / state derivable from seed + action log", the action log (history
tree) is the natural persistence unit and should autosave.

---

## 4. Mouse-capture handoff: Escape is double-consumed — first Escape never opens pause — **fix** (CONFIRMED)

Two independent Escape handlers race, ordered by Godot's input phases:

- Launcher `_input` (`launcher.gd:117-123`) runs FIRST (top-level `_input`
  before `_unhandled_*`). It consumes Escape **only when**
  `Input.mouse_mode == MOUSE_MODE_CAPTURED` (line 121), releasing to VISIBLE and
  calling `set_input_as_handled()` (line 123).
- Pause menu `_unhandled_key_input` (`pause_menu.gd:42-51`) runs LATER and only
  sees the event if it was NOT marked handled. `ui_pause` is bound to Escape
  (`project.godot`: `ui_pause` keycode `4194305` = `KEY_ESCAPE`).

Consequence in the parkour mode (mouse starts CAPTURED): the FIRST Escape press
is swallowed by the launcher (releases cursor, marks handled) — the pause menu
never opens. The player must press Escape a SECOND time (now VISIBLE, launcher
ignores it) to actually pause. The in-code comment at `launcher.gd:112-116`
acknowledges the pause flow but assumes "we only consume Escape when the mouse is
actually captured, leaving the pause flow intact when the cursor is already
free" — which is exactly the bug: in normal gameplay the cursor IS captured, so
the first Escape is always eaten before pause can fire.

Not strictly a soft-lock (the bar is reachable after one Escape; see §5), but the
documented "Escape pauses" behavior is broken on first press, and the launcher's
release fights the pause menu's own `Input.mouse_mode = CAPTURED` on resume
(`pause_menu.gd:68`).

What good requires: a single owner of Escape per mode, or launcher escape that
defers to the active mode's pause handler instead of unconditionally consuming
when captured.

---

## 5. Can you get stuck in a scene? — NO hard soft-lock, but fragile — **want** (CONFIRMED for parkour; UNVERIFIED edge in others)

- Parkour: even with mouse captured, the launcher's Escape interception
  (`launcher.gd:117-123`) releases the cursor to VISIBLE on the first Escape,
  after which the top bar (CanvasLayer `layer=128`) is clickable to switch out.
  So the bar is always reachable — no hard lock. (The cost is the §4 first-press
  pause swallow.)
- Pause menu has its own Quit that calls `get_tree().quit()`
  (`pause_menu.gd:96-97`) — that quits the WHOLE APP, not "back to launcher",
  even though the pause menu is nested inside a launcher mode. From the player's
  mental model ("I'm in a sub-mode") a Quit that kills the app is surprising;
  there is no "exit to launcher / main" affordance from inside a mode.
- The launcher itself only swaps modes on tab-button click; there is no keyboard
  shortcut to focus/return to the bar, and the tab buttons are
  `focus_mode = FOCUS_NONE` (`launcher.gd:72`) so they are NOT keyboard-navigable
  at all — bar switching is mouse-only.

What good requires: an explicit, consistent "exit to launcher" affordance inside
every mode (distinct from app-quit), and keyboard-navigable mode switching.

---

## 6. UI layout scattered / built imperatively, inconsistently — **redesign** (CONFIRMED)

The UI is split across two incompatible construction styles with no shared
structure:

- Menus (pause/options/controls/overlay/crosshair) are authored `.tscn` scenes
  with `%`-unique-name nodes and scene-level theme overrides.
- The launcher bar (`launcher.gd:48-75`) and the ENTIRE character-creator UI
  (`character_creator.gd:_build_ui`, hundreds of lines, ~580–1090) are built
  imperatively in code with `Label.new()` / `Button.new()` / per-node theme
  overrides.

There is no shared layout vocabulary (panel padding, separation, anchors are
hand-set per site: e.g. `row.add_theme_constant_override("separation", 4)` at
`launcher.gd:60` vs `vbox ... "separation", 6` at `character_creator.gd:590`).
Each menu re-implements its own back-button / submenu visibility toggling
(`pause_menu.gd:78-93` vs the per-menu `close_requested` signals). The launcher
title is a bare `Label` with no panel sizing; the bar `PanelContainer` has no
explicit height or styling. Net effect: every surface looks and behaves slightly
differently and there is no single place to change the app's look.

What good requires: a consistent UI construction approach (prefer scenes +
shared theme; if code-built, a shared widget/layout helper), shared spacing/panel
tokens, and a single reusable submenu/back-stack pattern instead of N bespoke
ones.

---

## Summary table

| # | Tag | Defect | Evidence locus |
|---|-----|--------|----------------|
| 1 | fix | "aeriea" / mode name rendered twice on screen | `launcher.gd:64` + `character_creator.gd:594` (+ tab `launcher.gd:23`) |
| 2 | redesign | No shared Theme; 7 distinct font sizes, no tokens | scenes 14/16/24/28; creator 9/10/11 (lists above) |
| 3 | fix/redesign | Character & sim state lost on switch and on restart | `launcher.gd:87-89` (free, no save/restore) + `character_creator.gd:132-140` (always-fresh `_ready`); only export at `creator_io.gd:116` |
| 4 | fix | First Escape eaten by launcher; pause never opens on press 1 | `launcher.gd:117-123` vs `pause_menu.gd:42-51`; `ui_pause`=Esc in `project.godot` |
| 5 | want | No "exit to launcher"; Quit kills app; bar is mouse-only | `pause_menu.gd:96-97`; `launcher.gd:72` (FOCUS_NONE) |
| 6 | redesign | UI split between .tscn scenes and imperative code; no shared layout | menus in `scenes/ui/*` vs `launcher.gd:48-75` / `character_creator.gd:_build_ui` |

Settings persistence (`GameSettings`, `InputSettings`) works correctly and
survives switches/restart — not a defect; noted as the existing machinery that
character/sim state (§3) should reuse.
