# Creator + Body — design pass, ARCHETYPE + PROGRESSIVE-REFINE frame

Status: **DESIGN CANDIDATE** (one frame of a design-it-twice; not the synthesized winner).
Date: 2026-06-23. No feature code — design artifact only.

**Frame (the constraint this candidate optimizes):** subtract the wall of sliders. The
common path is *pick an archetype, then nudge to taste*. You always start from something
that already looks good and is already valid. Deep control exists but is revealed on demand,
not in your face. The slider grid (56 region sliders, `region_sliders.gd:GROUPS`) and the
drag-sculpt path (`morph_drag.gd`, body-parameterization.md §9b) are **kept** but demoted to
Tier 3 — they are the floor of control, not the entry point.

Everything factual below is grounded in the verified diagnosis set
(`docs/artifacts/diagnosis/*.md`) and the decided parameterization
(`docs/decisions/body-parameterization.md`, "§N" refers to that file). Achievability claims
cite a file:line / asset, or are flagged **unverified — would check X**.

---

## 0. What the ground truth gives us (so the design doesn't reinvent it)

Already decided and (mostly) built — this candidate builds ON these, does not redo them:

- **`BodyState` is a sparse, serializable record** (§3): headline natural-unit axes
  (`age_years`, `height_cm`, `masculinity` 0–100, `muscle`, `weight`, `proportions`) + a
  sparse `modifiers: {fullName → value}` map. Absent key = neutral. This is the substrate an
  archetype must be expressed in (data-over-code: an archetype is just a `BodyState`, §1.1).
- **`to_blend_weights()` is pure & deterministic** (`body_state.gd:471`): macro factor-cube
  product (§1.3) + sparse registry projection (`_project_modifiers`). Same record → same mesh.
- **The modifier registry is data** (`assets/body/modifier_registry.json`, §6): every detail
  axis carries `kind` (bidirectional/unipolar/macro), `range`, `tab`, `slider_group`, `label`.
  A UI tier system can be a *projection* of this registry, not a hand-authored panel.
- **Drag-sculpt + region sliders both write the same `modifiers` map** and share one
  `HistoryTree` (§9b). Any archetype/nudge operation must commit to that same history so undo
  is uniform.
- **The gate is `is_adult_body()` = `age_years >= 18.0`** (§5), single source of truth,
  fail-closed. Morphs are never gated; the verb×body intersection is. This candidate does not
  touch the gate predicate.

Verified defects this candidate must address (not invent fixes for — these are real):

- **D1 — proxies (eyes/teeth/tongue/brows/lashes) only seated at masc=100**
  (`body-visual-reverify.md` §1, confidence high). The proxy delta library was baked against a
  near-disjoint macro target set vs what the body emits, so at neutral/feminine the eyeballs
  ride up to the brows and teeth/tongue protrude by the nose. **This breaks every archetype
  that isn't fully masculine** → it is a blocking prerequisite for archetypes, addressed in §5.
- **D2 — `breast/BreastSize` macro has no driving path** (verified here: the `*cup*` targets in
  `base_body_detail.index.json` are all `mouth/…-cupidsbow-…`; there is NO
  `…-mincup/averagecup/maxcup` breast cube imported; `_decode_macro_factors` has no breastsize
  token set; `_universal_target_weight` has no breastsize factor; `_project_modifiers` skips
  `kind==macro`). So the registered `breast/BreastSize` modifier drives literally nothing.
  Today "size" in the UI is silently aliased to `breast/breast-volume-vert-down|up`
  (`region_sliders.gd:42`) — a bidirectional *shape* axis, not the cup-size macro. Addressed §4.
- **D3 — unbounded morph stacking** (`body-reverify.md` §2, confidence high): per-modifier
  value is clamped, but composed displacement is summed with no cumulative bound
  (`detail_library.gd:104`). Overlapping regions (bust+volume+belly+waist+hips) sum into
  angular monstrosities at the extremes (`body-reverify.md` §4). This is *the* reason a naive
  "free sliders" creator can't guarantee a good result → bounds design, §3.
- **D4 — no persistence, no preset/archetype/randomize anything** (`creator-ux.md` §7; grep
  here: zero `preset|archetype|randomize` in `character_creator.gd`). State lost on
  scene-switch/restart. The archetype system *is* the first content that needs persisting.
