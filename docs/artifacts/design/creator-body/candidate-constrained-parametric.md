# Candidate design — Character Creator + Body: **constrained-parametric / "editing that just works"**

Status: DESIGN CANDIDATE (one frame of a design-it-twice set). Not committed. No feature code.
Date: 2026-06-23.

Frame (the lens this whole document optimizes for): **curated, semantically-correct, bounded
controls** where you *literally cannot build a broken or monstrous body*. Every slider means
what its label says; symmetry is sane by default; the validity envelope is enforced by the
system, not by player discipline. The optimization target is **trustworthy, predictable
editing** — the player forms a correct mental model from the first drag and the system never
violates it. This is the opposite of a freeform-sculpt frame; sculpt is demoted to a bounded
"nudge", not a primitive.

---

## 0. Grounding — what is actually true *right now* (verified, not from stale diagnosis)

I read the sources and the diagnosis artifacts, then **re-verified the load-bearing claims
against current `HEAD`**, because several diagnosis findings are already stale. The diagnosis
files (`docs/artifacts/diagnosis/body-render.md`, `body-visual-reverify.md`, `body-reverify.md`,
`creator-ux.md`) were written 2026-06-23 00:00–01:03. **Two commits landed AFTER that
(`b12bcd7` "weld normals across UV seams + add tangents", `5c33ca5` "compute normals
correct-by-construction on base topology", both `2026-06-23 02:35`)** and invalidate parts of
the fidelity diagnosis. Per CLAUDE.md ("something unexpected is a signal — stop and find out
why"), I chased this rather than designing against the stale text.

What I verified at HEAD (cite):
- **Seam-normal two-tone / faceting (diag body-render #3, body-visual-reverify #4): FIXED.**
  Normals are now accumulated **per BASE vertex** via a persisted `render_to_base` map
  (`ARRAY_CUSTOM1`) and scattered back to seam duplicates, at BOTH build time
  (`tools/body_converter.gd:216-218, :218 _compute_normals(..., render_to_base)`) and
  morph-rebake time (`scripts/body/body_state.gd:677-708`, the verbatim "CORRECT BY
  CONSTRUCTION … IDENTICAL mechanism" block). The diagnosis's central seam mechanism no longer
  applies. *(Unverified-by-render: I did not re-render to confirm the seam is gone on screen;
  I verified the code path that the diagnosis named as the cause is replaced. Would re-render
  `bvd_head_back` / `bvd_body_lit` to close this fully.)*
- **Tangents (the normal-map blocker, body-visual-reverify #3c): FIXED.** The converter now
  writes `ARRAY_TANGENT` from UVs (Lengyel), deliberately NOT welded across seams because a
  tangent is UV-parameterized (`tools/body_converter.gd:219-281`), and zeroes tangent deltas
  per blendshape to match surface format (`:408,:466`). **So a skin normal map is now
  applicable** — this is the single most important correction to the fidelity plan below.
- **Proxy facial features (eyes/teeth/tongue/brows) do NOT follow the macro morph
  (body-visual-reverify #1): STILL TRUE — this is a DATA defect**, not code. The proxy detail
  library (`assets/body/base_body_proxies_detail.index.json`, 8 macro targets) was baked
  against a near-disjoint macro target set from what the body emits (188 macro targets in
  `assets/body/base_body_detail.index.json`). At neutral/feminine the eyeballs ride up to the
  brows and teeth/tongue protrude by the nose. **Confirmed still present** (the post-diagnosis
  commits only touched normals/tangents, not the proxy bake).
- **Unbounded additive morph stacking (body-reverify #2): STILL TRUE.** Per-modifier values
  clamp to range (`body_state.gd:_project_modifiers :554,:563`) but the composed *displacement*
  is a pure sum (`detail_library.gd:104 morphed[ri] += Δ*weight`) with no combined bound. This
  is the centerpiece this frame must solve.
- **Dead breast-size macro: CONFIRMED.** `breast/BreastSize` & `breast/BreastFirmness` are
  `kind:"macro"` (`assets/body/modifier_registry.json:248-249`), but (a) `_project_modifiers`
  *skips* every macro kind (`body_state.gd:551-552`) and (b) `to_blend_weights` only walks the
  *universal* cube (`DetailLibrary.paths_of_kind("macro")` = gender×age×muscle×weight ×
  proportions; `body_state.gd:488`). The MakeHuman breast cube factor tokens
  (`breastsize: mincup/averagecup/maxcup`, `breastfirmness: minfirmness/averagefirmness/
  maxfirmness`; verified `body-parameterization.md:218-219`) **were never imported** into the
  library at all (`grep cup|firm assets/body/base_body_detail.index.json` → none). So there is
  no driving path AND no data. Both must be fixed.
- **No skin/eye textures exist anywhere** (`find assets -iname '*skin*'|*normal*|*.png'` →
  none; skin material is bare `StandardMaterial3D` albedo+roughness, `body_rig.gd:359-361`).
  No MakeHuman skin/litsphere texture is realized in the nix store at design time
  (`find /nix/store -path '*makehuman*data/skins*'` → empty store path — the pin isn't
  realized in this shell; flagged unverified below).
- **Symmetry**: there is NO asymmetry feature (body-reverify #1 / creator-ux #3). Sliders are
  symmetric by construction (a bilateral `l-` stem drives BOTH `l-` and `r-`,
  `region_sliders.gd:136-145`); **sculpt is one-sided** (`morph_drag.gd` is per-vertex, no
  mirror). So "symmetry by default" is *already true for sliders* and *false for sculpt*.
- **Creator UX**: default camera shows the BACK was a defect; `_yaw` is now `0.0`
  (`character_creator.gd:42`) — needs a render to confirm it shows the front. No state
  persistence at all (creator-ux #7): `_body_state = BodyState.new()` each open, no `user://`
  I/O, export is write-only timestamped files. Sliders are display-only, **no numeric entry**
  (creator-ux secondary). ~1s synchronous build in `_ready` (creator-ux #8).

This grounding is the requirements input. The design below makes a decided call on each
prompt item, from the constrained-parametric frame.

---

## 1. Slider/control taxonomy — organization, naming, numeric entry, reset/randomize, symmetry, sculpt

### 1.1 Two tiers, one model: **Headline axes** (whole-body macro) → **Region controls** (local shape)

The taxonomy is a strict two-level tree, and it is the SAME tree the data already has — we do
not invent a parallel UI ontology (data-over-code at the seam). Tier 1 is the natural-unit
macro axes that exist as first-class `BodyState` fields; Tier 2 is the curated region table
that already exists as `RegionSliders.GROUPS`.

**Tier 1 — Headline (always visible, top of panel, 6 axes):**

| label | field | unit / range | control |
|---|---|---|---|
| Age | `age_years` | 18–90 yr (base creation; see §2) | slider + numeric (yr) |
| Build (fem ↔ masc) | `masculinity` | 0–100 (50 = androgynous) | slider + numeric |
| Height | `height_cm` | clamped per age/sex (see §3) | slider + numeric (cm) |
| Muscle | `muscle` | 0–100 % | slider + numeric |
| Weight | `weight` | 50–150 % (50 = lean, 100 = avg, 150 = heavy) | slider + numeric |
| Proportions | `proportions` | 0–100 (50 = average) | slider + numeric |

These are the coarse dials; they are *natural-unit* and self-explanatory, which is the whole
point of the parameterization decision. They are NOT relabeled.

**Tier 2 — Regions (collapsible groups, accordion):** the existing `RegionSliders.GROUPS`
ordering — Breasts, Glutes & pelvis, Belly & stomach, Waist & hips, Torso & shoulders, Arms,
Legs, Neck, Head & face shape. Each region is a collapsible section; one open at a time by
default (keeps the panel short, fixes the creator-ux #8 "56-slider wall" feel).

**Decided: NO third tier in base creation.** The registry's long tail (per-finger, per-AU
micro-targets — 291 modifiers total) is NOT surfaced. The curated `RegionSliders` set IS the
contract. Reaching the long tail is a *post-creation* "advanced" affordance, not part of the
trustworthy base flow. (This is the frame's core stance: a *curated* surface, not exhaustive.)

### 1.2 Naming — spell it out, kill engineering shorthand

Fixes creator-ux #5. Every label is a player-facing noun phrase. Concretely amend
`RegionSliders.GROUPS` display strings: `"bust circ."`→`"bust circumference"`,
`"hips circ."`→`"hips circumference"`, `"torso-to-hip"`→`"torso-to-hip length"`,
`"rect."`→`"rectangular"`, `"triangle"`→`"triangular"`. Each slider keeps its two **pole
labels** (`lo_pole`/`hi_pole`, e.g. small↔large) shown at the slider ends — these are the
"means what the label says" guarantee: the player reads the direction off the control.
Tooltips come verbatim from MakeHuman's `*_modifiers_desc.json` (already captured as the
`tooltip` field in the registry manifest; `modifier_registry.gd:332`).

A shared `Theme` (fixes creator-ux #6): three sizes — title / body / caption — applied once to
the CanvasLayer, deleting the 13 ad-hoc `font_size` overrides. One spacing constant scale
(2/4/8). This is taxonomy hygiene: consistent typography is part of "every control means what
it says."

### 1.3 Numeric entry — **mandatory in this frame** (fixes creator-ux secondary)

Predictable editing requires exact entry. Every Tier-1 axis gets a `SpinBox` bound to the same
field as its slider (shows the natural unit: `25 yr`, `170 cm`, `60 %`). Tier-2 region sliders
get a compact numeric readout that is *editable* (click-to-type) showing the signed `%+.2f`
axis value (or a 0–100 remap — see below). Slider and SpinBox are two views of one bound value;
editing either updates both and re-morphs. Numeric entry is clamped to the SAME envelope as the
slider (§3), so you cannot type your way past the bounds — typing "9999" snaps to the cap and
the field visibly corrects, reinforcing the contract.

**Decided remap for region readouts:** internal axis is `[-1,1]` (bidirectional) / `[0,1]`
(unipolar), but the player sees `-100..+100` / `0..100`. Players think in percentages, not
`0.62`. The remap is display-only; storage stays the registry-native range.

### 1.4 Reset / Randomize

- **Reset (per-control + per-region + global):** every control has a tiny reset glyph that sets
  it to its registry `default` (0 for region axes, the natural-unit defaults for Tier-1).
  Per-region "reset region" and a global "reset all". Reset is *instant and total* — no
  confirmation for a single control, a single undo entry for region/global (the history tree
  already exists, `character_creator.gd:112`).
- **Randomize — bounded and per-scope, NOT a chaos button.** This is where the frame earns
  trust: randomize draws each axis from a **truncated distribution centered on default**, then
  runs the SAME validity envelope (§3) so the result is *always a plausible body*. Scopes:
  "randomize face", "randomize build", "randomize all". A "subtle" vs "varied" amount control
  sets the distribution width. **Decided: randomize is seed-logged** (deterministic sim
  invariant — the roll is an action in the action log, reproducible). No randomize ever
  produces a body the player couldn't have built by hand — that is the contract.

### 1.5 Symmetry — **default ON, single global mirror toggle**

The frame demands symmetry sane by default. Current state: sliders symmetric, sculpt one-sided.
Decided:
- **One global "Mirror edits" toggle, default ON.** When ON, every edit (slider, numeric,
  sculpt nudge) applies to both sides. For sliders this is already the behavior
  (`resolve_full_names` drives `l-` and `r-`); we keep it. For sculpt, the nudge must be
  mirrored (see §1.6) — closing the body-reverify #1 gap.
- **When OFF**, per-side editing is allowed *only* via explicitly-paired controls (an arm/leg
  region shows "both / left / right" segment). We do NOT expose `asym/*` targets (62 asymmetry
  targets in MH) in base creation — controlled asymmetry is a post-creation advanced feature.
  Rationale: uncontrolled asymmetry is the #1 source of "monstrous" results; defaulting it off
  and gating it is the frame's whole thesis.

### 1.6 Sculpt / direct-manip — **demoted to a bounded "nudge", not a primitive**

This is the decisive frame call. In a freeform frame sculpt is the headline; here it is a
*convenience over the same bounded axes*. Concretely:
- Sculpt drag does NOT introduce new degrees of freedom. `morph_drag.decompose_drag` already
  projects a drag onto **registered modifiers clamped to their range**
  (`morph_drag.gd:365-368`) — i.e. sculpt is already "drive the named sliders by grabbing the
  mesh." We keep exactly that and re-frame the UI: grabbing the body **moves the same sliders**
  (their handles animate live during the drag), making the equivalence visible. There is no
  per-vertex freeform displacement, ever.
- **Sculpt obeys the global mirror toggle.** When mirror is ON, a drag on the left arm picks
  the bilateral pair and applies the decomposed delta to BOTH `l-` and `r-` modifiers (mirror
  the picked candidate set across the body's sagittal plane and union the modifier sets). This
  is the body-reverify #1 fix, done at the modifier level (not a mesh mirror), so it stays
  within the validity envelope.
- **Sculpt obeys the validity envelope (§3).** A nudge that would push the *combined* region
  displacement past the envelope is clamped at the envelope boundary — the body resists, it
  does not deform monstrously. The handle stops moving; that is the feedback.
- Mode discoverability fix (creator-ux #2): the toggle keybind stays visible in BOTH states
  ("Sculpt: ON — drag body; press M to exit"); a persistent mode badge; no hint hidden behind
  the mode it documents. The `P` picker-backend toggle (creator-ux secondary) moves behind a
  dev flag, off the player input map.

---

## 2. Editable in base creation vs gated

**Decided rule: base creation = the adult, non-stateful body envelope. Anything that is a
*runtime simulation state* rather than a *standing body configuration* is OUT of base
creation.** This is a clean, defensible line, not an ad-hoc blocklist.

- **Age: clamped to 18–90 in base creation.** The continuous axis [1,90] stays *representable*
  in the engine (NPCs of any age exist — `is_adult_body` gates the *intersection* of
  child-range × NSFW verb, not the primitive; `body_state.gd:448-451`). But the *player's own
  base creation slider* is hard-clamped to ≥18. The gate stays exactly where it is (the single
  `is_adult_body` predicate, fail-closed on NaN); base creation simply never offers a sub-18
  handle. (Reaffirms `body-parameterization.md` §5 — gate the configuration, not the
  primitive.)
- **Pregnancy: OUT of base creation.** Verified the only pregnancy-named modifier is
  `stomach/stomach-pregnant-decr|incr`, currently surfaced relabeled as the generic "belly
  flat↔round" slider (body-reverify #3). **Decided: split the concept.** A genuine
  *belly-roundness/softness* slider stays (driven by `stomach/stomach-tone` + a non-pregnant
  belly-volume target) so heavy/soft bellies are buildable; the **`stomach-pregnant` target
  itself is removed from the base-creation table** and reserved for the pregnancy *simulation
  state* (a runtime body modifier applied by the sim, animated over a term, not a creation
  slider). Rule restated: pregnancy is a *state the body enters*, not a *shape you author at
  birth* — so it lives with the runtime body-modifier system, gated like any other sim state.
- **Genitals: editable in base creation**, behind the NSFW toggle (SFW is a rendering layer,
  not a content rewrite — DESIGN.md). The 6 genital targets are standing configuration, so
  they belong in creation; the SFW toggle hides the *region group and its rendering*, not the
  underlying state.
- **Always editable in base creation:** the 6 headline axes + the curated `RegionSliders` set
  (minus pregnant target) + skin tone + eye color + hair/eyebrow style/color (part library).
- **Gated to post-creation/runtime (NOT base creation):** pregnancy, transient body states
  (arousal/swelling/transformation in-progress), the registry long tail (per-AU/per-finger),
  and `asym/*` controlled-asymmetry.

---

## 3. Bounds — the centerpiece: guaranteeing no monstrous proportions

The defect (body-reverify #2): per-modifier values clamp, but composed displacement is an
unbounded sum, so overlapping regions (bust + breast-volume + belly + waist + hips all touch
neighbouring verts) stack to grotesque, and at extremes the coarse mesh facets (body-reverify
#4). Per-modifier clamps cannot fix this because the problem is *combinatorial*.

I considered three mechanisms (design-it-twice within the item):

- **(A) Validity envelope on the public AXES** (constrain the input space): a precomputed set
  of pairwise/region constraints on the natural-unit + region axis values, enforced as the
  player edits — "when waist is already wide, hips cannot also be at max."
- **(B) Combined per-vertex displacement clamp** (constrain the output): after summing all
  deltas, clamp each vertex's total displacement magnitude to a per-region budget before
  baking.
- **(C) Normalized contribution / partition-of-unity** (constrain the composition): when
  multiple modifiers touch the same vertex, normalize their summed weight so overlapping
  regions share a displacement budget rather than adding freely.

**Decided: (A) as the primary guarantee, (B) as the hard backstop. Not (C) alone.**

Reasoning from the frame: the frame's promise is *"you literally cannot build a broken body."*
That promise must be enforced at the **input** so the player never even *sees* a broken state
and the slider handles themselves reflect the limit (predictable). (C) is invisible and would
make a slider "stop doing anything" with no explanation — it violates "every control means
what its label says." (B) is a safety net but as a *sole* mechanism it produces the same
"slider does nothing past X" opacity. (A) makes the bound legible: the handle range *shrinks*
visibly as related controls move.

**(A) — the validity envelope, concretely:**
1. A declarative constraint table (DATA, alongside `RegionSliders.GROUPS`), each entry a
   *region budget*: a set of axes that overlap in vertex space share a summed-magnitude
   budget. Example: `{ region: "midsection", axes: [waist-circ, hips-circ, belly,
   bust-circ], budget: 2.4 }` means the sum of absolute axis values across that set cannot
   exceed 2.4 (numbers TBD by tuning, see quality bar §7). The overlap sets come from the
   DetailLibrary footprints — two modifiers are "overlapping" if their moved-vertex sets
   intersect above a threshold; this is **computable offline** from
   `base_body_detail.index.json` (the `record`/index already lists moved verts per target), so
   the table is *derived data*, not hand-guessed adjacency.
2. As the player drags axis X, the remaining headroom in each budget X participates in is
   computed; X's effective max is `min(registry_max, headroom)`. The slider's drawn track
   shrinks to the live cap; the handle cannot pass it. Numeric entry snaps to it.
3. This is **monotone and order-independent in display** because the budget is symmetric: it
   doesn't matter which axis you raised first; the joint feasible region is the same convex
   set. (Implementation note: this is a box-plus-L1-ball feasible region per region budget —
   trivially projectable.)

**(B) — the per-vertex backstop**, concretely:
- After `to_blend_weights` → sum-of-deltas (`detail_library.apply` loop,
  `body_state.gd:670-676`), before the normal rebake, clamp **per base vertex** the total
  displacement magnitude to a ceiling `D_max(region)` derived from local mesh edge length
  (a displacement can't exceed ~k× the average incident edge length, which is what causes the
  faceting in body-reverify #4). This is a cheap pass over `morphed` keyed by `render_to_base`.
- (B) should essentially never fire if (A) is tuned right; it exists so a *data* mistake (a new
  slider added without an envelope entry, or a loaded older save) can never render a monster.
  Fail-safe, not the primary mechanism.

**Why not pure (C):** rejected as primary because invisible normalization breaks the legibility
contract. (C)'s partition-of-unity idea *is* folded into (A) implicitly: the region budget IS
a shared partition, just made *visible* as shrinking handle ranges.

**Determinism:** both (A) and (B) are pure functions of the axis vector — no RNG, replay-safe.
The envelope table is content-hashed into the save so an old save loaded under a newer envelope
is re-validated (and visibly snapped) on load, never silently rendered out-of-envelope.

---

## 4. Correct semantics — fixing the dead macro (breast size etc.)

The macro-driving gap, root-caused (§0): macro modifiers (`BreastSize`, `BreastFirmness`) have
no driving path (`_project_modifiers` skips macro kind) AND no data (the breast cube targets
were never imported). A macro is fundamentally different from a directional modifier: it sets a
*factor variable* that re-weights a whole **factor-product cube**, exactly like gender/age/
muscle/weight already do (`body_state.gd:471-501`, `_universal_target_weight`). The fix
mirrors that proven path. Two parts:

**4.1 Data — import the breast factor cube.** MakeHuman ships the breast macro as a cube over
`breastsize ∈ {mincup, averagecup, maxcup}` × `breastfirmness ∈ {minfirmness, averagefirmness,
maxfirmness}` × gender × age (verified token sets, `body-parameterization.md:218-219`). Import
these `.target` files into the sparse DetailLibrary with `kind:"macro"` (same as the universal
cube), via the existing `tools/body_proxy_build.gd`/converter import path. This is the same
operation that already produced the 188 universal/proportions macro targets — no new mechanism.
*(Unverified: exact count of breast-cube target files in the pin — the pinned store path isn't
realized in this shell; would `find …/data/targets/breast -name '*cup*'` to enumerate. The
mechanism is verified; the file inventory is not.)*

**4.2 Code — drive the breast cube from the macro modifier value.** Add a small generalization
to `to_blend_weights` that mirrors the headline factor-product loop but for *named* macro
modifiers:
- Split `masculinity`-style: a macro modifier value `v ∈ [0,1]` (default 0.5) splits into its
  anchor triple exactly like `_weight_vals`/`_muscle_vals` do — `maxcup = max(0, v*2-1)`,
  `mincup = max(0, 1-v*2)`, `averagecup = 1-(max+min)` — a verbatim reuse of the existing
  2×-split helper (factor it out as `_macro_triple(v)`).
- Extend `_decode_macro_factors` token sets with `breastsize`/`breastfirmness` (the tokens are
  already named in the design doc; add `BREASTSIZE_TOKENS`/`BREASTFIRMNESS_TOKENS` consts).
- In the macro loop (`body_state.gd:488-491`), `_universal_target_weight` already multiplies
  the product by any decoded factor — extend it to also read `breastsize`/`breastfirmness`
  factors from the breast-modifier triples. So a breast-cube target's weight =
  `gender × age × cup × firmness` factor product. Composes correctly with build/age (a
  large-cup target on a young female ≠ on an old male) — the same product semantics as the
  universal cube.
- The macro value source: `BodyState` gains two natural fields — `breast_size` (0–100, a real
  "small↔large" axis, default 50) and `breast_firmness` (0–100, default 50) — that map to the
  `breast/BreastSize`/`breast/BreastFirmness` macro values `v = field/100`. These become the
  Tier-2 Breasts group's headline pair, replacing the directional-only `breast-volume`
  *as the primary size control* (the directional targets stay as fine-shape modifiers:
  spacing, projection, height, nipple — they layer ON TOP of the macro cube, which is exactly
  the MakeHuman model).

**Result:** a real "breast size" slider that drives the proper factor cube and reads as cup
size, composing with build/age/weight — and the same pattern generalizes to any future macro
modifier. The dead path becomes a first-class, semantically-correct control.

**One caution (frame-relevant):** the macro breast cube and the directional breast targets BOTH
touch the chest verts, so they overlap — this is precisely a §3 envelope region. The breast
region budget must include the macro size axis. So the macro fix and the bounds mechanism are
coupled by design: importing the cube without adding it to the envelope would reintroduce
unbounded stacking. (This coupling is called out in the quality bar.)

---

## 5. Visual fidelity — eyes, eyebrows, skin (grounded, technique-named)

This is the hard part; I separate **what HEAD already fixed** from **what remains**, and grade
each remaining item by achievability against the actual assets.

### 5.1 Skin — the dominant win, and it just became achievable

Diagnosis #3 said the plastic look is "missing normal map + bare material + no tangents, NOT
tessellation." **Tangents now exist (§0, verified `body_converter.gd:219-281`).** So the
blocker is gone and the plan is:

1. **Albedo + roughness variation, not flat color.** Replace the bare
   `StandardMaterial3D(albedo, roughness)` (`body_rig.gd:359-361`) with a skin material that
   has at minimum a **roughness map** (skin is not uniform 0.7 — T-zone vs cheeks vary) and an
   **albedo map** with subdermal hue variation. Source options, in preference order:
   (a) **a CC0/CC-BY human skin texture set** (e.g. texturing.xyz-style or Poly Haven CC0 skin
   — *would verify license + UV compatibility with the MH UV layout*); (b) **procedurally
   generated** roughness/detail-normal from a noise+pore tiling shader if no licensed map fits
   the MH UVs. MH base UVs exist (`21334 vt`), so a MH-authored skin texture maps directly —
   **MakeHuman ships a default skin** in `data/skins/` (the pin's `young_lightskinned_*`
   set), which is **CC0-compatible base content**. *(Unverified: I could not realize the pin's
   store path in this shell to confirm the skin PNGs and their license header — would
   `find …/data/skins -iname '*.png'` and read the license. This is the single biggest
   achievability dependency; flagged loudly.)*
2. **A subtle tiling detail-normal map** for pores/micro-wrinkles, applied via the detail-
   normal slot (now that `ARRAY_TANGENT` is present and blendshape tangent deltas are zeroed to
   match format — so the detail normal survives morphs). This is the single highest-leverage
   change for "reads as skin not plastic" and is fully achievable today (a tiling CC0 skin
   detail-normal is trivially sourced).
3. **Subsurface scattering**: Godot 4 `StandardMaterial3D` has a `subsurf_scatter_enabled`
   slot; enable it low (skin is translucent at the ears/nose). Achievable, no asset needed.
4. **Skin tone as a player axis**: an albedo *tint* over the (textured) base, exposed as a
   creation control. Cheap, additive, deterministic.

Achievability: **high** for detail-normal + roughness + SSS + tint (engine features + trivially
sourced tiling maps). **Medium, dependency-gated** for a full MH albedo skin set — depends on
the unverified `data/skins` license/availability. Mitigation: ship the procedural/detail-normal
path first (guaranteed), add the albedo set when verified.

### 5.2 Eyes — fix seating first (data), then tessellation

Two compounding causes (body-visual-reverify #2). In priority order:

1. **Seating (root cause #1, the dominant defect): a DATA fix, achievable now.** Rebuild
   `base_body_proxies_detail.index.json` so the eye/teeth/tongue/brow proxies carry the SAME
   macro target set the body emits (the 188 universal/proportions targets), via the existing
   proxy build tool against the correct macro set. The proxies then follow the skull morph
   through `ProxyMorph.apply` (the code path is correct — `proxy_morph.gd:82,108-127`; only the
   data is wrong). **This alone makes the eyes sit in the sockets at all genders.** Achievable
   with the existing tooling; the only work is rebaking against the right target list.
2. **Tessellation: the analytic shader quantizes on the 96-vert (~48/eye) ball.** Two
   sub-options:
   - (a) **Increase eyeball proxy resolution** to a clean UV-sphere (~200–400 verts/eye). The
     shader keys off the model-space NORMAL (`eye.gdshader:55-65`), so a denser sphere gives
     smooth interpolated normals → the analytic iris/pupil rings stop faceting. Low cost (a few
     hundred verts), high payoff. Requires authoring/swapping the eye proxy mesh —
     *would verify the proxy mesh is independently replaceable without re-baking the whole
     multi-surface proxy*.
   - (b) Keep the low-poly ball but make the shader robust at low tessellation by computing the
     gaze-cap analytically in a way that doesn't depend on per-fragment normal precision — but
     the normal IS the only per-fragment signal, so (a) is the honest fix. **Decided: (a).**
   - Also fix the **fixed `gaze_dir = +Z` constant** (`eye.gdshader:22`): after the eyeball is
     seated/rotated by the rig, model `+Z` may not be the geometric forward, so the iris cap
     can sit off-front. Drive `gaze_dir` from the eye bone's actual forward (a uniform set per
     eye at build) so the iris always faces front. Cheap, removes the "iris off to the side"
     artifact.

Achievability: **high** for seating (pure rebake) and gaze-dir (uniform); **high** for denser
eyeball IF the proxy mesh is independently swappable (unverified — the one open question here).
The analytic shader is otherwise good (resolution-independent iris/limbal/pupil, slit-pupil
support for non-human eyes — a real asset for this game's transformation scope).

### 5.3 Eyebrows / eyelashes — replace the 32-vert cards

They are project-authored proxy surfaces (32 verts each), rendered as flat two-sided dark
cards, and (like eyes) don't follow the morph (body-visual-reverify #2). Two fixes:
1. **Seating: same proxy-rebake as §5.2.1** — once the proxy detail library carries the right
   macro set, the brows track the brow ridge. This stops the "floating dark slashes" failure.
2. **Asset quality: the 32-vert flat card is the ceiling.** Decided approach, in order of
   achievability:
   - **(near-term, achievable now) a brow/lash TEXTURE on the existing card** — an alpha-masked
     hair-strand texture (CC0 sourced or generated) with `cull_disabled` already set
     (`body_rig.gd:912-919`), so the card reads as soft strands not a solid slab. This is the
     cheapest large quality jump and needs no new geometry. (No normal map needed for thin
     strands; alpha + albedo carries it.)
   - **(later, want) replace the card with a denser strip or curve-based brow** in the part
     library (`part_library.gd` already manages swappable parts). Higher fidelity, more work,
     not required for the quality bar.

Achievability: **high** for seating + alpha-strand texture (the realistic near-term target);
denser geometry is a *want*.

### 5.4 Extremities (hands/feet) faceting — acknowledged want, not in scope

Lower MH base density genuinely facets hands/feet (body-render #4). Out of scope for this pass;
flagged. A detail-normal (§5.1.2) partially masks it.

---

## 6. Camera / UX, state persistence, VR

### 6.1 Camera
- **Default view: front (face + chest) on open.** `_yaw` is now `0.0` (`character_creator.gd:42`)
  which by the in-comment math should be the front; **must confirm with a render** (the
  diagnosis explicitly warned the comments and the render disagreed, so do not trust the
  comment — `xvfb-run` a capture, item in quality bar §7).
- **Region-aware framing**: selecting/opening a region group dollies the camera to that region
  (the registry has a `camera` field per modifier — `modifier_registry.gd:332`; reuse it). Edit
  the breasts → camera frames the torso. This is part of "predictable": you always see what
  you're editing.
- Orbit/zoom stay (`character_creator.gd:654-665`), clamped pitch so you can't go under the
  floor or inside the head (eye_height/head_top are correct, body-render confirmed).

### 6.2 State persistence — the high-impact fix (creator-ux #7)
- **Autosave the full `BodyState` + the `HistoryTree` to `user://creator/current.json`** on
  every committed edit (debounced) and on `_exit_tree` / `NOTIFICATION_WM_CLOSE_REQUEST`;
  restore on `_ready`. `CreatorIO` already has `history_to_json`/`embed_history_in_image` for
  the write side (`creator_io.gd`) — the missing piece is the read-back + the autosave trigger,
  not new serialization.
- **A real IMPORT action** (load an exported JSON/PNG back into the creator) — the read path
  exists in `CreatorIO` but is never called from the scene; wire it.
- **Save format carries the envelope content-hash (§3)** so a save made under an older envelope
  is re-validated and visibly snapped on load — never silently out-of-envelope.
- Export UI collapse (creator-ux secondary): {JSON | image} toggle + "include history"
  checkbox + one Export button, replacing the 2×2 four-button stack. Show the written path.
- **Load freeze (creator-ux #8)**: show a loading indicator immediately, defer the heavy
  builders off the first frame; the picker grid is already lazy and need not block open.

### 6.3 VR story for parametric editing
The frame is *natural* for VR because it's bounded controls, not precision sculpting.
- **A floating panel** (the same Tier-1/Tier-2 tree) on the non-dominant hand / wrist; the
  dominant hand ray-points and pinch-drags sliders. SpinBox numeric entry degrades to
  +/- steppers + a radial number wheel in VR (typing is bad in VR; the bounded ranges make
  steppers sufficient).
- **Grab-to-sculpt is excellent in VR** and stays bounded: reach out, grab the body region,
  pull — it drives the same clamped modifiers (§1.6), so even a big VR hand-sweep cannot exceed
  the envelope. The physical resistance at the envelope boundary reads naturally in VR.
- **A mirror** (VRChat-style) in the creator space so you can see your own face while editing —
  cheap (a second viewport) and a large immersion win.
- Cross-platform parity: the SAME bound model drives flat (KB+M/gamepad), PCVR, and Quest; only
  the input mapping differs. No VR-specific editing semantics — that's the parity win of a
  bounded-control frame over a precision-sculpt frame.

---

## 7. Concrete, testable quality bar

Each item is a pass/fail check, runnable under `nix run .#test` / `xvfb-run godot4` renders.
Numbers are the acceptance thresholds.

**Bounds (the frame's core promise):**
1. **No-monster property test (automated, deterministic):** for N=10,000 seeded random axis
   vectors drawn from the FULL legal range, after morph+envelope, assert (a) every base
   vertex's total displacement ≤ `D_max(region)`; (b) no triangle's area shrinks below ε or
   inverts (no self-intersection proxy); (c) the body AABB stays within sane human bounds
   (height within §3 clamp, width < k×height). Zero failures required. This is the literal
   "you cannot build a broken body" assertion.
2. **Envelope legibility test:** for each region budget, drive one axis to its cap, then assert
   a sibling axis's effective max has *visibly* shrunk (handle range reduced), and that numeric
   entry past the cap snaps to the cap. Verifies the bound is legible, not silent.
3. **Order-independence:** raising axis A then B yields the same final feasible state as B then
   A (envelope is symmetric). Byte-identical morph output.

**Macro semantics:**
4. **Breast-size drives the cube:** sweeping `breast_size` 0→100 monotonically increases chest
   volume (measured by chest-region AABB) at constant build; AND a fixed `breast_size` composes
   correctly across age/build (the cube product, not a flat add). The previously-dead path
   produces nonzero, monotone morph. Regression test that the macro modifier is no longer
   skipped.
5. **Breast macro is inside the envelope:** the macro size axis participates in the breast
   region budget (test #1 includes it). No unbounded stacking of macro + directional breast.

**Visual fidelity (render-asserted under xvfb):**
6. **Eyes seated at ALL genders:** render face at masc 0/50/100; assert the eye proxy centroid
   is within the eye-socket AABB at every gender (currently fails at 0/50 — body-visual-reverify
   #1). This is the single highest-value render check.
7. **No iris faceting:** at the denser eyeball, the rendered iris boundary is smooth (a
   circularity metric on the iris/sclera edge > threshold). Iris is centered on the visible
   front (gaze-dir fix).
8. **Skin not flat:** the lit body shows roughness/normal variation — quantitatively, the
   variance of screen-space luminance over the cheek region exceeds the current flat-material
   baseline by a set factor (proves the detail-normal/roughness map is active).
9. **No seam two-tone:** re-render `head_back` and the inner-leg seam; assert no luminance
   discontinuity along the UV-island edges (should already pass post-`5c33ca5` — this is the
   regression lock for the already-landed fix).
10. **Eyebrows read as brows, not slabs:** the brow card with the strand texture has alpha
    break-up (not a solid filled rectangle in the alpha channel) and sits on the brow ridge.

**UX:**
11. **Default view shows the face** (front), confirmed by a render + a face-detection / non-back
    heuristic (hair-down-the-back absent).
12. **Round-trip persistence:** set a non-default BodyState, trigger autosave, new BodyState,
    restore — assert byte-identical `to_blend_weights()`. And quit→relaunch restores the same
    body.
13. **Numeric == slider:** typing a value and dragging to the same value produce identical
    BodyState; typing out-of-range snaps to the clamp.

**Determinism (project invariant):**
14. Randomize with a fixed seed reproduces an identical body; the roll is in the action log;
    replay of the log reconstructs the exact creation.

---

## 8. Least-sure spots (flagged, would verify)

1. **MakeHuman `data/skins` availability + license (§5.1).** The single biggest fidelity
   dependency. The pin's store path was not realizable in this shell, so I could not confirm
   the default skin PNGs exist/are CC0-headed or that their UVs match our imported base.
   Mitigation: the procedural detail-normal + roughness + SSS path is independently achievable
   and gives most of the win; the albedo skin set is the upgrade. Would
   `find …makehuman…/data/skins -iname '*.png'` + read a license header.
2. **Eyeball proxy independent replaceability (§5.2.2a).** The eyes are one surface inside a
   shared multi-surface proxy mesh (`base_body_proxies.res`). Swapping just the eyeball for a
   denser UV-sphere may require re-baking the whole proxy + re-mapping ProxyMorph indices.
   Would inspect `tools/body_proxy_build.gd` to confirm per-surface swap is supported. If not,
   the denser-eye fix costs more than stated (the seating rebake is unaffected — that's a pure
   data rebake and remains high-confidence).
3. **Envelope budget tuning (§3).** The region-budget numbers (e.g. midsection budget 2.4) are
   placeholders; the *mechanism* is sound but the *thresholds* need empirical tuning against
   rendered extremes (the quality-bar #1 property test is the tuning harness). Risk: too tight
   feels restrictive (player can't make the heavy/curvy body they want), too loose lets
   faceting through. This is a tuning loop, not a design unknown — but it is the spot most
   likely to need iteration after first implementation.
