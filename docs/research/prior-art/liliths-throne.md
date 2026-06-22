# Lilith's Throne — prior-art study

Status: studied 2026-06-22 from a full clone at `~/git/liliths-throne` (canonical public repo `github.com/Innoxia/liliths-throne-public`, HEAD `aa8e84a`, verified via `git ls-remote`). Java, ~980 source files.

Scope: prior art for aeriea's NSFW content engine, body/transformation system, and procedural prose. Lilith's Throne (LT) is the *positive exemplar* cited in reference-analysis.md for a dense composable sex engine (act × target × position × body-state). This documents the patterns to learn, the standout gems, and what to avoid. Goal is to LEARN, not adopt — no code is yoinked.

---

## NSFW content engine — the combinatorial core

The reference-analysis claim holds up. LT's sex engine is genuinely compositional, not authored-scene-per-encounter.

- **`SexType` = (participant, performingArea, targetedArea).** `src/com/lilithsthrone/game/sex/SexType.java` is a 3-tuple value object: who you are in the scene (`SexParticipantType`), the body area *doing* the action (`SexAreaInterface`), and the body area *being acted on*. `equals`/`hashCode` over the tuple make sex types first-class keys.
- **Two area kinds implement one interface.** `SexAreaPenetration` (PENIS, CLIT, TONGUE, FINGER, FOOT, TAIL, TENTACLE) and `SexAreaOrifice` (VAGINA, ANUS, ASS, MOUTH, NIPPLE, BREAST, NIPPLE_CROTCH, BREAST_CROTCH, THIGHS, ARMPITS, URETHRA_VAGINA, URETHRA_PENIS, SPINNERET) both implement `SexAreaInterface`. The Cartesian product of penetrator × orifice *is* the act space.
- **Acts are static `SexAction` objects grouped by area-pair file.** `src/com/lilithsthrone/game/sex/sexActions/baseActions/` has 54 files named by the pair (`ClitAnus.java`, `FingerBreasts.java`, …). Across all of `sexActions/` there are **1349 `public static final SexAction` definitions**. Each `SexAction` carries a `SexActionType` gate, a `getDescription()` returning parser-tagged prose, and `applyEffects()`.
- **Availability is gated declaratively.** `SexActionType` (`src/.../sexActions/SexActionType.java`) enumerates requirements like `REQUIRES_EXPOSED`, `REQUIRES_NO_PENETRATION`, `REQUIRES_NO_PENETRATION_AND_EXPOSED`, plus lifecycle tags `START_ONGOING` / `ONGOING` / `STOP_ONGOING` / `ORGASM` / `ORGASM_DENIAL` / `SPEECH`. The engine filters the 1349 acts down to what is currently valid given exposure, positioning, and ongoing-action state.
- **Pace as an orthogonal axis.** `SexPace` = SUB_RESISTING / SUB_NORMAL / SUB_EAGER / DOM_GENTLE / DOM_NORMAL / DOM_ROUGH. Each act typically has gentle/normal/rough dom variants (see `ClitAnus.CLIT_FUCKING_DOM_GENTLE/NORMAL/ROUGH`), so prose and effects shift with intensity and consent posture.
- **Positions & managers are separate layers.** `sex/positions/` (slots, `AbstractSexPosition`) constrains which areas can reach which; `sex/managers/` (`SexManagerDefault`, dominion/submission/universal variants) drive scene flow and NPC behaviour. Position + pace + area-pair + body-state are the four composable axes — exactly the act×target×position×body-state the reference-analysis named.

Consent/flow is modeled as the dom/sub pace axis plus `SubControlLevel` and resistance, not a separate consent gate — i.e. consent is *expressed through* the pace/control state machine rather than a yes/no precondition.

## Body / transformation / tag system

