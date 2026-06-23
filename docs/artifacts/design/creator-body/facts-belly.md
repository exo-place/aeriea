# Belly / stomach / abdomen morph targets — fact-finding (full MakeHuman source)

Fact-finding only. No code, no design changes.

## Source

Pinned MakeHuman v1.3.0 full source tree:
`/nix/store/f17xilfqj8v2xphny6qfy4xvp8pzg4mi-source/makehuman/`

Resolved via `MAKEHUMAN_SRC` (used by `tools/detail_library_build.gd:79` and
`tools/body_proxy_build.gd:115`; falls back to vendored CC0 subset
`res://vendor/makehuman-cc0/data` when unset). Index pin recorded in
`assets/body/base_body_detail.index.json:4`
(`rev v1.3.0`, `sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=`).

Targets live under `<src>/data/targets/`; user-facing groupings in
`<src>/data/modifiers/modeling_modifiers.json` and `measurement_modifiers.json`.
Note: `modeling_modifiers_desc.json` exists but the descriptions for body
(non-face) targets are all empty strings upstream — names are the only
semantics. Verified by reading the desc file directly.

## Correction to the earlier claim

The earlier claim "no modifier isolates local belly volume except the
pregnancy morph" is **FALSE**. The full source (and aeriea's already-imported
library) carries several belly-region axes distinct from pregnancy. Most
importantly `stomach-tone` is a standalone abdominal axis separate from
`stomach-pregnant`. Belly *fat* volume specifically is carried by the macro
weight cube and the `apple` body-shape rather than by a single dedicated
"belly-fat" detail target — see Q1.

## Full belly / torso-volume target enumeration

All counts are aeriea ADLB sparse-delta vertex counts from
`assets/body/base_body_detail.index.json` (render mesh = 14517 verts).
Every target below is `"kind": "detail"` unless noted; all are **already
imported** into aeriea's library.

### `data/targets/stomach/` — the dedicated belly group (modifier group `stomach`)
- `stomach-pregnant-decr|incr` — pregnancy belly shape: forward-and-down rounded
  gravid bulge. incr count 350, decr 144. The classic pregnancy morph.
- `stomach-tone-decr|incr` — **abdominal tone / abs definition**, NOT pregnancy.
  Tightens/defines the abdominal wall (incr = toned/abs, decr = soft/slack).
  Local to the stomach panel. incr 175, decr 199.
- `stomach-navel-in|out` — navel depth (innie/outie). Tiny, 19 verts each.
- `stomach-navel-down|up` — navel vertical position. 161/162 verts.

### `data/targets/torso/` — torso volume/shape (modifier group `torso`)
- `torso-scale-depth-decr|incr` — **torso front-to-back depth**; the closest
  thing to a generic "bigger/deeper belly+chest" volume axis (incr 1651, decr 1753).
- `torso-scale-horiz-decr|incr` — torso width (incr 6058, decr 6434).
- `torso-scale-vert-decr|incr` — torso height/length (large, ~10.5k).
- `torso-trans-{backward|forward|in|out|down|up}` — torso translation (~10.6k each).
- `torso-vshape-decr|incr` — V-taper of the torso (lats/waist taper), incr 5554.
- `torso-muscle-dorsi-decr|incr` — back (lats) muscle, ~532.
- `torso-muscle-pectoral-decr|incr` — pectoral muscle, ~470.

### `data/targets/hip/` — lower-belly / waist-to-hip (modifier group `hip`)
- `hip-waist-down|up` — waist line vertical position (down 991, up 541).
- `hip-scale-{depth|horiz|vert}-decr|incr` — hip block volume (depth ~1240,
  horiz ~1128, vert ~1130). Affects love-handle / flank region.
- `hip-trans-{backward|forward|in|out|down|up}` — hip translation (~1180–1250).

### `data/targets/measure/` — circumference measures (group `measure`/measurement sliders)
- `measure-waist-circ-decr|incr` — **waist circumference**: directly inflates the
  belly/waist girth (the most "belly bigger around" axis). 879 verts each.
