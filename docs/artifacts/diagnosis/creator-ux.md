# Character Creator — UX + scene diagnosis

Diagnose-only. Evidence cited as `file:line`. Verified by reading source + one headless render
(`/tmp/cc_default.png`) and two timing harnesses under xvfb. Files in scope:
`scripts/body/character_creator.gd`, `scenes/character_creator.tscn`,
`scripts/body/region_sliders.gd`, `scripts/body/morph_drag.gd`, `scripts/body/creator_io.gd`.

---

## 1. Default camera shows the BACK of the character — CONFIRMED, with a self-contradicting comment pair

**fix.**

- `character_creator.gd:35-36` (class field) claims: `_yaw: float = PI  ## PI = camera in front of
  the body (the MakeHuman base faces -Z, so the camera sits on -Z)`.
- `character_creator.gd:276-277` (`_update_camera`) claims the OPPOSITE about which way the body
  faces: `# yaw=0,pitch=0 places the camera on +Z (in front of the body, which faces +Z)`.
- These two comments disagree on the body's forward axis (-Z vs +Z). The authoritative statement is
  `scripts/movement/interpreted_player.gd:186`: **"The body faces -Z (Godot forward)"**.
- **Render proves the default view is the BACK** (`/tmp/cc_default.png`, captured by instantiating
  `character_creator.tscn` and grabbing the viewport): hair down the back, no face, gluteal cleft
  visible. So with `_yaw=PI` the camera ends up BEHIND the body, not in front.
- Math: at `_yaw=PI`, `dir = (sin(PI)·c, sin(pitch), cos(PI)·c) = (0, sin(pitch), -c)`
  (`:278-282`), so the camera sits on **-Z** looking toward +Z. If the body's face is on -Z
  (per interpreted_player), the camera at -Z should see the front — yet the render shows the back.
  So EITHER the body is actually rotated 180° in the creator vs the game convention, OR `_yaw=PI` is
  the wrong default. Both comments are wrong about the observed result regardless.

**What good requires:** pick the convention, verify it against a render, and make the default
`_yaw` show the FRONT (face + chest) on open — the first thing a player wants to see is the face.
Then make the two comments agree with the verified facing. (Likely fix is `_yaw = 0.0`, but VERIFY
with a render — do not flip it blind, since the in-comment math and the render already disagree.)

## 2. Sculpt mode is a mode-toggle behind 'M', and the keybind is HIDDEN when active — CONFIRMED

**redesign.**

- Toggle gate: `character_creator.gd:461-468` (`_set_sculpt_mode`), bound to `M` at
  `:507-511` and to the button at `:599-603`.
- The button label only shows the keybind when sculpt is OFF: `"Sculpt mode: ON (drag body to
  morph)" if on else "Sculpt mode: OFF (press M)"` (`:465`). Once active, the "press M" affordance
  is gone — a user who turned it on (or had it on) has no on-screen reminder of how to exit, and the
  full controls legend is itself hidden behind a Ctrl hold/pin (`:722-757`, default
  `visible = false` at `:728`). So the only persistent discoverability of the toggle key vanishes in
  exactly the mode where the input semantics changed.

**What good requires:** keep the keybind visible in both states (e.g. "Sculpt: ON — press M to exit")
and/or surface a persistent mode badge; do not gate the only hint behind the same mode it documents.

## 3. Asymmetry enabled by default — REFUTED (no asymmetry feature exists at all)

**(no defect of this shape.)** `grep` for `asymmet|symmetry|asym` across `body_state.gd`,
`body_rig.gd`, `morph_drag.gd`, `detail_library.gd` returns nothing. There is no asymmetry concept
in the pipeline. Bilateral stems are driven SYMMETRICALLY by construction: a `l-…` spec expands to
BOTH `l-` and `r-` modifiers with the same value (`region_sliders.gd:136-145`). So "asymmetry
enabled by default" is not present; the system is symmetric-only. (If per-side asymmetry is *wanted*,
that's a **want**, not a bug — there is currently no way to make the two sides differ via the named
sliders.)

## 4. Sculpt morph ranges vs slider ranges — MATCH (claim REFUTED)

**(no defect.)** Sculpt clamps each modifier to its REGISTRY range:
`morph_drag.gd:365-368` (`clampf(cur + share·raw, rng[0], rng[1])`), where `range` comes from the
registry entry built at `modifier_registry.gd:183` (bidirectional → `[-1.0, 1.0]`) and `:169/:191`
(unipolar → `[0.0, 1.0]`). The named sliders use the SAME bounds:
`region_sliders.gd:118-121` (`BIDIR_MIN/MAX = ±1.0`, `UNIPOLAR_MIN/MAX = 0..1`), wired in at
`character_creator.gd:1040-1041`. Ranges are identical, so sculpt and sliders cannot disagree on
limits. Refuted.

## 5. Abbreviated slider labels ("bust circ.", "hips circ.", etc.) — CONFIRMED (authored strings)

**fix (cosmetic).** These are authored display strings, not clipping:

- `region_sliders.gd:48` `"bust circ."`, `:49` `"underbust"`, `:64` `"hips circ."`,
  `:67` `"torso-to-hip"`, `:110` `"rect."`, `:111` `"triangle"`.
- The label column is only 94 px (`character_creator.gd:1048`) at font size 11 (`:1049`), which is
  WHY the authoring abbreviated — but the abbreviation is in the data string, the label is not being
  truncated by layout.

**What good requires:** widen the name column (or wrap) and spell the words out ("bust circumference",
"hips circumference"); abbreviations like "circ." read as engineering shorthand, not player-facing.

## 6. Typography inconsistency / no shared Theme — CONFIRMED