- **`Body` is a flat struct of typed parts.** `src/.../character/body/Body.java`: arm, ass, breast, face, eye, ear, hair, leg, torso, antenna, breastCrotch, horn, penis, tail, tentacle, vagina, wing, spinneret, plus `bodyMaterial`, `genitalArrangement`, `pubicHair`, and a `coverings` map. Built via a `BodyBuilder`.
- **Parts carry rich quantitative state, not just a type.** `Vagina(type, labiaSize, clitSize, clitGirth, wetness, capacity, depth, elasticity, plasticity, virgin)` — 10 args. `Penis(type, length, usePenisSizePreference, girth, testicleSize, cumProduction, testicleCount)`. The "what kind" (`AbstractVaginaType`) is one field; the rest is continuous physical state.
- **GEM — orifices physically and *persistently* deform with use.** Three distinct value enums (`character/body/valueEnums/`): `Capacity` (current diameter, documented as "cm of diameter of a penetrative object which could fit comfortably" — ZERO_IMPENETRABLE → FIVE_ROOMY+), `OrificeElasticity` (how strongly it resists stretching), and `OrificePlasticity` (how permanently a stretch persists vs. snaps back). Capacity changes during sex; elasticity/plasticity govern whether the change is temporary or lasting. The body has *history* — a sandbox-systemic property, not cosmetic.
- **Type system is data-driven & moddable.** `body/abstractTypes/` + 26 `*Type.java` files in `body/types/`; abstract types are loadable so external mod XML can add races/parts. `body/tags/BodyPartTag.java` tags parts for behaviour.
- **Race/subspecies derived from the part mix.** `subspecies`, `raceStage`, `raceWeightMap`, half-demon overrides — identity is computed from the body, and transformation (changing parts) re-derives it. 15 races.
- **Customization depth.** `CharacterModificationUtils.java` is **6935 lines**; `CharacterCreation.java` is 2218. Editable axes include Hair (length/style), Eyes, Face, Lips, Ears, Horns (+ rows-per-row counts), Skin, Breasts, Nipples, Penis (length/girth/modifiers), Vagina (capacity/depth/elasticity/plasticity/wetness/modifiers), Ass, Height, Wings, Tail (count/length/girth), Antennae, Tongue, Genital Arrangement, Body Hair, Fluids. 76 fetishes (`fetishes/Fetish.java`) as a preference/affinity layer.

## Prose / text generation — the parser

This is the most directly transferable system for aeriea's prose thread.

- **A single templating parser over authored fragments.** `src/com/lilithsthrone/game/dialogue/utils/UtilText.java` is **11203 lines** and the heart of text generation. Prose is authored with inline tags resolved against character state at render time.
- **Tag grammar: `[target.command(arg)]` with modifiers.** Targets are `npc`, `npc2`, `pc`, … (`ParserTarget`). Commands resolve to pronouns, names, verbs, and body-part nouns:
  - Pronouns/possessives: `[npc.her]`, `[npc.herHim]`, `[npc.she]`, capitalised `[npc.Name]`.
  - **Auto-conjugated verbs**: `[npc.verb(let)]`, `[npc2.verb(start)]` conjugate to person/number (player = 2nd person, NPC = 3rd). LT inverts player↔npc targets when the player is speaking (`UtilText` line ~486).
  - **Body-part nouns with descriptor expansion**: `[npc.cock]` vs `[npc.cock+]` — the `+` pulls in adjectives derived from that part's *current state* (size/girth/material). `[npc.pussy+]`, `[npc.asshole+]`, `[npc.lips+]` are pervasive in sex prose.
  - Convenience verbs that read scene state: `[npc.moan]`, `[npc.sexPaceVerb]` (verb varies by current `SexPace`).
- **Commands are registered objects keyed by body part.** `ParserCommand` (`dialogue/utils/ParserCommand.java`) holds tags, capitalisation/pronoun flags, an `arguments` example, a `description`, and a `relatedBodyPart`. `commandsMap: Map<BodyPartType, List<ParserCommand>>` (`UtilText` line 1509) registers ~hundreds of commands, each closing over how to render that concept from `GameCharacter` state.
- **The flow is: authored prose fragment → parser → state-resolved sentence.** Body-state (capacity/wetness/material) flows into the *adjectives* via the `+` suffix, so the same authored line reads differently for a tight virgin vs. a stretched-out partner without per-state authoring. This is the recombination-of-authored-fragments approach, not full procedural generation — fragments are human-written; only substitution/conjugation/descriptor-selection is automated.

## Animation / visual

- Minimal. `src/com/lilithsthrone/rendering/` has `RenderingEngine`, `SVGImages`, `Pattern`, `Artwork`, `Artist`, `ImageCache`, `CachedImage`, `CachedGif`. UI is **JavaFX WebView rendering HTML/CSS** (`res/fxml`, `res/css`); character "art" is per-artist static SVG/PNG selected by subspecies, recoloured via `Pattern`/SVG colour substitution. No paperdoll composition, no skeletal animation, no hair physics. The richness is entirely in *text + data*, not visuals. For aeriea (a 3D embodied engine) the visual layer has no reuse value; the lesson is the *opposite direction* — LT proves how far state-driven text alone carries immersion.

## Content / world structure & scale

