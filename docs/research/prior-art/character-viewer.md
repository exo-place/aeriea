# Prior Art: Fenoxo CharacterViewer (DIC — "Doll Image Creator")

Status: studied 2026-06-22 from full clone at `~/git/character-viewer` (commit as cloned from github.com/Fenoxo/CharacterViewer). Author credited in-code as "Sbaf" / "sb-af".

Scope: A standalone ActionScript 3 / Flash (`DIC.fla` + 238 `.as` files) **paperdoll renderer** for Corruption of Champions (CoC) and Trials in Tainted Space (TiTS) characters. It is NOT a game — it loads a CoC/TiTS save (a Flash `SharedObject`), reconstructs the character's body from ~100 morphology fields, assembles a layered vector-art doll, recolors it, applies a goo shader, and lets you cycle parts / take high-res screenshots. This is the closest public prior art to aeriea's *parametric-body visual rendering* seam: it answers "given a fully-quantified body, how do you actually draw it?" Note the contrast with aeriea's prose thread — CharacterViewer is the *visual* half; the *prose* half lives in the copied CoC `Creature` model it carries.

Most of the repo by file count (`com/sibirjak/asdpc*`, `com/ColorJizz`, `com/gskinner`, `PNGEncoder2`) is vendored third-party libraries (the as3dpc UI toolkit, a color-space lib, a tweener, a PNG encoder). The original work is in `classes/` + `includes/` + `data/`.

---

## Architecture at a glance: simulation-data → layered paperdoll

The pipeline (`classes/character/Character.as`) mirrors aeriea's "simulation underneath, rendering on top":

1. **Body data model** — `classes/save/Creature.as` (3795 lines): a flat struct of ~100 enum-coded morphology fields (`faceType`, `earType`, `lowerBody`, `tailType`, `hornType`, `hipRating`, `buttRating`, `skinType`, `femininity`, `tone`, `thickness`, `tallness`) plus arrays of sub-objects (`cocks[]`, `vaginas[]`, `breastRows[]`, one `ass`). This is verbatim the CoC game's character class, dropped in as the rendering input — the viewer renders *the game's own simulation state*, not a bespoke render schema.
2. **Derived properties** — `CharacterProperties.as` computes render-time scalars: `heightMod = 82 / tallness` (everything scales relative to a canonical 82-unit doll), `masculine = femininity < 50 ? 1 : 0`, `hasBalls/hasVag/hasBigClit`, real (scaled) ball/clit sizes.
3. **Quantizer** — `SaveTranslator.as` maps each *continuous* body value to a small *discrete art index* via hardcoded thresholds (e.g. `getRealCockIndex`: <1→0, <4→1, … ≥27→9; `getRealBoobIndex` has 10 buckets). This is the crux: continuous sim → finite art set.
4. **Class dictionary** — `data/CoC_Dictionary.json` / `TiTS_Dictionary.json` (~25–28 KB each): a nested tree `partType → idx0 → idx1 → idx2 → FlashSymbolClassName`. `ClassDictionary.findPart(type, j, k, l)` resolves indices to a Flash library symbol, instantiates it from an object pool.
5. **Layered assembly** — `BackLayer` / `BodyLayer` / `ShaderLayer` / `FrontLayer` (`classes/character/layers/`). `BodyLayer.drawLayer()` is the recipe: arms, ass, legs, body, head, face, hips, hands, vag, clit, balls, boobs, cocks — each `addPart` resolves an index combo and `addChild`s the symbol in paint order.
6. **Painter** — `PartPainter.as` recolors named sub-segments of each symbol (SkinFill/SkinShade/HairFill/HairShade/BitsFill/BitsShade/EyeFill) via `ColorTransform` offsets. Segment names per part type come from `data/DIC_ChildrenNames.json`.
7. **Shader** — `ShaderLayer.as` applies a Pixel Bender (`filters/AlphaShader.pbj` + `AlphaMixer.pbj`) goo-skin alpha effect over the rasterized body, tweened in.

