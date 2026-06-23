# Creator/body contested-facts — round 1 (ground truth @ HEAD 7d0685e)

Established against CURRENT code/assets. No code changed. Method per question below.

## Git ordering note (Q1 context)
- `3d78922` ("rebuild facial proxy deltas … eyes/teeth/tongue follow morph") is an **ancestor** of `bd33b49` ("reverify body-visual …") — fix committed first, in linear history (`3d78922` → `fac8be5` → `bd33b49`).
- BUT the reverify doc's *file mtime* is `01:03`, while the rebuilt proxy artifacts (`base_body_proxies_detail.{bin,index.json}`) have mtime `01:11`. So the "byte-identical" prose was written **before** the rebuilt deltas existed — it describes pre-fix artifacts, then got swept into a later commit. The doc is stale relative to the assets it sits beside.

---

## Q1 — Does facial proxy eye/teeth/tongue FOLLOW gender morph at HEAD? — **TRUE (they follow).**
The "byte-identical across masculinity 0/50/100" claim is **FALSE on current assets**.

Evidence:
- `assets/body/base_body_proxies_detail.index.json`: 188 `"kind":"macro"` anchors, incl. `macrodetails/caucasian-female-young.target` and `caucasian-male-young.target`, each with `count:1219` = full `render_vertex_count:1219` → nonzero delta on **every** proxy render vert.
- Binary blob check (`base_body_proxies_detail.bin`): female-young vs male-young anchors are **not identical** — avg |delta-of-deltas| = **0.126 m/vert**, max 0.148 m; both 1219/1219 verts nonzero.
- Application chain: `BodyRig.apply_body_state` → `ProxyMorph.apply(state, proxy)` (`scripts/body/body_rig.gd:720`) → `state.to_blend_weights()` which emits `macrodetails/caucasian-{female,male}-*` keys (`scripts/body/body_state.gd:400-406`) → applied against the proxy delta library (`scripts/body/proxy_morph.gd:108-127`).
- Runtime, masculinity ISOLATED (age held at 25, sweep 0/50/100), per-surface max vertex delta:
  - eyes: 0→50 = 0.0724 m, 50→100 = 0.0724 m, 0→100 = 0.1448 m, identical0v100 = **false**
  - teeth: 0→50 = 0.0689, 0→100 = 0.1379, identical = false
  - tongue: 0→50 = 0.0673, 0→100 = 0.1345, identical = false
- Existing suite `tests/body_proxy_test.gd` passes 46/0 at HEAD, incl. "eyes follow the macro morph … differ (>1mm)" [0.1045 m] and "eyebrows follow the macro morph" [0.0328 m].

## Q2 — Are all `present` flags false, and what do they mean? — **TRUE (all 531 false), but the flag is NOT a dead-control signal.**
- Count: 0 `true`, 531 `false` (registry `counts.targets_present:0, targets_missing:531`).
- Meaning (`scripts/body/modifier_registry.gd:221-226`): `present = FileAccess.file_exists(targets_dir.path_join(rel))` — purely "is the `.target` morph FILE on disk under the build-time targets root."
- Why all false: the nix build resolves targets against the vendored CC0 subset (`vendor/makehuman-cc0/data`, `tools/modifier_registry_build.gd:33-44`), which ships only macro targets, not the full detail `.target` set ("Slice C"). Header comment `modifier_registry.gd:55-61` says so explicitly. A missing target is "Slice C supplies it later", NOT an error.
- Therefore a build-time guard keyed on `present` is meaningless (all false). The REAL live-vs-dead signal is in the **delta library**: `count == 0` ⇒ no displacement (dead), `count > 0` ⇒ live. Checked via `DetailLibrary.has_target` / `count==0` (`detail_library.gd:76,93`) and `proxy_morph.gd:113`. A dead control like BreastSize would show as `count:0` in the `.index.json`, not via `present`.

## Q3 — Belly volume/protrusion control after removing pregnancy. — **NUANCED: real gap for a *rounder belly*; only whole-torso depth/circumference remain.**
Stomach-group modifiers in registry (labels):
- `stomach/stomach-pregnant-decr|incr` — **"Pregnancy shape"** (the protrusion control; this is what's being removed)
- `stomach/stomach-tone-decr|incr` — **"Muscular tone"** (abs definition, NOT protrusion — adversary correct)
- `stomach/stomach-navel-in|out`, `stomach/stomach-navel-down|up` — navel position only
Nearest non-stomach controls: `torso/torso-scale-depth-decr|incr` ("Scale depth" — scales the *whole torso* front-back, not a local belly bulge), `measure/measure-waist-circ-decr|incr` ("Waist circum"), `hip/hip-waist-down|up` (waist vertical position), plus the `Weight` macro (whole-body fat). **No modifier isolates local lower-belly volume/protrusion** other than `stomach-pregnant`. Removing it leaves a genuine gap for a "rounder/bigger belly" that isn't whole-torso scaling or global weight.

## Q4 — Persistence read-side. — **TRUE: import/parse fully implemented; only scene wiring missing.**
- `scripts/body/creator_io.gd`: `parse_payload(text)` (`:51`, handles bare-BodyState + with-history JSON → BodyState + HistoryTree), `extract_history_from_png(png)` (`:66`), `extract_history_from_image(bytes, format)` (`:100`).
- Round-trip TESTED: `tests/creator_history_test.gd` (PNG tEXt embed→extract, JSON-with-history export→import reproduces the tree).
- `scripts/body/character_creator.gd` references NONE of the import fns — only `_build_export_ui` (`:875`) with JSON/image export buttons (`:899-914`) and `FileAccess.WRITE` (`:1392,1399`). No `_build_import` / import button / FileDialog / drop handler exists. So the gap is purely import-side scene wiring.

## Q5 — Clamp-on-hot-path cost. — **TRUE: bake runs every drag-motion frame over all render verts.**
Path: mouse-motion while dragging → `_apply_morph_drag(mm.relative)` (`character_creator.gd:663` → fn at `:446`) → `_apply_state()` (`:472`) → `_rig.apply_body_state(_body_state)` → `BodyState.bake_morphed_normals` (`body_state.gd:634`). The bake reconstructs morphed positions over all render verts (`:649`, `:664-665`), iterates the sparse delta library (`:670-676`), and recomputes per-vertex normals via per-triangle accumulation (`:677-690`). Every mouse-motion frame of a sculpt drag. (The comment at `character_creator.gd:1261` "Only runs on slider changes, so it's cheap" is inaccurate for the drag path.) Adding per-vertex cumulative-displacement clamp work in this chain lands squarely on the interactive hot path.

## Q6 — Tangent weld. — **TRUE: normals welded across UV seams, tangents deliberately NOT.**
`tools/body_converter.gd`:
- Normals: `_compute_normals(scaled_render, tris, render_to_base)` (`:218`) — accumulates on UN-SPLIT base topology then scatters to UV-split duplicates ⇒ welded across seams (`:215-217`).
- Tangents: `_compute_tangents(...)` (`:224`) with comment `:222-223`: "**NOT welded across UV seams**: a tangent is parameterised by UV, and split corners have distinct UVs, so each side legitimately gets its own tangent."
So a tangent-rebake that "mirrors the normal weld" would WRONGLY weld tangents across UV seams and re-introduce a seam in normal-mapped detail. **Yes — mirroring the normal weld onto tangents is wrong.**
