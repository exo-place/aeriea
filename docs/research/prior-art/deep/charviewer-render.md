# Deep-dive: CharacterViewer (DIC) — the parametric-body render pipeline

**Source:** `~/git/character-viewer` (DIC — "Doll Image Creator", a TiTS/CoC companion).
ActionScript 3 / Flash. Vector art is authored as Flash `MovieClip` symbols (linkage class
names like `HumanFemaleNormalBody`); the AS3 code below selects, composes, and colors them.
HEAD at time of read: `c43ceeb`.

This is the closest extant prior art to aeriea's visual channel: a **continuous, numeric body
state** (the same `Creature` save schema the prose game runs on) is rendered into a **finite,
hand-authored, sparse combinatorial art set**, with all the selection logic driven by
**data tables (JSON), not code**. The pattern aeriea wants is exactly here: *continuous state →
finite surface, quantize at the seam, map-as-data, degrade gracefully on unrepresented combos.*

The pipeline has four distinct stages, each a clean seam:

1. **Quantize** — continuous body scalars → small integer "viewer indexes" (`SaveTranslator`).
2. **Select** — `(type, i, j, k)` index tuple → a concrete art Class, via a JSON dictionary,
   with a **per-type graceful defaulter** when the tuple is unrepresented (`ClassDictionary`).
3. **Compose** — instantiate, z-order by draw sequence, position/rotate, mask for shadows
   (`BodyLayer` + the layer stack).
4. **Color** — recolor named child segments of each part by `ColorTransform`, with shades
   derived mathematically from a small named-color palette (`PartPainter` + `ColorDictionary`).

---

## Stage 1 — Quantization at the render seam (`classes/SaveTranslator.as`)

This is the literal "quantize at the seam" move, and it's almost aggressively simple: a set of
hand-tuned **threshold ladders**, one method per body dimension, mapping a continuous savefile
scalar to a small integer art index. No interpolation, no formula — just `if` cascades.

`SaveTranslator.as:20-32` (`getRealBoobIndex`) — a 10-bucket non-linear ladder:

```
size < 1  -> 1     size < 9  -> 5     size < 48 -> 8
size < 3  -> 2     size < 15 -> 6     size < 80 -> 9
size < 5  -> 3     size < 27 -> 7     else      -> 10
size < 7  -> 4
```

Note the buckets are **non-uniform and widen with size** (1,2,2,2,6,12,21,32, then "80+").
That's a perceptual/art-budget choice: small breasts need fine gradation, huge ones can share
one mega-asset. The same shape recurs for cock (`:39-51`, 10 buckets), ass (`:58-67`, 7),
hair length (`:74-81`, 5), hips (`:88-97`, 7). Each ladder is independent and tuned to how many
art variants the artist actually drew for that part.

**Crucial detail — quantize *after* scaling, not before.** Height is folded into the value
*before* quantization. `CharacterProperties.as:40` computes `heightMod = 82 / tallness`
(82 = the canonical art height in inches), and `BodyLayer.addCocks` (`:173`) passes
`player.cocks[i].cockLength * prop.heightMod` into `getRealCockIndex`. So a given absolute size
maps to a *larger* art index on a shorter character — the doll's proportions stay self-consistent
because the seam quantizes the *rendered-relative* size, not the raw stat. Boobs (`:219`) and
balls/clit (`CharacterProperties.as:41-42`) do the same.

**Other quantizations live inline in `BodyLayer`, not in the translator.** Watch for these —
they're the same pattern but scattered:
- Face femininity → 3 expressions: `addFace` `:62` `u = 2 - Math.floor(player.femininity / 34)`.
- Body tone → fit/normal: `addBody` `:71` `n = (player.tone >= 50) ? 1 : 0`.
- Masculine flag → fem/masc art: `CharacterProperties.as:44` `(player.femininity < 50) ? 1 : 0`.
- Nipple length → 0..7: `addBoobs` `:211` `lim(player.nippleLength * 4, 0, 7)`.
- Clit/ball size clamp to 0..8 *gated by presence*: `:112` `lim(realClitSize,0,8) * int(hasVag)`
  — a neat trick: multiplying the size index by the boolean collapses "absent" to index 0 in one
  expression.