- **D5 — visual fidelity floor**: bare `StandardMaterial3D`, albedo+roughness only, no normal
  map, no tangents, no AO/SSS (`body-visual-reverify.md` §3); UV-seam one-sided normals produce
  shading creases (§4); 96-vert eyes with a normal-keyed analytic shader quantize into blocky
  irises (§2); 32-vert brow cards read as floating dark slashes. Addressed §5.
- **D6 — default camera shows the BACK of the head** (`creator-ux.md` §1); ~1s synchronous load
  freeze (§8). Addressed §6.

---

## 1. The archetype/preset system

### 1.1 An archetype IS a `BodyState` (decided)

An archetype is a **named, frozen `BodyState`** — the full record: the six headline axes plus a
curated `modifiers` map — shipped as a small data file (`assets/body/archetypes/*.json`,
serialized by the existing `BodyState.to_dict`/`from_dict`, §8). **Not** a macro point (a macro
point can't carry the detail-envelope shaping — brow, nose, jaw, breast-shape — that makes an
archetype *look authored* rather than *parametrically averaged*). **Not** a closure or a build
script (data-over-code at a faithful seam, CLAUDE.md: a `BodyState` is exactly the faithful
serialization, it caches/diffs/replays for free, and it is already the determinism substrate).

Concretely an archetype file is:

```json
{ "id": "athletic-fem", "label": "Athletic", "family": "feminine",
  "thumb": "athletic-fem.webp",
  "state": { "age_years": 24, "height_cm": 168, "masculinity": 22, "muscle": 68,
             "weight": 96, "proportions": 0.15,
             "modifiers": { "breast/BreastSize": 0.45, "torso/torso-vshape-decr|incr": 0.3,
                            "stomach/stomach-tone-decr|incr": 0.5, "nose/nose-scale-vert-decr|incr": -0.1,
                            "head/head-oval": 0.4, ... } },
  "envelope": { "max_delta": 0.35 } }   // see §3
```