---

## Character creation / customization

- **Axes** (from `Creature.as` enum comment blocks, the de-facto schema): faceType (0–16: human/horse/dog/cow/shark/cat/lizard/bunny/kangaroo/spider/fox/dragon/raccoon/mouse…), earType (-1–12), hornType, tailType (0–16), wingType (0–12), lowerBody (0–19: hooves/paws/naga/centaur/demonic-heels/goo/pony/drider…), armType, hairType, eyeType, tongueType, skinType (skin/fur/scales/goo). Plus continuous-ish ratings: femininity 0–100, tone, thickness, hipRating, buttRating, tallness, hairLength, beardLength. Plus piercings (8 sites, each with short/long prose). Plus repeated genital arrays (`cocks[]` up to 10, with cockType 0–10 + length; `breastRows[]` up to 4, with rating + nipple length).
- **UI / data model**: the *creator* mode lets you cycle each part. `Character.cycle(partNames, ID, increment)` reads `data/DIC_Cycler.json`, which says *which index to bump* for a given cycle button (e.g. `"hair": {"0":"0,1,0"}` cycles the type index, `{"1":"1,0,0"}` cycles length). So the cycle UI is fully data-driven from a tiny JSON — no per-part button code.
- **Depth**: very deep on *taxonomy of discrete morphs* (dozens of species heads/legs/tails) and on *genital combinatorics* (10 cock types × 9 sizes, 4 breast rows × 10 sizes × nipple length), shallow on *continuous sliders* (only a handful of 0–100 scalars, and even those are quantized to ~5–10 art buckets before rendering).

## Body / transformation / tag system