- Content is **code-as-content**: scenes, acts, dialogue nodes, and item/clothing definitions are largely Java `static final` objects, with XML for moddable types (races, clothing, outfits, encounters under `res/`). World in `world/places` + `world/population`.
- Scale signal: 1349 sex actions, 6935-line char editor, 11203-line parser, 76 fetishes, 15 races, 26 part types. Enormous authored surface — the combinatorics multiply authored fragments, they don't replace authoring.

## Determinism / save — the contrast (important for aeriea)

- **No determinism.** `src/com/lilithsthrone/utils/Util.java` line 56: `public static Random random = new Random();` (unseeded) and bare `Math.random()` used throughout (237 files touch RNG). There is no seed, no action log, no replay.
- **Save = full XML serialization of the live object graph.** `saveAsXML`/`loadFromXML` implemented on ~171 character-package classes, with explicit version-migration branches (e.g. `SexType.loadFromXML` special-cases pre-0.3.7.6 saves). State is the source of truth; you cannot reconstruct a session from seed+inputs.
- This is the direct counter-example to aeriea's "deterministic seeded simulation / event-log replay" invariant. LT shows the *content density* is achievable without determinism — but also shows the cost: brittle versioned save-migration, no replay, no reproducible bug repro.

---

## What aeriea can LEARN

1. **Model the act space as a typed tuple over a part-area interface, not as authored scenes.** `(participant, performingArea, targetedArea) × position × pace` is a clean, extensible product. Aeriea can keep this shape but make the act *data* (serializable AST) rather than 1349 `static final` Java objects — aligning with the data-over-code seam principle.
2. **Give body parts persistent physical state with separate "current / resistance / permanence" axes.** Capacity vs Elasticity vs Plasticity is a genuinely good model: the body accumulates history systemically. Reusable far beyond NSFW (any deformable/wearing system).
3. **A descriptor-suffix parser (`[part+]`) that pulls adjectives from live state** is the high-leverage prose pattern: author one fragment, render N body-states. Aeriea's prose thread should adopt the *separation of authored fragment vs. state-driven substitution/conjugation/descriptor-selection*, ideally with the templates as data and conjugation rules as a small typed grammar.
4. **Declarative availability gating** (`REQUIRES_EXPOSED`, ongoing-lifecycle tags) keeps the combinatorial menu coherent — a good pattern for any large systemic action set.
5. **Consent/intensity as a pace state machine** (sub-resisting → dom-rough) folds consent into systemic state instead of a modal gate — fits an immersion-first sandbox.

## What to AVOID

1. **Code-as-content at this scale.** 1349 hand-authored Java action objects + an 11k-line parser file + 6.9k-line editor are unmaintainable and unmoddable-by-data. Aeriea should push these to faithful serialized data (acts, prose templates, body schemas) per the data-over-code principle.
2. **Unseeded RNG and live-object-graph saves.** Directly violates aeriea's determinism invariant; produces brittle version-migration code (the pre-0.3.7.6 branches) and no replay/repro. Aeriea keeps seed + action log.
3. **Parser-as-string-substitution in one giant file.** Powerful but a monolith; the conjugation/descriptor logic deserves a real typed grammar, not 11k lines of special cases (note the player↔npc target-inversion hack at line ~486).
4. **Coupling identity to a hard-coded race enum + part-weight heuristics.** Workable but rigid; aeriea's tag/frond approach (cf. `playmate`) is a more composable way to derive identity from parts.
5. **Visual layer has zero reuse** for a 3D engine — don't mine it.

## Files worth remembering

- `src/com/lilithsthrone/game/sex/SexType.java` — the (participant, perform, target) tuple.
- `src/com/lilithsthrone/game/sex/SexAreaOrifice.java` / `SexAreaPenetration.java` — the area interface + descriptor methods.
- `src/com/lilithsthrone/game/sex/sexActions/baseActions/ClitAnus.java` — exemplar act file (gate + pace variants + parser prose).
- `src/com/lilithsthrone/game/sex/sexActions/SexActionType.java`, `SexPace.java` — the gating & intensity axes.
- `src/com/lilithsthrone/game/character/body/Body.java`, `Vagina.java`, `Penis.java` — the part struct + quantitative state.
- `src/com/lilithsthrone/game/character/body/valueEnums/{Capacity,OrificeElasticity,OrificePlasticity,Wetness}.java` — the deformation model.
- `src/com/lilithsthrone/game/dialogue/utils/UtilText.java` + `ParserCommand.java` + `ParserTarget.java` — the prose parser.
- `src/com/lilithsthrone/game/dialogue/utils/CharacterModificationUtils.java` — the customization axes.
- `src/com/lilithsthrone/utils/Util.java` (L56) — the unseeded `Random` (determinism contrast).