This makes archetypes **authorable by anyone** (sculpt a body in the creator → "Save as
archetype" exports the current `BodyState` + a captured thumbnail), and it makes the *shipped*
set just the first-party seed of an open, moddable library — the same library-first /
projection-from-one-definition posture as the registry (§6).

### 1.2 The axes of the archetype space (how many, what)

The archetype *grid* the player browses is organized on **two visible axes + filters**, not on
the raw morph axes:

- **Family (the primary pick):** `feminine | androgynous | masculine`. This is the masculinity
  axis quantized into three readable bins — it is the single biggest perceptual fork and the one
  players reach for first. (Three, not a continuum, because the *pick* should be a glance, and
  masculinity stays a continuous nudge afterward.)
- **Build (the secondary pick within a family):** a small named set — `slim | average |
  athletic | curvy | heavy | muscular`. These span the muscle×weight×proportions region with
  hand-authored detail shaping, not just macro points.

That is a **3 × ~6 = ~18 first-party archetypes** as the shipped seed (a few builds won't make
sense in every family; ship the ones that read well, ~15–18 total). **Deliberately not 100.** A
small, hand-curated, individually-good set beats a large auto-generated grid — the whole point of
the frame is "always start from something good," and good is *authored*, not sampled. The long
tail is served by (a) randomize-within-validity (§1.4) and (b) the open archetype library (1.1).

Filters layered on top (cheap, since archetypes are data): age band, height band — these
re-query the same set, they are not new archetypes.

### 1.3 Blend / nudge from an archetype

Two operations, both producing a new `BodyState` deterministically:

1. **Nudge (the common path).** After picking, the six headline axes show as labeled sliders in
   natural units ("Age 24 yr", "Height 168 cm", "Masculine 22"). Dragging one moves *only* that
   axis. This is the 90% interaction: pick + a couple of axis nudges. Headline axes are
   *un-bounded* relative to the archetype (you can take any archetype to any age/height) — they
   are macro and well-behaved by construction (the factor-cube is continuous, §1.3 of the
   decision; the height scale is uniform, §4). Only the *detail* `modifiers` are envelope-bounded
   (§3), because those are what stack into monstrosities (D3).

2. **Blend between two archetypes (Tier 2, optional).** A single "morph toward another
   archetype" control: pick a second archetype, get a 0–1 slider. The result is a per-field lerp
   of the two `BodyState`s: headline axes lerp numerically; the `modifiers` maps lerp key-by-key
   (absent key = 0 on that side). Because both endpoints are valid and the lerp of two valid
   states stays inside the convex hull of valid detail values, the blend is **valid for free** —
   no extra clamping needed beyond the per-field range. This gives "between athletic and curvy"
   without exposing the morph grid. Deterministic, commits one history node.

A nudge or blend **commits one `HistoryTree` node** labeled by the operation ("archetype:
Athletic", "nudge: height 168→172", "blend: Athletic↔Curvy 0.4") so undo/redo/branch is uniform
with sculpt+sliders (§9b).

### 1.4 Randomize-within-validity

"Surprise me" must *never* produce a monstrosity (the failure mode of every slider-randomizer).
Decided mechanism — **randomize is a bounded walk from a seed archetype, not a uniform sample of
axis space**:

1. Pick (or keep) a seed archetype A → start from `A.state`.
2. Sample each **headline** axis from a *narrow, plausible* distribution centered on A's value
   (e.g. age ±6 yr clamped to a sane adult band, height from a sex-appropriate Gaussian, muscle/
   weight ±15 of A, masculinity ±12 within A's family). These are macro and safe.
3. For **detail** modifiers: perturb each existing key by a small N(0, σ) and *optionally* add a
   few new keys drawn only from a **safe-to-randomize allow-list** (face shape, nose, jaw, brow,
   breast-size, hip/waist *within* the envelope) — never the gross placement/measure axes, never
   two antagonistic axes at once. Every perturbed value is then run through the **§3 envelope
   clamp**, so the result is provably inside A's validity envelope.
4. Seeded: randomize takes the deterministic sim seed + a salt, so "the random I just got" is
   reproducible and shareable (consistent with the seeded-sim invariant, CLAUDE.md).

Result: randomize explores *around a good body*, bounded, and is reproducible. It cannot escape
the envelope, so it cannot make a monster — by construction, not by hope.

### 1.5 Progressive-disclosure tiers (what's coarse vs revealed on demand)

| Tier | Shown | Surface | Who it's for |
|---|---|---|---|
| **T0 — Pick** | the archetype grid (family → build), thumbnails, "Randomize", "Random within family" | first screen on open | everyone; the 70% who pick-and-go |
| **T1 — Headline nudge** | the 6 natural-unit axes as labeled sliders + "Blend toward…" | revealed automatically the moment an archetype is chosen (it's right there, not a click away) | the 90% case: pick + a few nudges |
| **T2 — Curated common detail** | ~12–16 *high-impact, low-footgun* detail sliders: breast size, face shape family (oval/round/square as one segmented control), jaw, nose size, hip/waist, brow, lip fullness — a hand-picked subset of the registry's `slider_group`s | one tap on "Refine" | players who want their own face |
| **T3 — Full control** | the complete categorized registry tree (the existing 56 region sliders + every other modifier, grouped by `tab`/`slider_group`, §6/§7) **and** drag-sculpt mode (`morph_drag.gd`) | one tap on "Advanced / Sculpt" | power users, archetype authors |

The disclosure is **monotone and additive**: opening T3 doesn't hide T1/T2, it adds a panel. The
existing slider grid is literally Tier 3 — nothing is thrown away, it is *relocated behind a
door*. T2 is the new authored layer; its slider list is a small curated array (a `const` of
fullNames), and each entry is just a projection of an existing registry entry (label, range, kind
all come from the registry — no duplication).

---

## 2. Editable-in-base-creation vs gated; pregnancy rule

**Rule (decided): the base creator edits a *persistent body identity*. Anything that is a
*transient bodily state* rather than a stable trait is OUT of base creation and lives only as a
runtime/live modifier (the VRChat-style live-toggle surface, DESIGN.md reference set).**

By this rule:

- **In base creation:** the six headline axes; all stable detail shaping (face, nose, jaw, brow,
  lips, ears, breast size/shape, hip/waist/glute shape, limb proportions, muscle/fat
  distribution, genital shape — geometry is anatomy, never gated, §5 of the decision). Skin tone.
- **OUT of base creation (transient state, not identity):**
  - **Pregnancy — OUT (decided).** `stomach/stomach-pregnant-decr|incr` is the MakeHuman
    pregnant-belly target (`body-reverify.md` §3). It is a *state*, not a creation-time trait.
    **Rename + relocate, don't delete:** keep it in the registry/Tier-3 as a generic
    `belly roundness` axis (it already is relabeled "belly: flat→round",
    `region_sliders.gd:57`) for body-type shaping, but a *pregnancy* concept proper is a runtime
    system (a transient `BodyState` overlay), never a base-creator slider labeled "pregnancy."
    This keeps the morph primitive uncrippled (you can still make a round belly) while not
    presenting "set your pregnancy" as an identity choice. Same posture as the gate: don't
    cripple the primitive, gate/relocate the *framing*.
  - Arousal/expression/transient inflation/etc. — same rule, runtime overlays, not base sliders.
- **Gating × archetypes:** archetypes are body *geometry*, so the **NSFW gate never interacts
  with archetype selection** — every archetype is selectable at any age the player sets. The gate
  is on the *verb×body intersection at runtime* (§5), entirely downstream of the creator. The one
  creator-side obligation: the age axis stays continuous and the `is_adult_body()` predicate is
  read live so any age-gated *preview verb* (none in base creation) would honor it. Archetypes do
  **not** carry a "this is an adult archetype" flag — that would duplicate the gate; age is just a
  field on the state and the single-source predicate evaluates it.

---

## 3. Bounds — keeping refinement from producing monstrosities

The core insight: **archetypes are valid by construction; refinement must stay near a valid
point.** Two complementary mechanisms, addressing the verified unbounded-stacking defect (D3):

### 3.1 Per-archetype validity envelope (bounded delta from the seed) — the primary mechanism

When you pick archetype A, A's `modifiers` map becomes the **center** of an envelope. Each
*detail* modifier the player edits is clamped to **`A_value ± max_delta`** (default
`max_delta ≈ 0.35`, overridable per-archetype in the file, §1.1), intersected with the
modifier's own registry range. So from "Athletic" (breast 0.45) you can roam breast 0.10–0.80,
not 0.0–1.0 — you stay in the neighborhood that reads as a refinement of *that* body, not an
escape into a different (possibly broken) region. Crossing the envelope edge is *possible* but
requires an explicit "expand range" gesture in Tier 3 (the power-user escape hatch — the envelope
is a guard rail, not a cage). Headline axes are **not** enveloped (they're macro-safe, §1.3).

The envelope is centered on the *archetype*, so it moves with archetype choice and is reset on
"blend" to the blended center. It is a pure clamp on the `modifiers` map — no new asset, computed
from the loaded archetype.

### 3.2 Cumulative displacement guard (the real fix for D3) — the safety net

The envelope bounds *per-axis* values, but D3 is *cumulative summed displacement* across
overlapping axes (`detail_library.gd:104` is pure accumulation). Decided mechanism — a
**per-region cumulative displacement soft-clamp in the bake**:

- During `bake_morphed_normals` (`body_state.gd:640`), accumulate, per render vertex, the total
  applied `|Δ|`. Where the summed displacement at a vertex exceeds a threshold (calibrated to the
  local edge length so it's tessellation-aware — the monstrosities are where displacement
  outruns what the coarse mesh can represent, `body-reverify.md` §4), apply a **soft
  compression** (tanh-style) to the *combined* delta rather than letting it sum linearly. This
  bounds the silhouette to what the mesh can smoothly represent.
- This is a **bake-time invariant, not a UI clamp** — it protects *every* path (sliders, sculpt,
  archetypes, randomize, blend, and any future runtime overlay), so it's the honest place for the
  guarantee. It's the one piece of this candidate that touches the morph math; it should ship as
  its own slice with golden tests (extreme-stack render stays smooth, moderate render
  byte-unchanged).

**Unverified — would check:** the exact threshold curve needs calibration against renders at the
`belly_extreme`/`thigh_extreme` cases in `/tmp/geom-check/` (`body-reverify.md` §4). I have not
measured the per-vertex summed-Δ at which faceting begins; that's an empirical sweep, flagged.

Together: 3.1 keeps you near a good body (common-path guarantee), 3.2 guarantees no monster even
if you defeat 3.1 in Tier 3 (substrate guarantee).

---

## 4. Correct semantics — a real working "breast size" (the D2 fix)

**The defect (verified above):** `breast/BreastSize` is a registered *macro* modifier
(`modifier_registry.json:248`) whose factor cube (`…-mincup/averagecup/maxcup`) was never
imported into `base_body_detail.index.json`, and which `_project_modifiers` skips (kind==macro)
while `_universal_target_weight` has no breastsize factor. So it drives nothing. The UI's "size"
slider is silently aliased to `breast/breast-volume-vert-down|up` — a *shape* axis, not cup size.

**Decided fix — wire BreastSize into the macro factor-product path, the same way the other macro
cubes already work** (§1.3 is the proven mechanism; this just extends it):

1. **Import the breast cup cube** at build time (`tools/body_converter.gd` registry-driven
   import, §8): the MakeHuman `data/targets/breast/` cube is named on the
   `gender×age×{mincup,averagecup,maxcup}×{firmness}` factor tuple (per §1.3 `_cat_data` —
   `breastsize` and `breastfirmness` are *defined categories* in MakeHuman's own
   `lib/targets.py`). These targets are CC0 core (§1.1). Import them into the detail library as
   macro-cube targets keyed by file path, exactly like the muscle/weight/race cubes.
   **Unverified — would check:** the exact filenames of the breast cube in the pinned v1.3.0 tree
   (`data/targets/breast/*cup*.target`) and how many there are; the decision (§1.3) verifies the
   *category tokens* exist but I have not listed the breast cube files. Would run
   `find …/data/targets/breast -name '*cup*'` against the realized store path.
2. **Add the breastsize (and breastfirmness) factor to the product.** Add `BREASTSIZE_TOKENS :=
   ["mincup","averagecup","maxcup"]` to `_decode_macro_factors`, a `_breastsize_vals()` splitter
   (the same {min,avg,max} 2×-split-about-midpoint pattern as `_weight_vals`, §1.3), and a
   `bv`/`fv` factor in `_universal_target_weight`. Then `breast/BreastSize` is driven by the
   *headline path*, not `_project_modifiers`.
3. **Promote BreastSize to a first-class control** in T2 (it's high-impact, low-footgun): a
   natural-ish "Breast size" slider 0–1 (optionally labeled with approximate cup letters as a
   *display hint only* — A/B/C/D mapped to value bands, since MakeHuman has no real cup metric,
   parallel to height-cm being emergent, §1.4). The fine breast *shape* axes (volume-vert, dist,
   point, trans, nipple — all present in the lib) stay in T3 under "Breasts." So: T2 = "how big,"
   T3 = "exact shape." The current alias (`region_sliders.gd:42` "size" → volume-vert) is
   **retired** (retire-don't-deprecate): "size" becomes the real macro; volume-vert is relabeled
   "fullness/shape" in T3.

This is the model for any other dead macro: the fix is always "import the cube + add the factor
token + drive via the product," never a special-case in `_project_modifiers`. Collapses the
asymmetry (D2) to the existing primitive.

---

## 5. Visual fidelity (the hard part) — techniques, asset sources, achievability

The frame's promise ("always start from something good") is a lie if the rendered body looks
broken. The verified diagnosis says the perceived "low-poly/plastic/broken-face" is **not mesh
density** — the mesh is full MH topology, 14.5k render verts (`body-render.md` #4). It is four
specific, fixable things. Each below names the technique, the asset source, what I verified, and
flags unknowns. **No hand-waving.**

### 5.1 Eyes — the dominant face defect

Two compounding causes (`body-visual-reverify.md` §2, confidence high/medium-high):
**(a) seating** — at neutral/feminine the 96-vert eyeball proxy rides up to the brows because the
proxy delta library doesn't follow the macro morph (D1, §5.5 below — this is the *blocking*
fix); **(b) the shader** — `assets/body/eye.gdshader` keys the iris off the model-space NORMAL
(`:55-65`), so at ~48 verts/eye the interpolated normal is coarse and the concentric iris/pupil
rings (`:91-101`) quantize into a faceted blob; `gaze_dir` is a fixed model `+Z` (`:22`) which
may not equal the seated forward.

Decided techniques:

- **Fix seating first (D1, §5.5).** This alone makes the eye read as an eye in its socket.
- **Make the eye shader robust at low tessellation** without re-importing geometry: drive the
  iris from a **per-eye UV-island-centered radial coordinate** (the eyes have their own UVs,
  §11 of the decision says the *original* design computed iris from UVs — the current shader
  regressed to normals). UV radius is a smooth interpolant across the 48-vert ball where the
  normal is not — so the iris becomes a smooth circle regardless of vert count. This is the
  technique the decision doc already endorsed; the shader regressed away from it.
- **Drive `gaze_dir` from the rig** (the `eye.L/eye.R` bone forward, `body_rig.gd` already seats
  these) instead of a model-space constant, so the iris always faces front after seating.
- **A small spec highlight is good** (the wet eye) — keep `eye_roughness 0.06` but only once the
  ball is correctly seated and the iris is smooth; on a broken ball it reads as a grey card.

**Verified:** the shader keys off NORMAL not UV (`eye.gdshader:55-65`, re-verified in
body-visual-reverify §2). **Unverified — would check:** that the eye proxy UVs are actually a
clean per-eye island suitable for radial mapping (the decision §11 claims they are; I'd render the
`eyes` surface with a UV-debug material to confirm before committing to the UV approach). If the
UVs are not clean, fallback is a denser eyeball proxy — but the decision's CC0 source is the
96-vert low-poly eye, so a denser eye would need a different CC0 asset or a generated UV sphere
(flagged as the riskier branch).

### 5.2 Eyebrows + eyelashes

They are **project-authored 32-vert proxy ribbons** (`body-visual-reverify.md` §2; decision §11.1
— no CC0 brow mesh exists in pinned MH core, so they were authored in-repo). At 32 verts and not
following the morph (D1) they read as floating dark slashes.

Decided: (a) seating fix (D1) reseats them onto the brow ridge; (b) **render them as
alpha-textured hair-card ribbons, not opaque matte cards** — author a small **CC0 brow-hair
strip alpha texture** (a few rows of tapered hair strokes, paintable in-repo, no external asset
dependency = no license risk) and apply it with `cull_disabled` + alpha-scissor. A textured card
reads as eyebrow hair; a 32-vert opaque ribbon never will, regardless of vert count. The decision
§11.1 already flags "refinable later with a proper hair-card texture" — this candidate makes that
the actual fix, not a someday. Same approach for lashes (sparser, finer strokes).

**Unverified — would check:** that alpha-blend/scissor over the cull-disabled thin cards doesn't
introduce sort artifacts at grazing angles (would render a 3/4 face after applying). Flag.

### 5.3 Skin — the "plastic" look

Verified root: bare `StandardMaterial3D`, albedo+roughness only, **no normal map, no tangents,
no AO/SSS** (`body-visual-reverify.md` §3). The decisive flat-ambient test proves it's shading,
not geometry. Decided techniques, in achievability order:

1. **Generate tangents** (`body_converter.gd` writes no `ARRAY_TANGENT`, §3) — prerequisite for
   any normal/detail map. Cheap, deterministic, done in the converter. **Must ship first** or
   the normal map below does nothing.
2. **A CC0 skin normal + roughness + (light) AO map.** Source: a **CC0 human-skin PBR set**
   (e.g. the CC0 skin scans on ambientCG/Poly Haven-class libraries, or a tileable CC0 skin-pore
   detail-normal). Applied as a **detail-normal** (tiled pore/micro-wrinkle) blended over the
   base — this is what kills the plastic look at any lighting angle. Roughness map breaks the
   uniform-roughness sheen. **Unverified — would check:** whether the MH base UV layout has the
   resolution/seam behavior to carry a body-wide normal map cleanly, and licensing of the
   specific chosen map (must be genuinely CC0 — the decision is strict about this, §1.1/§11.1).
   The *technique* is standard PBR; the *specific asset* is the unverified part. Flag clearly.
3. **Subsurface scattering** (`StandardMaterial3D` has `subsurf_scatter_enabled`): a low SSS with
   a warm tint gives skin its translucent reads (ear rims, nostrils). Cheap, built into Godot 4.6
   StandardMaterial3D — no custom shader needed. **Verified** the property exists in Godot 4.x
   StandardMaterial3D; would confirm the exact name in 4.6.
4. **Fix the UV-seam normal creases (D5):** the converter accumulates normals per render vertex,
   not per base vertex, so UV-seam splits get one-sided normals (`body-visual-reverify.md` §4,
   confidence high, exact fix given there: accumulate per base vertex via the existing
   `render_to_base` weld, scatter back). This is a pure converter fix with a known mechanism — it
   removes the back-of-head and inner-leg shading creases. High-value, low-risk.

### 5.4 The default hair cap (the #1 face-obscurer)

`body-render.md` #1: the default CC0 "helper hair" is a long-hair *guide* mesh rendered as opaque
black slabs to the chest, ON by default, covering the whole face. Decided: **default to bald**
(or to a real fitted short scalp cap if one is authored), and the helper-hair guide mesh is
**never** a default. Archetypes can name a default hairstyle in their `modifiers`/parts, but the
fallback is no-hair, not the guide mesh. This is a one-line default-visibility change
(`PROXY_DEFAULT_HIDDEN`, `body_rig.gd:64`) plus archetype-driven part selection. Trivial, huge
perceptual win.

### 5.5 D1 — proxy morph-follow (the blocking prerequisite for archetypes)

`body-visual-reverify.md` §1 (confidence high): the proxy delta library
(`base_body_proxies_detail.index.json`, 8 targets) was baked against a near-disjoint macro target
set vs what the body emits (`base_body_detail.index.json`, 188 macro targets) — intersection ≈0 —
so eyes/teeth/tongue/brows/lashes don't follow the gender/age morph and only line up at masc=100.
**Without this fix, every non-masculine archetype renders with displaced eyes** → it gates the
whole archetype frame.

Decided: **rebake the proxy delta library against the body's actual emitted macro target set**
(`tools/body_proxy_build.gd`) — push each base vertex's full macro-cube `.target` delta through
the `.mhclo` binding for the *same* target names the body's `to_blend_weights()` emits (the
decision §11 describes exactly this binding path; the data was just built against the wrong target
list). This is a **data rebake, not a code change** — the runtime `ProxyMorph.apply` path is
correct (`body-render.md` PIPELINE-OK). The defect is in the baked asset.

**Verified:** the byte-identical-render proof and coverage table in body-visual-reverify §1 pin
this as a data mismatch, high confidence. **Unverified — would check:** that
`tools/body_proxy_build.gd` can enumerate the body's full emitted macro set (188 targets) and
that rebaking against all of them stays within a reasonable proxy-library size; would run the
rebuild and re-render at masc 0/50/100 (the existing diagnostic harness).

---

## 6. Camera / UX, persistence, VR

### 6.1 Camera

- **Default to the FRONT, framed on the face** (fixes D6: `creator-ux.md` #1 — default currently
  shows the back of the head). Set `_yaw` so the camera sits in front of the body's -Z facing,
  **verified against a render** (the decision's two comments disagree, so this must be a
  render-checked value, not a blind flip). On open, frame the face (the first thing a player
  judges an archetype by), then a gentle pull-back to full body after ~1s or on first input.
- **Context-aware camera per tier:** picking an archetype frames full body; opening face-detail
  (T2/T3 face groups) auto-frames the face (the registry carries a `camera`/`cam` hint per
  slider, §7 of the decision — use it). The `*_sliders.json` `cameraView` is data; the camera is
  a projection of it.
- **Async load** (fixes D6 freeze, `creator-ux.md` #8): show the archetype grid *first* (cheap —
  it's thumbnails over data), build the live `BodyRig`/accel/picker off the first frame via
  `call_deferred`/thread. The grid is interactive while the body builds; the body appears when
  the player picks. This turns the 1s freeze into "browse while it loads" — and the archetype-
  first flow makes that natural rather than a workaround.

### 6.2 Persistence (fixes D4)

- **Autosave the working `BodyState` + `HistoryTree` to `user://`** on change (debounced) and on
  `_exit_tree`/`NOTIFICATION_WM_CLOSE_REQUEST`; restore on `_ready`. `CreatorIO` already has the
  serialization (`history_to_json`, `to_dict`); the read-back path is just unused
  (`creator-ux.md` #7). No new format.
- **"Save as archetype"** writes the current `BodyState` + a captured thumbnail to the user
  archetype library (§1.1) — this is the authoring loop that makes the archetype set open/moddable
  and is the natural home for the existing write-only export (`creator-ux.md` secondary obs).
- **Resume:** on open, if an autosave exists, the body is the in-progress edit (not the grid); a
  "Start over" returns to T0. So state survives switch/restart by default.

### 6.3 VR story

- **The creator works flat and in VR** (cross-platform parity, NSFW-first design). In VR the
  archetype grid is a **curved panel at arm's length**; picking is a ray/point gesture.
- **The killer VR affordance: a mirror.** VRChat-grade embodied presence (DESIGN.md reference)
  means you refine your body *while embodied in it*, seeing yourself in a mirror at 1:1 metric
  scale (height-cm is real metric, §4 — this is exactly why uniform-scale stature was chosen).
  T0/T1 (pick + headline nudge) is the VR-primary path; the precise detail sliders (T3) and
  drag-sculpt are flat-primary (fiddly in VR) but reachable via the panel. **Direct grab-sculpt
  in VR** (reach out and pull your own body in the mirror) is the aspirational VR refine gesture —
  it reuses `morph_drag.decompose_drag` with a 3D controller ray instead of a screen drag.
  **Unverified — would check:** drag-sculpt's math is screen-space (`morph_drag.gd` projects to a
  2D screen frame); a VR port needs a world-space decomposition variant — flagged as design work,
  not free.
- VR is **T0/T1 first-class, T3 reachable-but-flat-optimized** — honest about where precision
  lives, rather than pretending 56 sliders work great on a controller.

---

## 7. Concrete, testable quality bar

A candidate is "done enough to ship" when **all** of these pass (each is a concrete xvfb test or
a render assertion — the project's standing CI discipline, `nix run .#test`):

1. **Every shipped archetype renders valid at its own state** — for each of the ~15–18
   archetypes: load, bake, render front face + full body; assert (a) eyes seated within the
   socket AABB (not at the brow), (b) teeth/tongue inside the mouth AABB, (c) no NaN/degenerate
   verts, (d) silhouette has no self-intersection. *Automatable: AABB containment + the existing
   proxy seating asserts in `body_proxy_test.gd`, extended over the archetype set.*
2. **Proxies seat across the morph range (D1)** — render each archetype at masc 0/50/100 and
   age 18/40/70; eyes stay socketed at *every* point (the masc0==masc50 byte-identical-displaced
   render from body-visual-reverify §1 must NO LONGER hold — proxies must move).
3. **No monster within the envelope (D3/§3)** — for each archetype, randomize-within-validity
   200 seeded times; assert every result passes test #1 (validity is closed under randomize).
   Plus: max-out every Tier-2 slider simultaneously from each archetype; silhouette stays smooth
   (no angular lobes — re-run the `body-reverify.md` §4 extreme cases, assert the cumulative
   guard keeps them smooth).
4. **BreastSize drives geometry (D2)** — `breast/BreastSize` at 0.0 vs 1.0 on the same base
   produces a measurable chest-volume delta (bbox/cross-section measure), and it is *independent*
   of `breast/breast-volume-vert` (changing one doesn't move the other's measured axis). Golden.
5. **Determinism** — same archetype + same nudge sequence + same randomize seed → byte-identical
   `BodyState` and byte-identical baked mesh, across runs and platforms (the seeded-sim
   invariant). Golden hash.
6. **Common-path latency** — from creator-open to a fully-rendered picked archetype is
   interactive (grid visible <1 frame; picked body rendered without a perceptible main-thread
   stall — the async load, §6.1). *Measure under xvfb; the bar is "no synchronous build in the
   open frame," structurally testable (assert the heavy builders run deferred/threaded).*
7. **Fidelity floor (render-judged, the soft bar made concrete):** a front 3/4 face render of the
   default archetype must show, on inspection, (a) two correctly-seated eyes with round smooth
   irises facing forward, (b) eyebrows reading as brow hair on the brow ridge, (c) no
   face/cranium two-tone seam, (d) no back-of-head/inner-leg shading crease, (e) no opaque hair
   slab over the face, (f) skin that is not uniform-flat-matte (normal/roughness variation
   visible). Each maps to a §5 fix; each is a before/after render diff against the saved
   diagnosis renders (`_face_3q_nohair.png`, `bvd_*`).
8. **Persistence** — edit, switch scene, return: identical `BodyState` + history restored
   (D4). Quit, relaunch: same. Golden round-trip test.
9. **Gate untouched** — the existing gate boundary tests (17.9/18.0 yr, gated verb absent/present)
   still pass; archetype selection does not bypass or duplicate the predicate.

---

## 8. What this candidate deliberately does NOT decide

- The synthesized winner across the design-it-twice frames (this is one frame).
- The exact cumulative-displacement threshold curve (§3.2 — needs an empirical render sweep).
- The specific CC0 skin/normal map asset and its license verification (§5.3 — technique decided,
  asset flagged).
- The VR world-space drag-sculpt decomposition (§6.3 — flagged as real design work).
- The full archetype roster content (which 15–18 — that's authoring, not architecture).

## 9. Least-sure spots (honest)

1. **§5.1 eye UV cleanliness** — the smooth-iris fix assumes the eye proxy UVs are a clean per-eye
   island. The decision §11 claims this; the *current shader regressed to normals*, which makes me
   want to re-verify the UVs before committing (vs the riskier denser-eye fallback).
2. **§5.3 skin map on the MH UV layout + CC0 licensing** — the PBR technique is standard, but
   whether the MakeHuman base UVs carry a body-wide normal map without ugly seams, and finding a
   *genuinely* CC0 skin set, are both unverified-asset risks.
3. **§3.2 cumulative-displacement guard calibration** — the mechanism is sound but the threshold
   is empirical; a badly-tuned curve either lets monsters through or flattens legitimate shaping.