### aeriea implications
- **This is the channel boundary aeriea has been circling.** The continuous typed body
  (frond/tag system) is the `Creature`; the visual channel needs exactly this ladder layer —
  a deterministic `quantize(bodyScalar) -> artIndex` per renderable dimension. Keep it a pure
  function of state (it already is here: no RNG in the ladders) so it stays replay-deterministic.
- **Quantize relative-to-render, not raw.** DIC's `heightMod` trick is the lesson: the seam must
  normalize for global scale first or proportions drift. aeriea's body has far more interacting
  dimensions, so define the normalization basis explicitly.
- **Bucket widths are an art-budget knob, not a math constant.** Make the ladders *data*
  (aeriea is data-over-code at seams) so an artist/tuner edits thresholds without a code change —
  DIC hard-codes them in AS3, which is the one place it violates its own data-driven ethos and
  pays for it (see gotchas).

### gotchas / anti-patterns
- **The ladders are code, not data** — the single inconsistency in an otherwise data-driven
  codebase. Every threshold edit is a recompile. aeriea should push these to a table.
- **Magic constants with no provenance** (`82`, `/34`, `*4`, the bucket edges). Cite the source
  of each constant or it rots. (aeriea's CLAUDE.md already mandates cited constants — cf. the
  CDC height-curve commit.)
- **Off-by-one between dimensions:** boobs start at index 1 (`size<1 -> 1`), cocks start at 0.
  Inconsistency that only survives because each ladder feeds a separate dictionary axis.

---

## Stage 2 — Selection + graceful degradation (`classes/ClassDictionary.as`)

This is the heart of the prior art and the part aeriea should study line-by-line.

### The data shape: a 3-deep ragged index tree, keyed by type

`data/TiTS_Dictionary.json` is `type -> i -> j -> k -> ClassNameString`. Example (`body`):

```json
"body": {
  "0": { "0": {"0":"HumanFemaleNormalBody","1":"HumanFemaleFitBody","2":"HumanFemaleFatBody"},
         "1": {"0":"HumanMaleNormalBody",  "1":"HumanMaleFitBody",  "2":"HumanMaleFatBody"} },
  "1": { ... Furry ... }, "2": { ... Scaley ... }, "3": { ... Gooey ... }
}
```

So `body[skinType][masculine][toneBucket]` (the three indexes computed in `addBody`) names a
concrete symbol. The tree is **ragged and sparse**: `tail` only populates index `i` (e.g.
`"7":SpiderTail`, and note **`8` and `12,13` are absent** — non-contiguous keys are normal),
with `j=k=0`. Each type uses only as many of the 3 axes as it needs; unused axes are pinned to 0.

### How JSON becomes a typed structure: the reviver

`ClassDictionary` constructor (`:27-41`) parses the JSON with `classDictionaryReviver`
(`:305-341`), which does three jobs bottom-up:
- A leaf **string** → resolved to an actual `Class` via `getDefinitionByName`, *iff*
  `ApplicationDomain.currentDomain.hasDefinition(...)` (`:309`). **If the art symbol isn't
  compiled in, the string silently becomes `undefined`** (`:315`) — i.e. the data table can
  reference not-yet-drawn art and the system just treats that cell as a hole. (This is what
  `Todo.txt`/`TodoGraphics.txt` track.)
- An object whose keys are ints (`src["0"]` exists) → converted to a **typed `Vector`**, nesting
  depth inferred by sniffing whether `array[0]` is a `Class` / array-of-Class
  (`:317-333`). Missing int keys become `undefined` holes in the vector.
- An empty object → `undefined` (`:339`) — empties are pruned, not kept.

So at runtime the dictionary is `Object{ type : Vector<Vector<Vector<Class>>> }`, sparse, with
`undefined` holes anywhere.