- `measure-underbust-circ-decr|incr` — under-bust girth (upper abdomen), ~1190.
- `measure-bust-circ-decr|incr` — bust girth, ~1270.
- `measure-hips-circ-decr|incr` — hip girth, ~730.
- `measure-waisttohip-dist-decr|incr` — torso segment length waist→hip (~10.7k).
- `measure-napetowaist-dist-decr|incr` — nape→waist length (~10.7k).

### Macro cube (whole-body, `"kind": "macro"`) — carries belly *fat* volume
- `macrodetails/universal-<eth?>/<gender>-<age>-<muscle>-<weight>.target`
  e.g. `macrodetails/universal-female-young-averagemuscle-maxweight.target`
  (count 3495). The `*weight` axis (min/average/max) is the body-fat axis; at
  `maxweight` the abdomen rounds out as a soft fat belly. This is the actual
  "belly fat" source, but it is a **whole-body macro**, not a stomach-local
  detail — it fattens the whole figure, with the belly as the largest part.
  Driven by modifier `macrodetails-universal/Weight`.
- The `proportions` macro sub-tree
  (`macrodetails/proportions/...-{min|average|max}weight-...`) also keys off the
  same weight axis.

### Body shapes (`data/targets/bodyshapes/`, `"kind": "detail"`)
Endocrine-typology whole-figure shapes; several are belly-dominant:
- `bodyshapes-elvs-fem-apple` / `bodyshapes-elvs-man-apple` — **apple shape =
  central abdominal fat distribution (pot belly)**. fem 2894, man 1891.
- `bodyshapes-elvs-{fem|man}-adrenal`, `-liver`, `-thyroid` etc. — other
  distributions that redistribute belly/midsection volume.
  (Group/modifier: `bodyshapes_modifiers.json`.)

## Answers

### 1. Belly FAT / VOLUME morph distinct from pregnancy?
Yes — several, none of which is the pregnancy shape:
- **`stomach/stomach-tone-{decr|incr}`** — abdominal wall tone (decr = soft
  slack belly, incr = toned/abs). The true stomach-local non-pregnancy axis.
- **`measure/measure-waist-circ-incr`** — inflates waist/belly girth.
- **`torso/torso-scale-depth-incr`** — pushes the belly/torso forward (deeper).
- **`macrodetails/...maxweight`** (Weight macro) — the actual *fat* belly, but
  whole-body, not stomach-local.
- **`bodyshapes-elvs-{fem,man}-apple`** — pot-belly central-fat figure.

So a rounder/bigger belly that is NOT pregnancy is achievable today via
`stomach-tone-decr` + `measure-waist-circ-incr` + `torso-scale-depth-incr`
(local) or `Weight`/`apple` (whole-body fat). The earlier "only pregnancy"
claim does not hold.

### 2. Distinct belly-region axes available
- Pregnancy shape — `stomach-pregnant`
- Abdominal tone / abs — `stomach-tone`
- Navel depth (innie/outie) — `stomach-navel-in|out`
- Navel position — `stomach-navel-down|up`
- Waist girth (belly around) — `measure-waist-circ`
- Upper-abdomen girth — `measure-underbust-circ`
- Torso depth (belly forward) — `torso-scale-depth`
- Torso width — `torso-scale-horiz`
- Torso V-taper — `torso-vshape`
- Waist line position — `hip-waist-down|up`
- Love-handles / flanks (hip block) — `hip-scale-horiz|depth`, `hip-trans-out`
- Whole-body fat (belly fat source) — `Weight` macro (`*weight` targets)
- Fat-distribution figure (pot belly) — `bodyshapes ... apple` / others

### 3. Already in aeriea's library vs needing import
**All of the above are ALREADY imported** into
`assets/body/base_body_detail.index.json` (target_count 719; 531 detail + 188
macro). Verified present: all 8 `stomach/*`, all 18 `torso/*`, all 14 `hip/*`,
the 12 belly-relevant `measure/*`, all 22 `bodyshapes-elvs-*`, and the universal
weight macro cube (incl. `...maxweight`). Nothing in the belly region needs
importing from the full source — the full set is already vendored into the index.

The only gap is **semantic/UI**: these axes exist as raw MakeHuman targets but
are not yet surfaced as named creator sliders, and upstream provides no human
descriptions (desc strings empty). That is a design task, not an import task.