- **Representation**: a body is the flat `Creature` struct; "parts" are not first-class objects in the data — they're *enum codes* that the renderer turns into Flash symbols. There is no part graph / attachment tree; layering is a hardcoded paint order in `BodyLayer.drawLayer()`.
- **Transformation**: `Creature.as` carries the CoC TF *prose* logic (`modFem`, `modThickness`, `modTone` nudge a 0–100 stat toward a goal by a strength step and emit a flavor string), but the *viewer* doesn't run TF over time — it renders a snapshot. The mechanic worth noting: **gradual stat drift toward a target with bounded steps, gated by perks** (`fixFemininity` clamps femininity into gender-specific bands unless the "Androgyny" perk is held).
- **Tags**: there is no explicit tag system; "tags" are the enum fields + a `perks[]` / `statusAffects[]` / `keyItems[]` array, each a name + up-to-4 numeric values (`PerkClass`, `StatusAffectClass`). Capability checks (`hasPerk`, `perkv1..4`) are linear scans. (Contrast aeriea's `frond` tag system in playmate — this is the *un-systematized* version.)

## NSFW content engine

- CharacterViewer itself has **no scene/act engine** — it's a renderer. But it carries the CoC `Creature` model, which exposes the *body-state surface* a scene engine would consume: genital arrays with type+size, `hasVagina`/`hasCock`/`hasBalls`, fertility/pregnancy state (`knockUp`, `pregnancyType`, `pregnancyIncubation`, ovipositor egg counts). The relevant lesson is the *data shape* CoC/TiTS scenes act × target × this body-state against — multiple genitals as arrays, not booleans.
- **Consent/flow**: none present (renderer). Note this as a gap vs aeriea's consent/flow requirement.

## Prose / text generation

- This is the gem half. `Creature.as` is a **procedural descriptor library**: methods like `face()`, `legs()`, `leg()`, `feet()`, `foot()`, `faceDesc()`, `breastCup()`, `skin()` turn enum state into noun phrases.
- **Two techniques worth stealing**:
  1. **Synonym recombination via RNG**: `face()` for a feline face returns `"muzzle"` / `"feline face"` / `"face"` chosen by `Math.random()` — authored fragment pools selected at call time so repeated descriptions vary. (Determinism cost noted below.)
  2. **Threshold-ladder lexicon**: `breastCup()` is a ~700-line `if (rating < N) return "X-cup"` ladder mapping a continuous rating to a named size word (A-cup → ZZZ-cup → giant descriptions). `faceDesc()` is the same pattern for femininity → prose. This is the "[pc.cockNoun]"-style parser's backend: state → word, but implemented as a giant hardcoded if-ladder rather than a data table.
- **Take for aeriea**: the *idea* (state→phrase via thresholds + RNG synonym pools) is exactly the prose-thread primitive; the *implementation* (700-line if-ladders, `Math.random()` inline) is what to avoid — make the ladder a data table and the synonym pool a seeded draw.

## Animation / visual rendering (the core relevance)

- **Paperdoll, layered, recolored vector art.** Each body part is a Flash `MovieClip` symbol with **named recolor segments**. `DIC_ChildrenNames.json` declares, per part type, which child clips are skin-fill/skin-shade/hair/bits(genital/lip)/eye, e.g. `"face": {"SF":"fillbg","SS":"shading","BF":"lips","BS":"lipsShading","EF":"pupils"}`. `PartPainter.colorSegment` writes a flat RGB via `ColorTransform` offsets (the art is drawn in a neutral key color, tinted at runtime).
- **Color is mostly *derived*, not authored.** `DIC_SkinColor.json` (~30 tones), `DIC_HairColor.json`, `DIC_EyesColor.json` give only the *base* hex. `ColorDictionary` synthesizes the shade color (`shade()`: RGB scaled ~0.7 with a cool bias) and the "bits" (genital) color (HSV s×1.1, v×0.7) from the base — so one authored hex yields a full coordinated palette. Fur (`skinType==1`) tints skin *from hair color* and blends bits halfway. This "author one color, derive the rest by color math" is a strong, low-authoring-cost pattern.
- **Self-shadowing between stacked parts** (`BodyLayer.setPartShadow` / `setDarkPart`): for overlapping boob rows / body, it clones the lower part as a fully-shaded ("dark") version and masks it with the silhouette of the parts above, faking cast shadows from layer overlap. The author's own comment calls it fragile ("Any system could be better, but there are no other systems"; white-pixel and mask-XOR bugs documented inline) — honest signal that ad-hoc paperdoll shadowing is a tar pit.
- **Procedural genital layout**: `addCocks()` randomizes cock order (`ArrayUtils.randomize`), fans them with `Math.random()` rotations and a `1 - 4^(-0.3n)` spread curve, scales each by distance from center. `updateCockIndex()` does a runtime `hitTestPoint` to re-sort the cock layer above/below boobs so it isn't occluded. Clever, but RNG-driven (non-reproducible).
- **Goo shader** (`ShaderLayer.as` + `filters/*.pbj`): rasterize the body to a `BitmapData`, run a Pixel Bender alpha shader to build a mask, blend back with a second shader, fade in via tween. A real-time post-process pass over the assembled doll — the "goo skin" look isn't separate art, it's a shader over the normal art.
- **Graceful degradation** (`ClassDictionary.getDefaultIndexes`): if an `(type, j, k, l)` combo has no art symbol, a per-type "defaulter" (`data/CoC_Defaulter.json`) defines the priority order in which indices collapse to 0 until a defined symbol is found. So the art set can be sparse and the renderer never hard-fails on an unimplemented combo — it falls back to the nearest authored variant. **This is the standout engineering idea** for any combinatorial-asset system.
- **No skeletal animation / no hair physics.** It's a static pose (one standing frame, `standingPoint(150,792)`); the only motion is the goo-shader fade tween and drag-to-move. `TodoGraphics.txt` confirms art is hand-authored per (type × size) variation — e.g. every cock type needs "9 size variations."

## Content / world structure & scale

- No world. Content = the art symbol library inside `DIC.fla` (8.4 MB) + the two dictionary JSONs that index it. Scale is "dozens of part types × a few species/size variants each," all hand-drawn. `Todo.txt` / `TodoGraphics.txt` are the backlog (priority-ranked art requests, code bugs, "mask clipping, as always").
- Dual-game support (CoC + TiTS) is achieved by swapping the dictionary/defaulter/cycler JSON triples and the save-loader — the engine is game-agnostic, the *data* selects the game. Library-from-data, in spirit.

## Determinism / save (the contrast)

- **Input save**: CoC/TiTS Flash `SharedObject` (`.sol`), read field-by-field into `Creature` (`includes/save.as` `loadFromCoCSave` etc.). `.sol` file loading via `FileReference` is marked "Currently not working" in-code — it relied on the browser/Flash sandbox.
- **No seed, no replay, no determinism.** Worse: rendering is *actively* non-deterministic — `Math.random()` drives cock fan layout/rotation, prose synonym choice (`face()`, `legs()`), and `colorPupils("random")`. The same save renders differently each load. For aeriea (determinism is a hard invariant) this is the explicit anti-pattern: **the render/prose layer reaches for global RNG instead of a seeded stream**, so artifacts can't cache/replay/diff.

---

## What aeriea can LEARN

- **Quantize continuous body params to a finite art index at the render seam** (`SaveTranslator`), and keep the index→asset map as *data* (`*_Dictionary.json`), not code. Lets the sim stay continuous while art stays finite.
- **Graceful-degradation defaulter** (`ClassDictionary.getDefaultIndexes` + `*_Defaulter.json`): a per-type priority order for collapsing unsupported index combos to the nearest authored asset. Directly applicable to aeriea's combinatorial body/cosmetic assets — sparse art set, never a hard failure.
- **Author one base color, derive the coordinated palette by color math** (`ColorDictionary.shade`/bits/fur-from-hair). Cuts authoring cost and keeps shade/highlight consistent.
- **Named recolor segments + flat-tint-on-neutral-art** (`DIC_ChildrenNames.json` + `ColorTransform`): art is drawn in a key color; runtime tinting per segment. Cheap, data-driven recoloring.
- **Data-driven part cycling** (`DIC_Cycler.json`): one tiny JSON describes which index each UI control bumps; no per-part button code.
- **Prose = state→phrase via threshold ladders + synonym pools** — the right primitive for aeriea's prose thread; just make the ladder a data table and the synonym draw seeded.
- **Engine game-agnostic, game selected by data triple** (dictionary/defaulter/cycler JSON) — projection-from-data ethos.

## What to AVOID

- **Global `Math.random()` in the render/prose path.** Layout fan, prose synonyms, random eye color — all break reproducibility. aeriea must route every such choice through the seeded timeline.
- **700-line / 1456-line `if`-ladders as lexicons** (`breastCup`, `faceDesc`). Correct idea, wrong encoding — should be a sorted threshold table (data), not source.
- **Ad-hoc layer-overlap self-shadowing via cloned "dark" parts + masks** (`setPartShadow`). The author documents it as buggy and fragile (white pixels, mask XOR). Don't hand-roll 2D cast-shadow faking; use the engine's actual lighting/material system.
- **Flat ~100-field god-struct as the body model** (`Creature.as`) with linear-scan perk/status arrays and no part graph. Fine for a snapshot renderer, poor for a sim that mutates bodies over time — aeriea wants a structured part/tag model (cf. playmate `frond`).
- **Hardcoded paint order + hardcoded positions** (`setBoobPos` magic-number arrays, fixed `standingPoint`). No rig, no pose variation — a dead end for an embodied first-class-VR game.
- **Save coupled to a host sandbox** (`.sol` SharedObject, loader "not working"). Bind the body model to a portable serialization, not an engine/runtime artifact.
