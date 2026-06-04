# Decision: Body parameterization — natural units, single-axis sex macro, data-driven modifier registry, full CC0 library

Status: **DECIDED — design + phased slice plan** (2026-06-04); **amended** (sex
axis collapsed to single macro, 2026-06-04 — see §2)

Scope: the overhaul of the body-morph parameterization. This doc supersedes the
provisional `BodyState` shape sketched in `body-and-locomotion-slice.md` §2.1
(the six raw 0–1 macro knobs, 9-of-1280 targets imported) with: (a) a **public
API in natural units** where a real unit exists; (b) a **single `masculinity`
macro sex axis** (0–100) replacing the single 0–1 `gender` (the earlier two-axis
model — femininity + masculinity — was a design error; see §2 amendment); (c)
**height as pure stature, orthogonal to proportions**; (d) the **entire
~1,280-target CC0 library** imported via a **data-driven modifier registry**
parsed from MakeHuman's own modifier-definition JSON; (e) the **gate re-expressed**
from `age >= 0.5` to `body_age_years >= 18`. This doc is the spec — **no
implementation code**. It extends, and is cross-linked from,
`body-and-locomotion-slice.md` (the pipeline + slice discipline) rather than
living inside it, because that doc is the *pipeline* decision and this is the
*parameterization* decision; they are independently load-bearing.