**redesign.** There is **no `Theme`** set anywhere in the creator (`grep theme|Theme` over
`character_creator.gd` → zero hits). Every size is an ad-hoc per-widget
`add_theme_font_size_override`. Distinct explicit sizes set:

- size **9** ×2 — region-slider poles (`:1056`, `:1082`)
- size **10** ×5 — main-axis poles (`:922`, `:957`), status toast (`:809`), legend body (`:750`),
  region value label (`:1088`)
- size **11** ×6 — region name (`:1049`), region value-of-axis paths and history rows
  (`:857`, `:882`, `:888`, `:892`), legend header (`:737`)
- size **(unset, ~Godot default 16)** — the title (`:594`), every main button (sculpt/reset/history/
  export), all main-axis name/value labels (`:914`, `:963`), panel headers (`:699`, `:771`, `:991`),
  undo/redo glyphs.

So **4 distinct font sizes** (9 / 10 / 11 / default-16) chosen by hand per call site, no shared
Theme, no scale ramp. 13 total `font_size` overrides.

**What good requires:** one `Theme` resource (a small type scale: e.g. title / body / caption) applied
once to the CanvasLayer, deleting the per-widget overrides. Consistent spacing constants too (separation
is set ad-hoc to 1/2/3/4/6 across `:591,:660,:695,:709,:732,:750,:850,:911,:1001,:1008,:1044`).

## 7. State LOST on scene switch and on app restart — CONFIRMED (no persistence at all)

**fix (high impact).** The creator's working state is `_body_state: BodyState = BodyState.new()`
(`character_creator.gd:31`) plus the in-memory `_history` tree (`:112`, seeded fresh each
`_ready` at `:133`). There is:

- **No `user://` read/write** for state (`grep user://|save|load_state|persist|ConfigFile` → zero
  hits; the only `save`/`load`-shaped code is manual EXPORT to a timestamped file in
  `_export_json`/`_export_image`, `:1244-1280`, which the user must trigger and which is never read
  back on open — there is no import path in this script).
- **No `_exit_tree` / `_notification(NOTIFICATION_WM_CLOSE_REQUEST)`** autosave (zero hits).

So switching scenes or quitting silently discards the entire edit + its branching history. Export is
opt-in, one-directional (write-only here), and timestamp-named — not a resume mechanism.

**What good requires:** autosave the BodyState (and ideally the HistoryTree) to `user://` on change /
on exit, and restore on `_ready`; plus a real IMPORT action to reload an exported JSON/PNG (CreatorIO
already has `history_to_json` / `embed_history_in_image` for the write side; the read side is
unused/absent here).

## 8. ~1s load freeze — CONFIRMED in shape (all build work is synchronous in `_ready`)

**fix.** `_ready` runs five heavy builders back-to-back with no async/loading screen:
`character_creator.gd:132-139` → `_build_environment`, `_build_body` (`:188-205`, which adds a
`BodyRig` whose `_ready` runs `build()` constructing the Skeleton3D + per-instance skinned mesh + CPU
normal bake — `body_rig.gd:286-293`, a 1770-line module), `_build_morph_drag` (`:212-235`, builds the
morph accel structure over the registry + loads DetailLibrary + builds the CPU spatial-grid picker
over all body triangles, `:226-228`), `_build_camera`, `_build_ui` (which itself builds the full
56-slider region panel, `:978-1024`). Measured cold instantiate+ready = **89 ms on llvmpipe**
(`/tmp/cc_time.gd`), but that is a software-rasterizer headless number with no shader compilation
and a warm asset cache; the synchronous skinned-mesh build + accel build + grid build are exactly the
kind of work that lands at ~1 s on a real first-open (shader stalls + cold disk + GPU upload). The
defect is structural: **it is all blocking, on the main thread, in one frame, with no progress UI** —
so any cost shows as a hard freeze.

**What good requires:** show a loading indicator immediately, then build off the first frame (defer
the heavy builders via `call_deferred`/a coroutine, or thread the accel + picker grid which are pure
and deterministic — `morph_drag.build_accel` and `cpu_accel_picker.build` take only data). At minimum
the picker grid (`:226-228`) is lazy-rebuilt already (`_apply_state` marks it dirty) so it need not
block open at all.

---

## Secondary observations (not in the asked list, found while reading)

- **want — export is write-only, no import in the scene.** `_export_*` (`:1244-1280`) writes files but
  nothing in `character_creator.gd` ever calls a CreatorIO import/parse to load one back. Combined with
  finding #7, a player literally cannot get a saved character back into the creator.
- **want — export goes to a timestamped path with no file dialog and no on-screen path.** Toasts say
  "exported JSON (current)" (`:1254`) but never where; `_export_basename` is a unix-timestamp
  (`:1238-1240`) under `CreatorIO.EXPORT_DIR`. The user cannot choose a name/location and cannot find
  the file from the UI. The "no persistent path text" design choice (`:122`, `:582`) removed the only
  breadcrumb.
- **redesign — export controls are a flat stack of 4 near-identical buttons + a format dropdown**
  (`_build_export_ui`, `:766-814`): "Export JSON (current)", "Export JSON + history", "Export image
  (current)", "Export image + history". Four buttons for a 2×2 matrix (JSON|image × current|+history)
  is the layout mess; a {JSON / image} toggle + a single "include history" checkbox + one Export
  button would collapse it.
- **want — sliders show no numeric entry.** Values are display-only labels (`_format_value`,
  `:1132-1143`; region `"%+.2f"`); a player can't type an exact age/height, only drag.
- **fix — the 'P' picker-backend toggle is a dev/debug control exposed in the player input map**
  (`:512-519`). It is documented in the legend as a user control (`:743`), but switching CPU↔GPU
  picking is not a player-facing concept; it should be behind a dev flag, not on `P` in shipping.