A **reverse index** is built once (`getReversedDictionary` `:347-387`): `Class -> [type,i,j,k]`.
This is how the running viewer asks "what indexes is this part currently at?" (`getPartIndexes`
`:196`) in O(1) — essential for cycling and for the dependent-part updates (ears track hair
length, etc., in `Character.updateEars/updateClit/updateVag`).

### The lookup with fallback: `findPart` + `getDefaultIndexes`

`findPart(type,i,j,k)` (`:51-71`):
1. `testClass` (`:171-187`) walks the ragged tree and returns **2** (type missing — hard error),
   **1** (some index out of range / hole), or **0** (hit).
2. On `1`, call `getDefaultIndexes` to *repair* the tuple, then index again and instantiate via
   the pool.

**The defaulter (`:81-151`) is the graceful-degradation engine, and it's data-driven.**
`data/TiTS_Defaulter.json` maps each type to a short digit string giving the **priority order in
which axes may be collapsed to 0**:

```json
"body": "132",   "face": "132",   "cock": "1",   "arms": "1",
"hand": "2",     "hair": "2",     "legs": "2",   "balls": "1", ...
```

Read `"132"` as: *if the exact `(i,j,k)` isn't drawn, first try zeroing axis 1, then axis 3, then
axis 2* — i.e. the digit *string* is the search order, "least important axis to sacrifice first."
For `body`, sacrificing axis 1 (skinType) first means a Gooey/Scaley body that lacks a specific
fit/tone variant falls back to the **Human** art for that pose before it loses gender or build.

The mechanism (`getDefaultIndexes` `:81-151`) is an exhaustive **minimal-collapse search**,
sized by how many axes the type allows defaulting (`switch (defaulter.length)`):
- length 3 (`:94-101`): try collapsing 1 axis (in priority order), then 2, then all 3 — 7 probes
  total, ordered so the **fewest** axes are zeroed and the **least important** ones go first.
- length 2 (`:104-107`): try axis 1, axis 2, then both.
- length 1 (`:110-111`): just zero the one defaultable axis.

`testDef(a,b)` (`:122-132`) maps a *priority slot* (1/2/3) through the defaulter string to an
*actual axis*, zeroes those axes, and asks `testClass == 0`. `getVec` (`:137-150`) returns the
repaired tuple. The first probe that hits wins; if nothing hits it falls through to "zero
everything defaultable" (`getVec(1,2,3)`), which by construction reaches the `(0,0,0)` base art
every type guarantees. **The contract: index 0 on every defaultable axis must always be drawn.**

This is genuinely elegant: a *sparse* art set never hard-fails on an unrepresented body, because
the lookup degrades along an artist-authored priority gradient toward a guaranteed base asset,
and the gradient is **data** (`TiTS_Defaulter.json`), tunable per body part without touching code.

### Cycling (the editor's "next variant" buttons): `getNextClass` + the cycler table

`data/DIC_Cycler.json` maps `type -> cyclingButtonID -> "a,b,c"` where each digit flags which of
the 3 axes a given UI button increments. `getNextClass` (`:231-283`) increments the flagged axis,
**skipping `undefined` holes** (`while (vector[index] == undefined)` `:272`) and wrapping around
(`:266-269`) — so the artist's sparse, non-contiguous index keys (the missing `8` in `tail`)
are invisible to the user; cycling lands only on drawn variants.

### aeriea implications
- **Adopt the `(type, index-tuple) -> asset` JSON dictionary wholesale, and the defaulter with
  it.** This is the canonical "map-as-data at the render seam." aeriea's visual channel should
  resolve a quantized body tuple to a concrete renderable through a table exactly like this, so
  new art is added by editing data, and the table can reference art that doesn't exist yet
  (the hole = the TODO).
- **The per-type priority-collapse defaulter is the answer to combinatorial sparsity** — which
  aeriea *will* have acutely (NSFW-first, deep customization = a huge cross product no art set
  can fully cover). Don't enumerate the cross product; author a base per axis + a priority order,
  and let lookups degrade. Make the priority order data, per body part.