Cross-links:
- `body-and-locomotion-slice.md` §1 (the nix-reproducible `.target`→ArrayMesh
  pipeline, the pinned MakeHuman source §1.3, the vendored CC0 subset), §2
  (`BodyState` ↔ NSFW gate — **this doc revises §2.1's shape and §2.2's
  threshold**), §4 (the slice discipline this doc's phases inherit).
- `affordance-substrate.md` — the guard layer where the Layer-1 NSFW gate lives;
  the body-state adult predicate feeds it.
- `units-and-scale.md` — 1u = 1m; canonical body dims; height-cm is anchored to
  this frame.
- `procedural-body-and-animation.md` §B (one-topology morph philosophy), §F (the
  one-substrate interlock — the same morph vector conditions the future
  controller).
- `../../DESIGN.md`, *Age × NSFW: gate the configuration, not the primitives*
  (Layer 1 hard structural gate). **§5 below touches this hard constraint.**

> **Verified-vs-assumed marker.** Every factual claim about MakeHuman's data and
> code below is tagged `[V]` (verified against the nix-pinned MakeHuman v1.3.0
> source — store path realized from the `body-and-locomotion-slice.md` §1.3 pin,
> `makehuman/` subtree) or `[A]` (assumption / design choice not derivable from
> the source). The pinned tree used for verification:
> `fetchFromGitHub { owner="makehumancommunity"; repo="makehuman"; rev="v1.3.0";
> hash="sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4="; }`, realized to a
> store path; data lives under `makehuman/data/`, code under `makehuman/apps/`
> and `makehuman/lib/`.

---

## 0. Why this exists

The current body system (`body-and-locomotion-slice.md` §2.1, Slice 1–2) exposes
**six raw MakeHuman macro weights as 0–1 axes** (`gender`, `age`, `muscle`,
`weight`, `height`, `proportions`) and imports **9 of MakeHuman's 1,280 CC0
targets** as hand-listed blendshapes (`tools/body_converter.gd` `MACRO_AXES`).
Two problems:

1. **The public API leaks an implementation detail.** "Age 0.5", "gender 0.7",
   "height 0.3" are MakeHuman macro-slider internals, not how a human or a
   designer thinks about a body. They are also *lossy* in a way that hurts the
   gate: `age = 0.5` is only "adult" by MakeHuman convention — the threshold has
   no self-evident meaning, which is exactly the wrong property for a hard legal
   gate to depend on.
2. **9 targets is a toy.** The within-form detail envelope (breast/buttocks/
   genitals/face/limb shape — 228 breast, 140 arms/legs, 102 expression, 68 eye
   targets, …) is the substance of "a body that reads as real" and "characters
   that feel real, not preset-parrots" (DESIGN.md). Hand-listing hundreds of
   blendshapes is the wrong shape — it is exactly the "prefer data over code at
   every seam" / "collapse N special cases to their primitive" anti-pattern
   (CLAUDE.md). MakeHuman already *ships the registry as data*; we should parse
   it, not retype a fraction of it.

The fix, decided: **natural units on the public surface, the raw macro weights
demoted to an internal mapping detail, and the full library imported via a
data-driven registry parsed from MakeHuman's own modifier JSON.**

---

## 1. Real MakeHuman data formats (verified)

This section grounds the design in what the pinned source *actually contains*, so
implementation is not assumption-driven.

### 1.1 Target files — `.target` `[V]`

`data/targets/**.target`, **1,280 files, 122.3 MB ASCII total** `[V]`
(`find … -name '*.target' | wc -l` → 1280; summed byte size 128,256,594).
Each is a sparse vertex-delta file: a CC0 header comment block, then lines of
`<vertex_index> <dx> <dy> <dz>` for only the moved verts. Verified header
(verbatim, from `…/height/female-young-averagemuscle-averageweight-maxheight.target`):

```
# This is a target file for MakeHuman
#
# This asset was explicitly released as CC0 in september 2020. The license
# text for CC0 can be found in the root of this repository.
#
# Original copyright (C) 2014 Manuel Bastioni
…
# Copyright (C) 2020 Data Collection AB, https://www.datacollection.se
```

A macro target moves ~19,150 of the 19,158 base verts `[V]` (that file:
`grep -vc '^#'` → 19150). `LICENSE.ASSETS.md` at the tree root is **CC0 1.0
Universal** `[V]` (verbatim first line: `# Creative Commons CC0 1.0 Universal`).

Per-category target counts `[V]` (`find <cat> -name '*.target' | wc -l`):

| category | targets | | category | targets |
|---|---:|---|---|---:|
| macrodetails | 348 | | nose | 42 |
| breast | 228 | | measure | 40 |
| armslegs | 140 | | head | 27 |
| expression | 102 | | bodyshapes | 22 |
| eyes | 68 | | torso | 18 |
| asym | 62 | | neck / cheek | 16 / 16 |
| mouth | 44 | | chin | 15 |
| ears | 44 | | hip | 14 |
| | | | stomach / forehead | 8 / 8 |
| | | | genitals | 6 |
| | | | eyebrows | 6 |
| | | | pelvis / buttocks | 4 / 2 |

The **CC0 caveat (carried verbatim from `body-and-locomotion-slice.md` §1.5):**
the *core bundled* targets above are CC0; the MakeHuman **community database**
(user-contributed clothes/hair/morphs) is **not uniformly CC0** — out of scope;
this import pins **only** the CC0 core under `data/targets/`.

### 1.2 Modifier definitions — the registry source `[V]`

`data/modifiers/` holds the registry as JSON. The files `[V]`:
`modeling_modifiers.json` (17,484 B), `measurement_modifiers.json` (1,506 B),
`bodyshapes_modifiers.json` (1,178 B), plus `*_modifiers_desc.json` (human-text
descriptions) and `*_sliders.json` (UI grouping — §7).

**Schema (exact).** A modifier file is a JSON **array of groups**; each group is
`{"group": <name>, "modifiers": [<modifier-def>...]}`. A modifier-def is one of
three shapes `[V]` (loader: `apps/humanmodifier.py:loadModifiers`):

1. **Bidirectional `UniversalModifier`** — has a `target` and **both** `min` and
   `max`:
   ```json
   {"target": "head-age", "min": "decr", "max": "incr"}
   ```
   The target base path is `<group>-<target>`; `min`/`max` (and optional `mid`)
   are *extension suffixes* naming the negative / positive target files. So this
   resolves to target files `head-head-age-decr` and `head-head-age-incr`, and
   the modifier's value runs **[-1, +1]** with 0 = neutral (base mesh).

2. **Unipolar `UniversalModifier`** — has a `target` but **no** `min`/`max`:
   ```json
   {"target": "head-oval"}
   ```
   One target file; value runs **[0, 1]**, default 0 `[V]`
   (`humanmodifier.py:Modifier.__init__` `_defaultValue = 0`).

3. **Macro modifier** — `{"macrovar": "<Name>"}`, optionally
   `{"modifierType": "EthnicModifier"}`:
   ```json
   {"group": "macrodetails",
    "modifiers": [
        {"macrovar": "Gender"},
        {"macrovar": "Age"},
        {"macrovar": "African", "modifierType": "EthnicModifier"},
        {"macrovar": "Asian",   "modifierType": "EthnicModifier"},
        {"macrovar": "Caucasian","modifierType": "EthnicModifier"}
    ]}
   ```
   A macro modifier does **not** drive one target — it sets a *macro variable*
   and the targets module recombines a whole macro target group (§1.3). Default
   value **0.5** `[V]` (`MacroModifier.__init__ _defaultValue = 0.5`); ethnic
   default **1/3** `[V]`. The macro groups `[V]` (`modeling_modifiers.json`):
   `macrodetails` → Gender, Age, African/Asian/Caucasian;
   `macrodetails-universal` → Muscle, Weight; `macrodetails-height` → Height;
   `macrodetails-proportions` → BodyProportions. (Breast Size/Firmness are macro
   modifiers in the `breast` group `[V]`.)

   A per-modifier `defaultValue` key overrides the class default `[V]`
   (`loadModifiers`: `if "defaultValue" in mDef: modifier._defaultValue = …`).
   **No `range`/`min-value`/`max-value` numeric keys exist** `[V]` — the range
   is *implied by shape*: bidirectional ⇒ [-1,1], unipolar ⇒ [0,1], macro ⇒
   [0,1] clamped (`MacroModifier.clampValue`). This is the registry's clamp
   logic verbatim `[V]` (`ManagedTargetModifier.clampValue`):
   ```python
   value = min(1.0, value)
   value = max(-1.0, value) if self.left is not None else max(0.0, value)
   ```

**`fullName` / addressing `[V]`.** A modifier's identity is `<group>/<name>`,
e.g. `macrodetails/Age`, `head/head-age-decr|incr`, `breast/BreastSize`. The
bidirectional name encodes both extensions: `head/head-age-decr|incr`. This
string is the stable key we use as the modifier-map key (§3).

**Description files `[V]`.** `*_modifiers_desc.json` maps `fullName`→prose, e.g.
verbatim:
```json
"macrodetails/Age": "Age of the human (range from 1 year to 90 years old, with center position 25 years).",
"macrodetails-proportions/BodyProportions": "Proportions of the human features … (min is unusual, center position is average and max is idealistic proportions).",
"macrodetails/Gender": "Gender of the human (min is female, max is male)."
```
These are usable verbatim as creator-UI tooltips (§7).

### 1.3 The macro factor-product system `[V]`

This is the load-bearing mechanic for the macro axes and the reason the *current*
9-target import is wrong. A macro target file is named by its **factor tuple**,
e.g. `universal-female-young-averagemuscle-maxweight.target` or
`caucasian-male-old.target` or
`height/female-baby-maxmuscle-minweight-maxheight.target`. The targets module
parses these tokens into **factor categories** `[V]` (`lib/targets.py:_cat_data`,
verbatim):
```python
_cat_data = [
    ('gender',          ['male', 'female']),
    ('age',             ['baby', 'child', 'young', 'old']),
    ('race',            ['caucasian', 'asian', 'african']),
    ('muscle',          ['maxmuscle', 'averagemuscle', 'minmuscle']),
    ('weight',          ['minweight', 'averageweight', 'maxweight']),
    ('height',          ['minheight', 'averageheight', 'maxheight']),
    ('breastsize',      ['mincup', 'averagecup', 'maxcup']),
    ('breastfirmness',  ['minfirmness', 'averagefirmness', 'maxfirmness']),
    ('bodyproportions', ['uncommonproportions','regularproportions','idealproportions']),
]
```

The weight applied to a macro target is the **product of its factor values** `[V]`
(`humanmodifier.py:getTargetWeights` → `reduce(operator.mul, [factors[f] for f in
tfactors])`). The factor values come from the human's macro state, each macro
split into anchor sub-weights `[V]`:

- **Gender**: `femaleVal`, `maleVal` (a linear split of the 0–1 gender macro).
- **Age** (`_setAgeVals`, verbatim `[V]`): four anchor vals over a piecewise map
  with breakpoints at `age` ∈ {0, 0.1875, 0.5, 1}:
  ```python
  # 1y      10y      25y           90y
  # baby   child    young          old
  # 0     0.1875    0.5            1   = age [0,1]
  if self.age < 0.5:
      self.oldVal   = 0.0
      self.babyVal  = max(0.0, 1 - self.age * 5.333)          # 1/0.1875
      self.youngVal = max(0.0, (self.age-0.1875) * 3.2)       # 1/(0.5-0.1875)
      self.childVal = max(0.0, min(1.0, 5.333*self.age) - self.youngVal)
  else:
      self.childVal = 0.0; self.babyVal = 0.0
      self.oldVal   = max(0.0, self.age*2 - 1)
      self.youngVal = 1 - self.oldVal
  ```
- **Weight / Muscle / Height / Proportions**: each a {min, average, max} triple
  from a 2× split about the midpoint `[V]` (`_setWeightVals` /`_setMuscleVals`/
  `_setHeightVals`/`_setBodyProportionVals`), e.g.:
  ```python
  self.maxweightVal     = max(0.0, self.weight*2 - 1)
  self.minweightVal     = max(0.0, 1 - self.weight*2)
  self.averageweightVal = 1 - (maxweightVal + minweightVal)
  ```

**Consequence.** A single macro slider does **not** map to a single blendshape.
The full age morph at a given sex/build is `Σ over targets` of
`(product of that target's factor vals)`. The base mesh is the **fully-neutral
product** (caucasian-female-young-averagemuscle-averageweight-…). MakeHuman ships
the macro group as a **dense factor cube** of pre-baked targets: 96 in
`macrodetails/` core + 144 in `height/` (sex×age×muscle×weight×**height**) + 108
in `proportions/` `[V]`. The current converter's 9-target shortcut linearizes
this — adequate for a one-axis-at-a-time demo, wrong for combined morphs (e.g.
"old + muscular + heavy male" is not the sum of three independent deltas).

### 1.4 Real-world mappings (verified — corrects the brief's guesses)

- **Age → years `[V]`** (`apps/human.py`): `MIN_AGE=1.0`, `MID_AGE=25.0`,
  `MAX_AGE=90.0`. The macro 0–1 ↔ years map (verbatim `getAgeYears`/
  `setAgeYears`):
  ```
  age < 0.5:  years = 1  + ((25-1)*2)  * age          # 1yr @0.0 … 25yr @0.5
  age >= 0.5: years = 25 + ((90-25)*2) * (age - 0.5)   # 25yr @0.5 … 90yr @1.0
  ```
  So the anchors are **1yr @ age 0.0, 25yr @ age 0.5, 90yr @ age 1.0**, and the
  morph anchor `child` sits at **age 0.1875 = 10 years** `[V]`
  (`_setAgeVals` comment). **The brief's guess of "25yr @ 0.5" is correct; its
  "10yr @ 0.1875" is correct; but note MID is 25yr (not a midpoint of 1–90), and
  the years↔macro map is *piecewise-linear in two segments*, not one line.**

- **Height → cm `[V]` — and the important subtlety.** There is **no
  cm-at-min/max constant in the data.** `getHeightCm()` is computed at runtime
  from the **mesh bounding box** (`10*(bbox.max.y - bbox.min.y)`) `[V]`
  (`human.py:getHeightCm`). i.e. cm is **emergent from the realized morph**, not
  an anchor we can read off a file. The Height macro is shipped as the 144-target
  `height/` cube (min/max-height per sex×age×muscle×weight). The
  `…-maxheight.target` deltas are **predominantly vertical but NOT a pure uniform
  scale** — sample line `0 -.097 6.886 .41` `[V]` (dy≈6.89 dominant, but nonzero
  dx/dz), and the target is *baked per build*, so MakeHuman's height is **coupled
  to build and not a pure stature scale.** This is decisive for §4.

- **Weight `[V]`**: macro 0–1 where **0.5 = full "average" weight for the build**,
  0 = full min-weight anchor, 1 = full max-weight anchor (the {min,avg,max}
  triple above). This *is* the "50–150% of average-for-build" semantic the brief
  names — average is the center, the ends are the lean/heavy extremes for that
  same sex/age/muscle. **There is no kg constant**; `getWeightKg()` is *estimated*
  from surface area via Mosteller's formula at runtime `[V]`, so it is emergent
  like cm.

- **Muscle / Proportions `[V]`**: same {min,avg,max}/bidirectional-about-center
  structure; muscle 0.5 = average, proportions 0.5 = "regular/average", min =
  "unusual", max = "idealistic" (desc verbatim §1.2).

### 1.5 Height ⊥ proportions — MakeHuman does NOT keep them orthogonal `[V]`

The brief asked to "confirm exactly how MakeHuman keeps stature independent of
proportion targets." **It does not.** Verified: (a) the Height macro is a baked
shape morph inside the full sex×age×muscle×weight×height cube, not a scale
transform `[V]` (§1.4); (b) the `proportions/` targets are a *separate* baked cube
(108 files) over sex×age×muscle×weight×{uncommon,ideal} `[V]`; (c) both feed the
same vertex deltas, so changing height re-shapes the body and changing
proportions does not preserve stature. **There is no orthogonality mechanism in
MakeHuman to confirm — aeriea must *engineer* it** (§4). This is a real finding,
not a gap: the decided "height = pure scale, orthogonal to proportions" axis is a
*deviation* from MakeHuman's model, made deliberately.

---

## 2. The decided public API (natural units)

`BodyState` exposes **headline natural-unit macro axes** + a **generic modifier
map** for detail. Natural units where a real unit exists; normalized/percent
where none does.

| public field | unit / range | semantics | maps to (internal) |
|---|---|---|---|
| `age_years` | **years, 1.0 … 90.0** (default 25) | real age | MakeHuman age macro 0–1 via the §1.4 piecewise map |
| `height_cm` | **cm** (e.g. ~50 … ~210, default per `units-and-scale.md`) | **pure stature scale, ⊥ proportions** | a *uniform mesh scale* + (optionally) a clamped height-macro contribution — see §4 |
| `masculinity` | **0 … 100** (default 50 = androgynous) | single macro sex axis: 0=feminine body, 50=androgynous, 100=masculine body | `macro_gender = masculinity/100.0` → drives the `gender_male` blendshape directly |
| `muscle` | **0 … 100 %** (default 50 = average) | muscle mass | muscle macro {min,avg,max} |
| `weight` | **50 … 150 %** of average-for-build (default 100 = average) | adiposity for the build | weight macro {min,avg,max} (100% = `averageweightVal`=1) |
| `proportions` | **dimensionless, idealized ↔ uncommon** (default 0 = regular) | within-form proportion envelope | proportions macro {uncommon,regular,ideal} |
| `modifiers` | **map: modifier `fullName` → value** | every detail axis (§1.2), defaulting to neutral when absent | direct per-modifier value, [-1,1] or [0,1] by shape |

**Single-axis sex macro (amended from the earlier two-axis design).** The
initial design replaced the single 0–1 `gender` with **two independent axes**
`femininity` and `masculinity`, each 0–100%, on the premise that androgynous
bodies (high-both) should be representable independently of the two poles. This
was a design error: MakeHuman's gender macro is a **single female↔male
interpolation** — one anchor pair, one blendshape (`gender_male`). Two
independent axes correspond to nothing in the data: `femininity` was a no-op
fiction in Slice A (it drove no blendshape; the base mesh *is* the feminine
pole). The "androgynous-full" configuration is incoherent in MakeHuman's single
macro space.

**Decision `[A]`:** the axis is collapsed to **one scalar `masculinity`**,
0–100, default 50 = androgynous (halfway between the poles). The mapping is
direct: `macro_gender = masculinity / 100.0` → `gender_male` blendshape weight.
`masculinity` is the chosen name — NOT `sex` (categorical) and NOT `gender`
(gender identity is deliberately decoupled from body morphology). The base mesh
is the feminine pole (0); 100 is the masculine anchor. Real sex-morphology
richness — androgyny blends, etc. — is emergent from the Slice C detail-target
modifiers (breast, hip, torso shape, …), not from splitting the macro. The name
`masculinity` conveys the morphology direction without encoding a gender-identity
claim.

**Raw macro weights are internal.** The 0–1 MakeHuman macro values
(`age`,`gender`,`muscle`,`weight`,`height`,`proportions`) are computed *inside*
`to_blend_weights()` from the natural-unit public fields — they are no longer the
public API. The inverse maps (§1.4) live in the converter/BodyState as pure
functions and are unit-tested against the verbatim MakeHuman formulas.

---

## 3. BodyState shape: headline axes + generic modifier map

```
BodyState = {
  # headline natural-unit macro axes (§2)
  age_years:    float,   # 1..90
  height_cm:    float,   # stature, ⊥ proportions
  masculinity:  float,   # 0..100 (0=feminine body, 50=androgynous, 100=masculine body)
  muscle:       float,   # 0..100
  weight:       float,   # 50..150 (% of avg-for-build)
  proportions:  float,   # idealized..uncommon, dimensionless

  # the detail envelope: a GENERIC map, modifier fullName -> value
  modifiers:    { String: float },   # e.g. "breast/BreastSize": 0.7,
                                      #      "nose/nose-hump-decr|incr": -0.3
}
```

- The `modifiers` map is **sparse**: an absent key means *neutral* (0 for the
  modifier's neutral, which is the base mesh). So a default `BodyState` is a
  neutral young adult with an empty map — serializes tiny, diffs cleanly, fits
  seed+action-log (the project's "prefer data over code / serializable over
  closures" seam, CLAUDE.md).
- Keys are the verified `fullName` strings (§1.2). Values are clamped by the
  registry-declared shape (bidirectional [-1,1], unipolar [0,1]).
- `to_blend_weights()` becomes: (1) compute the macro factor cube weights from
  the headline axes (§1.3 product math); (2) for each non-neutral `modifiers`
  entry, look it up in the **modifier registry** (§4) and emit its target
  weight(s) with the registry's sign convention. The output is the same
  `{ blendshape_name: weight }` projection consumed by the existing
  `apply_to`/`apply_morph_cpu` path (`body_state.gd`), so the render seam is
  unchanged.
- **Determinism preserved.** Same `BodyState` → same weights → same mesh; the map
  is iterated in sorted-key order for byte-stable output.

---

## 4. Height ⊥ proportions: the engineered orthogonality (decided)

Because MakeHuman couples height into the morph cube (§1.5), aeriea makes
`height_cm` a **pure overall scale** that does **not** touch limb ratios:

**Decision `[A]`:** `height_cm` is realized as a **uniform scale of the
fully-morphed mesh** (and the rig) about the foot origin, *not* by driving the
MakeHuman height macro. The MakeHuman height-macro targets (the `height/` cube)
are **not** wired to `height_cm`; they are either dropped from the macro
projection or pinned at average-height. Stature becomes `scale = height_cm /
base_height_cm`, where `base_height_cm` is the bounding-box height of the
*current morph at average-height* (measured once per build, the same
`getHeightCm` computation MakeHuman uses `[V]`). Proportions then change shape at
fixed stature; height changes stature at fixed shape. They are orthogonal **by
construction**, which MakeHuman's data does not give us for free.

Rationale: (a) VR demands real metric stature (`units-and-scale.md`) — a uniform
scale gives an exact cm with no per-config calibration table; (b) it makes the
two axes genuinely independent, which the design wants ("height scales overall
scale only, never limb ratios"); (c) it sidesteps the 144-target height cube
entirely, shrinking the import. **Honest cost:** real humans are not uniformly
scaled copies (a 150 cm and a 190 cm adult differ in proportion, not just
scale) — uniform-scale stature is a *simplification*. The `proportions` and the
per-limb `armslegs`/`measure` modifiers (§1.1) remain available to add
non-uniform variation deliberately, so the simplification is a sensible default,
not a cage. *(Open: whether to additionally expose a low-weight height-macro
contribution for subtle build-correlated stature realism — deferred; the pure
scale ships first.)*

---

## 5. The gate re-expression — TOUCHES A HARD CONSTRAINT

> **This section modifies a hard constraint (DESIGN.md Layer 1; CLAUDE.md
> "child-range body-state × NSFW is hard-gated"). It must stay robust.**

**Unchanged in intent.** The Layer-1 gate is still: *child-range body-state × any
NSFW/intimate verb is forbidden, enforced at the affordance/verb guard layer;
NSFW verbs guard on adult body-state* (`affordance-substrate.md`;
`body-and-locomotion-slice.md` §2.2). **Morph targets are NOT gated** — breast,
buttocks, genitals (§1.1) are all just anatomy, fully representable; the gate is
on the *verb×body intersection*, never on the morph primitives.

**The only change:** the adult-body predicate is re-expressed from
`age >= 0.5` (current `body_state.gd:ADULT_AGE_THRESHOLD := AGE_YOUNG`) to
**`age_years >= 18.0`** once age is in years.

**Where 18 falls in macro terms `[V]`.** Using `setAgeYears` (§1.4), 18 years is
in the first segment (`< 25`): `age = (18 - 1) / ((25 - 1) * 2) = 17 / 48 ≈
0.3542`. So the new threshold **age 0.354** is *more permissive than the current
0.5* on the raw axis — it admits the 18–25 "late-young-adult" band that the
conservative current threshold excludes. **This is the subtlety to flag:**

- The morph at 18yr (macro 0.354) is past the `child` anchor (10yr @ 0.1875) and
  well into the `young` band (the `youngVal` ramp runs 0.1875→0.5) — it is an
  adult-proportioned body, not a child morph `[V]` (`_setAgeVals`: at 0.354,
  `babyVal=0`, `childVal` small/zero, `youngVal` dominant). So 18yr is
  **unambiguously adult-proportioned**, satisfying the gate's purpose.
- **However**, moving the threshold *down* from 0.5 to 0.354 widens the
  adult-body set. Two safe-direction options, decided below.

**Decision `[A]`:** the gate predicate is `body_age_years >= 18.0`, with **18.0
the exact, documented constant** (legal age of majority in the overwhelming
majority of jurisdictions; the same overdetermined legal/platform rationale as
DESIGN.md). The predicate reads the **public natural-unit field**, which is the
whole point of natural units: `>= 18 years` is *self-evidently* the legal line,
unlike the opaque `>= 0.5`. The age axis stays **fully continuous and
uncrippled** (baby/child/young/old all representable) — the gate is a predicate
*over* the smooth axis, never a notch cut into it (DESIGN.md, *gate the
configuration, not the primitive*).

**Robustness requirements (carried as hard):**
1. **Fail-closed on missing/NaN age** — an absent or non-finite `age_years` is
   treated as non-adult (the existing host hook is already fail-closed —
   `interaction_world.gd:host_is_adult_body`).
2. **Single source of truth** — the `>= 18` predicate lives in exactly one place
   (`BodyState.is_adult_body`), consumed by the affordance guard; no duplicated
   threshold. The `body_age_years` ↔ macro map is a pure tested function.
3. **Conversion-safe** — because `age_years` is the *public* field and the
   macro is derived, the gate never reads the lossy internal 0–1 value; this
   *removes* a class of "what does 0.5 mean" ambiguity rather than adding one.
4. **Test the boundary** — golden tests assert: 17.9yr ⇒ not adult, 18.0yr ⇒
   adult, and a gated test verb is absent below 18 and present at/above (extends
   the existing Slice-2 gate test). The child morph still renders for ordinary
   use (no crippling) is also asserted.

This is a **net robustness improvement**: the threshold becomes a legally
meaningful, human-readable constant on a unit-bearing field, instead of an
engine-internal magic number.

---

## 6. The data-driven modifier registry (decided design)

**Decision:** at *build/import time*, the converter **parses MakeHuman's modifier
JSON** (`data/modifiers/modeling_modifiers.json`, `measurement_modifiers.json`,
`bodyshapes_modifiers.json`) into a **modifier registry** emitted alongside the
mesh, and imports the `.target` files those modifiers reference. Hundreds of
detail axes become data, not hand-listed blendshapes.

**Registry entry (emitted to the manifest)** — one per modifier, derived
purely from the JSON (§1.2 schema):
```
{
  full_name: "nose/nose-hump-decr|incr",   # the stable key (§1.2)
  group:     "nose",                        # category, from JSON
  kind:      "bidirectional"|"unipolar"|"macro",
  neg_target: "nose-nose-hump-decr" | null, # resolved target file (bidirectional)
  pos_target: "nose-nose-hump-incr",
  default:    0.0,                           # class default or per-def override
  range:      [-1, 1] | [0, 1],              # implied by kind (§1.2)
  label:      "...", tooltip: "..."          # from *_desc.json / *_sliders.json
}
```

- **Bidirectional** modifiers (`min`+`max`) emit **two** target blendshapes (neg,
  pos) and a **signed axis** in [-1,1]: value v<0 drives `neg_target` with weight
  `-v`, v>0 drives `pos_target` with weight `v` (the verified UniversalModifier
  factor logic `[V]`: `factors[left] = -min(v,0)`, `factors[right] = max(0,v)`).
- **Unipolar** modifiers emit one blendshape, axis [0,1].
- **Macro** modifiers are handled by the §1.3 factor-cube projection, not as raw
  blendshapes — the registry records them as `kind: macro` so the UI knows they
  are the headline axes, but their weights flow through the factor-product path.
- **Group/category, default, range, label** are **all from data** — no
  hand-listing. Adding/removing a MakeHuman modifier changes only the parsed
  output. This is the "library-first, projection-from-one-definition" /
  "collapse N special cases to primitives" principle applied (CLAUDE.md).

**Why import via the pinned source build, with a vendored subset.** The full
import builds from the **nix-pinned MakeHuman source** (already pinned,
reproducible — `body-and-locomotion-slice.md` §1.3) via the existing
`nix build .#body-assets` derivation. The **122 MB of ASCII targets** (§1.1) is
too large to vendor wholesale into the repo; it lives behind the pinned fetch and
the build emits the compact Godot artifact. The small **vendored CC0 subset**
(`vendor/makehuman-cc0/`, already present) is retained for the **fetch-free /
no-nix dev path and tests** — it carries the base mesh + a handful of macro/detail
targets so the converter and registry parser are exercisable without realizing
the full source. The registry parser must work identically on the subset and the
full tree (the JSON is small and fully vendorable even when the targets are not —
`modeling_modifiers.json` is 17 KB).

---

## 7. Creator-UI implication

Hundreds of axes demand a **categorized, grouped UI**, and MakeHuman ships the
grouping as data too. `data/modifiers/*_sliders.json` `[V]` is a UI tree:
top-level tabs (`Face`, …) with `sortOrder` + `cameraView`, each holding named
sub-groups (`"head shape"`, `"head size"`, `"eyebrows"`, …) of slider defs
`{"mod": "<fullName>", "cam": "...", "label": "..."}`. Decided:

- **Headline macros prominent.** The headline natural-unit axes (§2) are the
  always-visible top section, in natural units with real labels ("Age: 25
  years", "Height: 175 cm", "Masculine body: 50 (androgynous)").
- **Detail axes categorized.** The `modifiers` map is presented through the
  parsed `*_sliders.json` tree (tabs → sub-groups → labeled sliders), tooltips
  from `*_desc.json`. The creator (`scripts/body/character_creator.gd`) drives
  the same `BodyState` it already drives — a slider sets `modifiers[fullName]`,
  `apply_morph_cpu` re-bakes. No new render seam.
- **Sane defaults / progressive disclosure** `[A]`: detail sub-groups collapse by
  default; only the headline axes and a curated "common" set are open. (The
  current `character_creator.gd` six-slider panel is the headline section's
  starting point.)

---

## 8. Converter changes needed

`tools/body_converter.gd` (745 lines today) gains, none of which change the
render-side mesh/skin format:

1. **Registry parser** — read `data/modifiers/*.json` → the §6 registry; resolve
   each modifier's `target`/`min`/`max` to actual `.target` file paths under
   `data/targets/`; skip-with-warning any referenced target missing from the
   (subset or full) tree.
2. **Full target import** — replace the hardcoded 9-entry `MACRO_AXES` list with
   the registry-driven set: import every referenced detail `.target` as a named
   blendshape (keyed by `fullName`), and the macro factor cube as the macro
   projection input. *(Implementation note: ~1,280 blendshapes on one ArrayMesh
   is large; tiering / on-demand surfaces is an implementation concern flagged
   for Phase 3, not decided here.)*
3. **Macro factor-product projection** — implement the §1.3 product math
   (`femaleVal`/`maleVal`, the age piecewise-anchors, the {min,avg,max} triples)
   so combined macro axes compose correctly, replacing the linear single-target
   shortcut.
4. **Natural-unit conversion functions** — the §1.4 piecewise age↔years map and
   the height/weight semantics, as pure tested functions used by both the
   converter and `BodyState`.
5. **Manifest** — emit the registry (§6) into `base_body.manifest.json` so
   runtime `BodyState` can resolve `fullName`→blendshape without re-parsing the
   MakeHuman source.

`scripts/body/body_state.gd` changes: the natural-unit fields (including the
single `masculinity` macro sex axis) replace the six 0–1 fields; add the
`modifiers` map; `to_blend_weights()` gains the factor-cube + registry projection;
`is_adult_body()` becomes `age_years >= 18.0`; `to_dict`/`from_dict` round-trip
the new shape (per "retire, don't deprecate", a clean break — old `gender`/`age`
keys and the dropped `femininity` key are not read back `[A]`).

---

## 9. Phased implementation plan

Each phase is independently shippable and **xvfb-verifiable** (the standing CI
discipline; `body-and-locomotion-slice.md` §4). "Touches gate" is called out
explicitly per the hard-constraint rule.

**Phase A — natural-unit public API + single masculinity macro sex axis + gate re-expression.**
*Scope:* rewrite `BodyState` to the §2 natural-unit fields (incl. the single
`masculinity` macro sex axis, 0–100, default 50 = androgynous — see §2 amendment
for why the earlier two-axis model was collapsed), keep the *existing* 9-target
macro projection underneath (map natural units → the current 0–1 macros internally
via the §1.4 functions). Re-express the gate to `age_years >= 18.0`.
*Files:* `scripts/body/body_state.gd`, `scripts/body/character_creator.gd` (labels
→ natural units), the body/gate tests (`tests/body_asset_test.gd`,
the interaction gate test).
*Verify:* golden — same `BodyState` → same mesh; natural-unit sliders morph as
before; **gate boundary tests** (17.9yr not-adult / 18.0yr adult; gated verb
absent <18, present ≥18; child morph still renders). Movement/interaction suites
unchanged.
*Touches gate:* **YES** — the §5 re-expression. Highest-care phase; ship behind
the boundary tests. Pure-API refactor otherwise (no new targets).

**Phase B — modifier-registry parser + manifest, on the vendored subset.**
*Scope:* §6 parser reading `data/modifiers/*.json`; emit the registry into the
manifest; resolve target paths; **import a modest, registry-driven detail set
from the vendored subset** (no full 1,280 yet). `BodyState.modifiers` map wired
into `to_blend_weights()` for the imported detail axes.
*Files:* `tools/body_converter.gd`, manifest schema, `body_state.gd`
(`modifiers` map projection), a new registry-parser test fixture in
`vendor/makehuman-cc0/data/modifiers/` (vendor the 17 KB JSON).
*Verify:* parser produces the expected registry entries from the vendored JSON
(unit test against the verbatim schema §1.2); a detail modifier (e.g.
`breast/BreastSize` or a bidirectional nose axis) drives the mesh via the map;
rebuild byte-identical.
*Touches gate:* no.

**Phase C — full ~1,280-target import via the pinned source + macro factor cube.**
*Scope:* the registry-driven import over the **full pinned MakeHuman tree**
(`nix build .#body-assets`), the §1.3 factor-product macro projection (replacing
the linear shortcut), and the import-size/tiering handling for ~1,280
blendshapes. Height-⊥-proportions uniform-scale realization (§4).
*Files:* `tools/body_converter.gd`, `nix/body-assets.nix` (the full target set is
already reachable via `MAKEHUMAN_SRC`), `body_state.gd` (factor-cube projection,
`height_cm` uniform scale).
*Verify:* `nix build` from the pinned source produces the full artifact with no
manual step, byte-deterministic on rebuild; combined macro morphs compose
correctly (e.g. old+muscular+heavy male is the factor-product, spot-checked
against MakeHuman-computed expectations); height changes stature without changing
limb ratios; under xvfb the full creator renders.
*Touches gate:* no (the gate predicate is unchanged from Phase A; more targets
do not change the adult predicate).

**Phase D — categorized creator UI from `*_sliders.json`.**
*Scope:* §7 — parse the slider tree, render headline macros prominently + the
detail axes in collapsible categorized groups with `*_desc.json` tooltips.
*Files:* `scripts/body/character_creator.gd` (+ any UI scene), parser shared with
Phase B.
*Verify:* under xvfb the creator shows the grouped tree; a slider in a detail
group sets `modifiers[fullName]` and re-bakes; headline axes show natural units.
*Touches gate:* no.

Phase A is shippable alone (it is the API + gate change with no new data). B→C→D
each build on the prior. A and B are independent of C/D's full-import cost, so the
natural-unit API and the registry can land before the heavy full import.

---

## 10. Verified vs assumed — summary

**Verified `[V]` against the pinned source:** the 1,280-target count and 122 MB
ASCII size; the CC0 header + `LICENSE.ASSETS.md`; the modifier-JSON schema
(group/modifiers, target+min/max bidirectional vs unipolar vs macrovar, the
absence of numeric range keys, `defaultValue` override, the `fullName`
addressing, the `_desc`/`_sliders` companion files); the macro factor-product
mechanic and `_cat_data` categories; the age↔years piecewise map (1/25/90,
child@0.1875=10yr) and that **18yr = macro 0.354**; weight/muscle/height/
proportions {min,avg,max} structure; that **height-cm and weight-kg are emergent
(bbox / Mosteller), not anchored constants**; and that **MakeHuman does NOT keep
height orthogonal to proportions** (no mechanism to confirm — it couples them).

**Assumed / decided `[A]` (not derivable from source):** the single `masculinity`
macro sex axis (0–100, default 50; the earlier two-axis femininity/masculinity
model was a design error collapsed at Slice A — §2); the height-cm =
uniform-scale orthogonality (a deliberate deviation);
the 18.0-year gate constant and fail-closed/single-source robustness rules; the
sparse-map `BodyState` shape and sorted-key determinism; the clean-break
serialization migration; UI progressive-disclosure defaults; the import
tiering/handling for ~1,280 blendshapes (flagged as a Phase-C implementation
concern, not decided here); whether to add a subtle height-macro contribution on
top of uniform scale (deferred).