- **Build the reverse index.** aeriea needs "given current visual, what's the body tuple" for
  editor round-tripping and for dependent-part coupling (DIC: ears follow hair length, clit
  follows vagina presence — `Character.as:277-307`). A `Class->tuple` (here, `asset->tuple`)
  map makes those O(1).
- **Determinism note:** selection here is pure (state → tuple → table → asset). The *only* RNG in
  the whole pipeline is cosmetic jitter in composition (cock rotation/scale, `addCocks:181-188`)
  and `ArrayUtils.randomize(player.cocks)` (`:164`). For aeriea, that jitter must be drawn from
  the **seeded** timeline, or the same body renders differently on replay. DIC uses bare
  `Math.random()` — acceptable for a toy viewer, a defect under aeriea's determinism invariant.

### gotchas / anti-patterns
- **Silent holes are double-edged.** A typo in a class name in the JSON degrades to `undefined`
  and is *swallowed* by the defaulter — the body renders, just wrong, with no error. aeriea
  should keep DIC's lenient runtime but add a **build-time validator** that asserts (a) every
  referenced asset exists or is explicitly marked TODO, and (b) every type's `(0,0,0)` base is
  present (the defaulter's terminal guarantee). Otherwise the fallback masks data bugs.
- **`getClassUnsecured` (`:293-296`)** indexes the dict with no fallback and "crashes horribly"
  (its own doc). It exists for the editor's direct index-set path (`Character.setPartIndexes`).
  Two lookup paths — safe and unsafe — is a footgun; aeriea should have one safe path.
- **Defaulter strings cap at 3 axes** (`defaulterReviver:402` throws if longer). The whole
  scheme is hard-wired to exactly 3 index axes everywhere (`testClass`, the reverse index, the
  reviver depth-sniff). aeriea's body has *many* more meaningful axes; the 3-axis tree won't
  generalize — take the *pattern* (typed tuple → table → priority-collapse fallback), not the
  fixed arity. A variable-length tuple + variable-length defaulter is the right generalization.
- **Reviver depth inference by sniffing `array[0][0] is Class` (`:329`)** is fragile — a type
  with a hole at `[0]` would mis-infer nesting. Works only because every type has `(0,0,0)`.

---

## Stage 3 — Composition: layering, z-order, masks (`classes/character/layers/`)

### Layer stack and z-order

`Character.initLayers` (`:83-106`) builds a fixed Sprite stack, back→front:
`backLayer, backWeaponParent, [bodyLayer + shaderLayer], frontLayer, frontWeaponParent`.
Within `BodyLayer`, **z-order is simply the call order of the add-functions** in `drawLayer`
(`:37-58`): arms, ass, legs, body, head, face, hips, hand, vag, clit, balls, boobs, cocks.
Each `addX` does `addChild(foundPart)`, so paint order *is* depth order. No explicit z-index —
**the draw script is the layering spec.** Re-orderings happen only where art demands it
(boob rows added in *reverse* `n=3..0` so row 0 sits on top, `addBoobs:215`; the cock parent is
re-depthed at runtime by `updateCockIndex:382-400` using `hitTestPoint` against the boobs so
cocks don't poke through an overhanging breast).

### Scalable parts: the `MC` sub-clip convention

Most parts are static symbols. Parts that scale continuously (biggest cock bucket index 9, boob
bucket 10, big balls, clit) wrap a child `MovieClip` named **`MC`** that the code transforms.
`PartPool.initProperties` (`:90-98`) flattens `part.MC`'s children up onto `part` as dynamic
properties at creation, so `painter` can reach named segments uniformly whether or not there's an
`MC` wrapper. Composition then sets `foundPart.MC.rotation/scaleX/scaleY` (`addCocks:181-188`)
for the jittered fan of cocks, or scales `boob.MC` for the mega-boob (`addBoobs:234-237`).
This is how a *finite* bucket (index 9/10) regains *continuous* expressiveness at the top end —
the last bucket is a scalable asset rather than another fixed one.

### Shadows: clone + mask, derived not authored

`setPartShadow` / `setDarkPart` (`:282-348`) implement inter-part shadowing without anyone drawing
shadow art per combination. For each surface that can be shadowed, it **clones the part**
(`clonePart` → pool), colors the clone with the *shade* color, stacks it on top, and **masks the
dark clone with a `shade` symbol** picked by the occluding part's size index
(`classDict.findPart("shade", index)` `:294`). So "boobs cast a shadow on the body" is realized by
selecting a shade-mask sized to the boob's bucket — again **index → asset**, reusing the same
dictionary machinery for shadows. The author's own comments (`:265-276`) are candid that this is
fragile (Flash mask XOR interactions, white-pixel seams from `cacheAsBitmap` alpha mixing).

### aeriea implications
- **"Draw order = layer spec" is fine for a fixed silhouette but won't survive aeriea's
  variety.** DIC has one pose, one camera. aeriea (parkour, VR, many poses) needs explicit,
  data-driven z-ordering — but keep DIC's insight that *most* ordering is static and only a few
  parts need runtime re-depthing (the `updateCockIndex` hit-test pattern is a good model for
  "this part's depth depends on another part's current extent").
- **The "top bucket is a scalable asset" trick is the bridge between quantized and continuous.**
  aeriea can render the bulk of a range with discrete buckets and reserve a scalable asset for the
  tail, getting continuity where it matters without N more drawings. Worth stealing directly.
- **Derive shadows/AO from the same index tables rather than authoring per-combo.** The
  clone-and-mask approach is Flash-specific and ugly, but the *principle* — occlusion art selected
  by the occluder's quantized size — generalizes to any layered 2D channel aeriea builds.

### gotchas / anti-patterns
- **Implicit z-order via call sequence** means layering is invisible until you read the whole
  `drawLayer` and is easy to break when adding parts. Make it explicit data in aeriea.
- **Runtime depth via `hitTestPoint` + a `setTimeout(…, 50)`** (`Character.initGraphics:126`,
  `updateCockIndex`) is a hack to wait for layout — non-deterministic timing. Anti-pattern for a
  deterministic engine; resolve depth from state, not from a post-layout pixel hit-test on a timer.
- **Shadow system fights the renderer** (author's own comments). Don't port the mechanism; port
  the idea.

---

## Stage 4 — Coloring (`classes/character/PartPainter.as`, `classes/ColorDictionary.as`)

### Named-segment recoloring by `ColorTransform`

Art is drawn in **flat placeholder colors**; recoloring is done by tinting named child MovieClips.
`data/DIC_ChildrenNames.json` maps each part type to the *segment child names* it exposes, in 7
slots (`PartNames.as:9-15`): SF/SS = skin fill/shade, HF/HS = hair fill/shade, BF/BS =
"bits" (nipples/lips/glans) fill/shade, EF = eyes fill. E.g.
`"face": {"SF":"fillbg","SS":"shading","BF":"lips","BS":"lipsShading","EF":"pupils"}`.

`PartPainter.addPart` (`:143-171`) reads that map for the part's type and stashes each found child
in the matching `Dictionary` (`segmentsSkinFill`, etc.), keyed weakly by the part. Recolor
(`colorAllParts:314-326`, `colorPart:280-291`) then iterates each segment dictionary and applies
one `ColorTransform` whose **offsets carry the RGB** (`colorSegment:298-308`:
`ct.redOffset = color>>16` …). Using *offset* (not multiplier) on a part drawn near-black means the
offset effectively *sets* the color — a cheap full-recolor of a grayscale/flat asset. Six colors
drive everything: `[skinFill, skinShade, hairFill, hairShade, bitsFill, bitsShade]` + eyes.

### Where the palette comes from: small named table + derived shades

`ColorDictionary` embeds tiny JSON palettes — `DIC_SkinColor.json` (~31 named tones),
`DIC_BitsColor.json`, `DIC_HairColor.json`, `DIC_EyesColor.json` — name → hex. Only **fill**
colors are authored; **shades are computed** (`createShadeDictionaries:145-165`):
shade = RGB each channel `max((c-5)*0.7*{1.1,0.9,1.1},0)` — i.e. darken ~30% with a cool
(more blue/red, less green) bias, in RGB. Missing bits-colors are auto-filled from skin via HSV
(`completeBitsDictionary:117-138`: `s*1.1, v*0.7`). For Gooey skin (`skinType==1`),
`getColorCodes:85-91` *derives skin from hair* (translucent goo) and **interpolates bits toward
skin in CIELab** (`interpolate:242-252`) — perceptual blending, deliberately "overkill" per the
author. ColorJizz (`com/ColorJizz/`) provides the Hex/RGB/HSV/CIELab conversions.

### aeriea implications
- **Flat-art + named-segment tint is the right NSFW-first recolor model.** One grayscale/flat
  asset recolors to any skin/hair/areola/eye palette via a handful of color slots — no per-color
  art. aeriea's visual channel should author parts with **named tintable segments** and a small
  **named-color palette as data**, deriving shades rather than authoring them.
- **Derive secondary colors, don't author them.** Shades from fills, bits from skin, goo-skin from
  hair — all computed. Keeps the authored palette tiny and internally consistent. The CIELab
  interpolation for perceptual blends is a nice touch worth keeping where blends matter.
- **Color is a separable late stage.** `colorCharacter` runs after all parts exist
  (`Character.initGraphics:111-127`) and re-runs on any change — clean separation of *what art*
  (stages 1–3) from *what color* (stage 4). aeriea should keep that seam; palette/skin swaps must
  not re-resolve geometry.

### gotchas / anti-patterns
- **`ColorTransform` offset-as-color only works because art is near-black.** It's a
  representation hack; aeriea on Godot should use proper material tinting / masks, but keep the
  *named-segment* data model.
- **Duplicate keys in `DIC_SkinColor.json`** (`"dark"` appears twice — `:7-8`) — silent
  last-wins in JSON. The palette has no validation. aeriea: validate palette tables (unique keys,
  every name resolves) at build time.
- **Named-color → hex indirection** means the body stat carries a *color name string*
  (`prop.skinColor`), and an unknown name falls back to `"white"`/`"red"` with only a `trace`
  warning (`getColorCodes:71-80`). Fine for a closed palette; aeriea should decide whether the
  body channel stores a name (palette-bound) or a raw color (free), and validate accordingly.

---

## Synthesis for aeriea

DIC is a working, shipped demonstration of the exact seam aeriea is designing: the **same numeric
body state** feeds both the (TiTS/CoC) prose game and this visual doll, and the visual side is
nothing but **quantize → table-lookup-with-fallback → ordered composition → segment recolor**,
with every selection driven by **JSON data** an artist edits.

Take directly:
- the **quantization ladders** (as *data*, normalized to render-scale first),
- the **`(type, tuple) → asset` dictionary**,
- the **per-type priority-collapse defaulter** for combinatorial sparsity — the single most
  valuable artifact here, the thing that lets a sparse art set never hard-fail,
- the **reverse index** for round-tripping and dependent-part coupling,
- the **named-segment flat-art recolor** with **derived shades** and a tiny named palette,
- the **"top bucket is a scalable asset"** continuity trick.

Generalize / fix:
- make the **arity variable** (DIC hard-wires exactly 3 index axes; aeriea has many),
- make the **ladders and z-order data**, not code,
- route all **jitter/RNG through the seeded timeline** (DIC's bare `Math.random`/`setTimeout`
  break determinism),
- add a **build-time validator** so the lenient `undefined`-hole behavior masks TODOs, not bugs
  (assert every `(0,…,0)` base exists; every referenced asset exists-or-is-marked-TODO; palette
  keys unique).

The throughline matches aeriea's CLAUDE.md verbatim: *prefer data over code at the seam* (DIC
does, except for the ladders — and that exception is exactly where it hurts), and *quantize the
continuous state into a finite surface at the boundary* while keeping the underlying sim continuous.
