# Deep-dive: Lilith's Throne — the combinatorial sex engine internals

Source: `~/git/liliths-throne` (Innoxia, GPLv3, Java/Swing). All line refs below are
against the working tree at read time (file mtimes 2026-06-22). Package roots:
`src/com/lilithsthrone/game/sex/` and `src/com/lilithsthrone/game/character/body/`.

This is the canonical **"modest typed vocabulary × rich mutable body-state → combinatorial
surface"** engine. The whole thing is built out of a tiny set of enums; the apparent
richness is the *cross product* of those enums, gated by body state, realized through
per-tuple prose. This is exactly the pattern aeriea wants for its NSFW-first embodied sim,
so the precise mechanism matters more than the inventory.

---

## 1. The act-tuple model

### The atomic unit: `SexType`

`game/sex/SexType.java` is the act tuple. It is *three* fields plus an implicit pace
(supplied at render time from the live `Main.sex` state):

```java
// SexType.java:25-27
private SexParticipantType asParticipant;   // NORMAL | SELF (SexParticipantType.java)
private SexAreaInterface  performingSexArea; // the doer's part
private SexAreaInterface  targetedSexArea;   // the receiver's part
```

`equals`/`hashCode` (`SexType.java:44-62`) are defined over
`(asParticipant, performingSexArea, targetedSexArea)` — so a `SexType` is a value, usable
as a map key / set member / cache key. `getReversedSexType()` (`:186`) just swaps
performing↔targeted: the same tuple read from the other participant's POV. This is the
seam aeriea should copy: **the act is data, not a closure.**

Pace is NOT in the tuple. `getPerformanceDescription` (`:113`) pulls pace from global state
at realization time: `Main.sex.getSexPace(performer)` / `...(target)`. The *full*
selection key is therefore the 5-tuple:

```
(asParticipant, performingArea, targetedArea, performerPace, targetPace)   [+ position, +body-state]
```

### The part vocabulary: `SexAreaInterface`

`game/sex/SexAreaInterface.java` (51 lines) is the unifying interface over all body parts
that can participate. Two implementing enums, and that is the *entire* part vocabulary:

- **`SexAreaOrifice`** (`SexAreaOrifice.java`, 142 KB / ~3230 lines) — the receivers.
  Constants: `VAGINA, ANUS, ASS, MOUTH, NIPPLE, NIPPLE_CROTCH, BREAST, BREAST_CROTCH,
  THIGHS, ARMPITS, URETHRA_PENIS, URETHRA_VAGINA, SPINNERET`.
- **`SexAreaPenetration`** (`SexAreaPenetration.java`, 192 KB / ~4060 lines) — the doers.
  Constants (with ctor args): `PENIS(4,-2f,true)`, `CLIT(4,-2f,true)`, `TONGUE(2,0,false)`,
  `FINGER(1,0,false)`, `FOOT(1,0,false)`, `TAIL(2,-1f,true)`, `TENTACLE(3,-1.5f,true)`
  (`SexAreaPenetration.java:17,961,1651,2101,2561,2739,3243`).

The interface (`SexAreaInterface.java:13-51`) is deliberately thin:
`isOrifice()` / `isPenetration()` (a default `!isOrifice()`), `isPlural()`,
`getName(owner, standardName)`, `isFree(owner)`, `getRelatedCoverableArea(owner)`,
`getRelatedInventorySlot(owner)`, and the prose entry point
`getSexDescription(pastTense, performer, performerPace, target, targetPace, targetArea)`.

Key design fact: **~13 orifices × ~7 penetrations ≈ 91 base interactions**, before pace
(6 values: `SexPace.java` — `SUB_RESISTING/NORMAL/EAGER`, `DOM_GENTLE/NORMAL/ROUGH`),
before position, before body-state gating. The vocabulary is tiny; the surface is the
product.

### From tuple to action: `SexAction`

`game/sex/sexActions/SexAction.java` wraps the tuple set into a *player-facing action*.
The core field (`SexAction.java:40-42`):

```java
/** keys = performing character's areas; values = targeted character's areas */
protected Map<SexAreaInterface, SexAreaInterface> sexAreaInteractions;
```

So one `SexAction` is a *set* of simultaneous part-pairings (e.g. double penetration =
two entries). The constructor (`SexAction.java:81-103`) takes
`(SexActionType, ArousalIncrease self, ArousalIncrease target, CorruptionLevel min,
Map<area,area> interactions, SexParticipantType, SexPace)`. Note: **arousal gains,
corruption gate, and the area-pairing map are all plain data on the action** — not code.
`SexActionInterface.java:174-232` derives `getPerformingCharacterOrifices/Penetrations`
and the targeted equivalents by filtering the map on `isOrifice()`.

`SexActionType` (the `START_ONGOING / ONGOING / STOP_ONGOING / POSITIONING / SPEECH /
ORGASM / REQUIRES_EXPOSED / …` enum) classifies *what kind* of action it is and drives
most of the gating in §3.

---

## 2. The 3-axis deformation model (Capacity / Elasticity / Plasticity)

This is the heart of the "rich body-state" half. Each orifice on each character carries a
mutable **stretched capacity** plus two *constant-per-body* deformation parameters. The
three axes are orthogonal and each lives in its own enum:

### Capacity — the current size (mutable state)

`character/body/valueEnums/Capacity.java`. **Measured in cm of diameter** of an object
that fits comfortably (`:13` javadoc). 8 bands, each a `[min,max)` cm range:

```
ZERO_IMPENETRABLE 0–1 · ONE_EXTREMELY_TIGHT 1–2 · TWO_TIGHT 2–4 · THREE_SLIGHTLY_LOOSE 4–6
· FOUR_LOOSE 6–9 · FIVE_ROOMY 9–12 · SIX_STRETCHED_OPEN 12–16 · SEVEN_GAPING 16–25
```
(`Capacity.java:21-80`). The *stored* value is a float (cm); the enum band is looked up
via `getCapacityFromValue(float)` (`:116`). The top 3 bands are `gapeContentRestricted`
and silently collapse to `FOUR_LOOSE`'s descriptor/colour when the gape content pref is
off (`:31-80`) — a clean **content-toggle-as-rendering-layer** pattern.

The two load-bearing fit predicates live here as statics:
- `isPenetrationDiameterTooBig(elasticity, capacity, diameter, lubed)` (`:143`):
  `diameter > capacity * (1.01 + elasticity.sizeTolerance + (lubed?0.10:0))`.
- `isPenetrationDiameterTooSmall(modifiers, capacity, diameter)` (`:131`):
  `diameter <= capacity*0.6` unless the orifice has `MUSCLE_CONTROL`.

So fit is a pure function of `(diameter, capacity, elasticity, lube, modifiers)`.

### Elasticity — resistance to stretching (constant per body)

`valueEnums/OrificeElasticity.java`. 8 bands `ZERO_UNYIELDING`..`SEVEN_ELASTIC`, each
carrying two floats (`:60`):
- `stretchModifier` — **fraction of the over-stretch applied per turn** when fucked too
  big (0.025 → 0.5 across the range, `:18-43`).
- `sizeTolerancePercentage` — base over-capacity tolerated before it's "too big" (feeds
  the `isPenetrationDiameterTooBig` formula above).

### Plasticity — how much stretch is permanent (constant per body)

`valueEnums/OrificePlasticity.java`. 8 bands `ZERO_RUBBERY`..`SEVEN_MOULDABLE`, each
carrying (`:78`):
- `capacityIncreaseModifier` — **fraction of stretch that is permanent** (RUBBERY 0 →
  ACCOMMODATING 0.2 → MALLEABLE 0.6 → MOULDABLE 1.0, `:18-67`).
- `recoveryModifier` — cm/second the orifice recovers toward base when not in use
  (e.g. `2/(60*30f)` = 2 cm per 30 min for `SPRINGY`).

So: **Capacity is the dial that moves; Elasticity sets how fast it moves under load;
Plasticity sets how much of the move sticks.** Three independent axes, each ~8 levels.

### The feedback loop: where capacity actually mutates

`character/GameCharacter.java:10040` — `getStretchDescription(penetrator, diameter,
orificeChar, orifice)`. One `switch(orifice)` with a near-identical block per stretchable
orifice. The vagina block (`GameCharacter.java:10135-10144`):

```java
if(Capacity.isPenetrationDiameterTooBig(
        orificeChar.getVaginaElasticity(),
        orificeChar.getVaginaStretchedCapacity(), diameter, true)) {
    for(int i=0; i<stretchCount; i++) {                 // stretchCount = 5  (:10041)
        orificeChar.incrementVaginaStretchedCapacity(
            Math.max(diameter * 0.05f,                  // minimumStretchPercentage (:10044)
                     (diameter - currentCapacity) * elasticity.getStretchModifier()));
    }
    if(orificeChar.getVaginaStretchedCapacity() > diameter)
        orificeChar.setVaginaStretchedCapacity(diameter); // never exceed the actual object
}
```

Loop reads: each turn, if the inserted **diameter** exceeds the comfortable max, the
stretched-capacity is incremented 5× by `max(5% of diameter, overstretch × elasticity)`,
clamped to the diameter. (`stretchCount=5` is a hand-tuned fudge that the comment
acknowledges simulates ~10 "real" stretches without diminishing-returns math.) Diameter
itself comes from the *penetration* side: `SexAreaPenetration.getDiameter(owner, atLength)`
(`SexAreaPenetration.java:30,4051`), e.g. `owner.getPenisDiameter()`. Permanent retention
and per-tick recovery are applied elsewhere from the Plasticity modifiers.

**The loop closes back onto available acts**: the same `isPenetrationDiameterTooBig` /
`...TooSmall` predicates feed arousal deltas (`SexAreaOrifice` ctor carries
`arousalChangePenetratedStretching / ...TooLoose / ...Dry`,
`SexAreaOrifice.java:3137-3157`) and the per-tuple description switch reads the live
capacity band to pick "stretched open" vs "tight" phrasing. So body-state → fit predicate
→ arousal + which prose branch + (if too big) further deformation → new body-state.

There is a parallel **depth** axis: `OrificeDepth.java` (8 bands, each a `depthModifier`
float 0.5..n) and per-orifice `getMaximumPenetrationDepthComfortable/Uncomfortable`
(`SexAreaOrifice.java:51-57, 3227-3229`), so length-vs-depth is a second fit dimension
alongside diameter-vs-capacity.

---

## 3. How content/text is SELECTED over the tuple

There are **two** selection layers: *which actions are offered* (gating) and *which prose
realizes a chosen tuple* (the description switch).

### Layer A — gating: `SexActionInterface.toResponse()`

`sexActions/SexActionInterface.java:776` is the master availability gate. An action becomes
a player option (`isAddedToAvailableSexActions()`, `:723`) iff `toResponse()` returns
non-null. The gate is a long cascade; the load-bearing checks:

1. **Base/core** (`isBasicCoreRequirementsMet`, `:583-644`): content prefs
   (`isAnalContentEnabled`, `isFootContentEnabled`, `isUdderContentEnabled`,
   `isArmpitContentEnabled` — toggles that *remove tuples from the vocabulary*), pace-dom
   consistency, sadist/loving fetish & affection gates, immobilisation compatibility.
2. **Part availability**: for every area in `sexAreaInteractions`, the part must be
   `isFree(owner)` (not already engaged), `isOrificeTypeExposed/isPenetrationTypeExposed`
   (clothing access), and physically present. `isAbleToAccessParts` (`:666-721`) walks the
   ongoing-actions map to confirm the doer can free its own parts and reach the target's.
3. **Knowledge gate** (`:816-875`): the *player* can't target a partner's vagina/penis/
   nipples until that area `isAreaKnownByCharacter`.
4. **Action-type-specific** (`:907-1168+`): `START_ONGOING` checks the part isn't already
   in use (unless switching), `STOP_ONGOING` checks an ongoing action exists,
   `REQUIRES_EXPOSED` checks clothing, `POSITIONING` checks position-change is allowed.
5. **Position block**: `Main.sex.getPosition().isActionBlocked(performer, target, this)`
   (`:781`) — the position can veto a tuple outright (see §4).

Crucially the gate is **all predicates over (tuple, live body-state, prefs, position)** —
no per-pairing hand-authored allow-list of "valid combinations". Validity *emerges* from
the part being present, free, exposed, known, and content-enabled.

### Layer B — prose: the per-area description switch

`SexType.getPerformanceDescription` (`:113-151`) delegates to
`performingArea.getSexDescription(pastTense, performer, performerPace, target, targetPace,
targetedArea)`. Each enum constant *overrides* `getSexDescription` with a giant nested
switch. Concretely, `SexAreaPenetration.PENIS.getSexDescription`
(`SexAreaPenetration.java:46-…`) and `SexAreaOrifice.VAGINA.getSexDescription`
(`SexAreaOrifice.java:59-…`) both branch:

```
switch on targetArea  (CLIT / PENIS / TONGUE / ...)     // the other part in the tuple
  → if pastTense vs present
    → if isCharacterInanimate(performer) (asleep / doll)
    → else switch(performerPace) { DOM_GENTLE/NORMAL/SUB_*/DOM_ROUGH ; SUB_RESISTING }
      → then switch(targetPace) { ... }                 // the partner's reaction line
```

So the realized text is selected by **(performingArea ⇒ which enum constant) × (targetArea
⇒ outer switch) × (pace ⇒ inner switch) × (tense) × (inanimate flag)**, with body part
*names* spliced in via the `UtilText` parser tags (`[npc.pussy+]`, `[npc.cock+]`,
`[npc.sexPaceVerb]`). The capacity/elasticity descriptors (§2) are pulled into those
strings via `Capacity.getDescriptor()` etc. There is a hard fallback: if the override
returns empty, `getPerformanceDescription` (`:130`) logs an error and emits a generic
`"[npc.Name] used [npc.her] X on [npc2.namePos] Y."` line (`:133-150`).

**This is the anti-pattern to learn from** (see §6): the prose is *hand-authored Java
string-builder code inside each enum constant*, one giant switch per part. It does not
cache, diff, or transport; it is ~330 KB of source across two files; adding a part means
editing every other part's switch. The *tuple model* is clean data; the *realizer* is not.

### Side selections driven by the same tuple

`SexType.getRelatedFetishes(performer, target, isPenetration, isOrgasm)`
(`SexType.java:190-387`) is a second, *pure* selection over the same tuple: a switch on
performing area and a switch on targeted area maps each part to the fetishes it exercises
(`PENIS→FETISH_PENIS_GIVING`, targeted `ANUS→FETISH_ANAL_GIVING`, + deflowering/
impregnation/lactation/masturbation special cases that read body-state like
`characterTargeted.isAssVirgin()` or `getPenisRawStoredCumValue()>0`). This is the good
shape: tuple + body-state → a list of typed effects, as data, no prose.

---

## 4. The position system

`game/sex/positions/`. A position is a set of **slots**; a slot is a posture role a
character occupies; the slot constrains which tuples are legal.

- `positions/slots/SexSlot.java:26-40` — a slot is data:
  `(name, description, orgasmDescription, boolean standing, SexSlotTag... tags)`.
  Concrete slots: `SexSlotAllFours, SexSlotStanding, SexSlotSitting, SexSlotLyingDown,
  SexSlotAgainstWall, SexSlotDesk, SexSlotBreedingStall, SexSlotMilkingStall,
  SexSlotStocks, SexSlotMasturbation, SexSlotGeneric`, plus `SexSlotUnique` for scripted
  scenes.
- `AbstractSexPosition` assembles slots; `SexPosition`/`SexPositionUnique` are the
  registries. `SexSlotManager` registers them.
- The position participates in gating via `position.isActionBlocked(performer, target,
  action)` called from `toResponse()` (`SexActionInterface.java:781`) — e.g. a watching
  spectator slot (`SexSlotGeneric.MISC_WATCHING`) blocks `POSITIONING` actions
  (`:642-643`). Slots also carry per-slot description/orgasm text, so the **position is
  another dimension of the prose-selection key**, not just a gameplay constraint.

Positioning itself is a `SexActionType.POSITIONING` action (`SexAction.baseEffects`,
`SexActionInterface.java:471-477`): NPCs get banned from re-positioning after one move per
phase; ongoing penetrations reset on position change.

---

## 5. The "ongoing action" state machine (why penetration is stateful)

A subtlety that makes the combinatorics tractable: penetrations are not one-shot. They are
**ongoing** — `START_ONGOING` opens a (performerArea → {targetChar → {targetAreas}})
entry in `Main.sex.getOngoingActionsMap(...)`; subsequent `ONGOING` actions advance it;
`STOP_ONGOING` closes it (`SexActionInterface.java:369-511`). `isFree(area)` (the gating
predicate) is literally "this part is not in any ongoing entry". This is what makes
double-penetration, "free up a hand", and "switch which orifice" all fall out of the same
map rather than needing bespoke states. **It is an event-sourced occupancy map**, which is
aeriea-shaped (deterministic, replayable).

---

## 6. Aeriea implications

- **Adopt the value-typed act tuple.** `SexType`'s `(participant, performingArea,
  targetedArea)` + ambient pace, with `equals/hashCode/reverse`, is the right primitive: an
  act is *data*, cache/replay/diff-able, and the reverse-POV view is free. aeriea's tag
  system should expose body parts through one thin `SexAreaInterface`-equivalent so the act
  layer is part-agnostic.
- **Keep the vocabulary tiny; let the surface be the cross product.** ~13×7 parts × 6 paces
  × positions, gated by body-state, yields thousands of distinct realized moments from a
  handful of enums. Resist enumerating "valid combinations"; make validity a *predicate*
  over presence/free/exposed/known/enabled (LT's `toResponse()` cascade) so new parts
  compose automatically.
- **The 3-axis deformation model is directly portable and aeriea-deterministic.** Capacity
  (mutable cm-diameter float, banded for display) / Elasticity (stretch rate) / Plasticity
  (permanent fraction + recovery rate) are orthogonal, each ~8 levels, and the whole loop
  is `f(diameter, capacity, elasticity, lube)` → pure, seedable, replayable. The
  fit predicates (`tooBig`/`tooSmall`) are the join between body-state and *both* arousal
  deltas and prose branch — a clean single source for "what changed and how it reads".
  Mirror this in `frond`/playmate's tag system: a part is `(base, current, axis params)`
  and deformation is a deterministic transition.
- **Split the realizer from the model — and put the prose on the data side.** LT proves the
  tuple/state model and proves the *anti-pattern* of the realizer: ~330 KB of hand-written
  Java switch statements (nested `targetArea × performerPace × targetPace × tense ×
  inanimate`) inside each enum constant. It does not cache/diff/transport, and adding a
  part is O(parts) edits. aeriea's prose realizer should consume the tuple+state as data
  and select text from an *external, diffable* corpus (data over code at the seam), keeping
  the LT-style structured fallback. The fetish-mapping switch (`getRelatedFetishes`) shows
  the right shape when you keep effects as data instead of prose.
- **Content toggles as a rendering/vocabulary layer, not content rewrites.** LT's gape /
  anal / foot / udder / armpit toggles either collapse a Capacity band to a milder
  descriptor (`Capacity.java:31-80`) or drop tuples from the offered set
  (`isBasicCoreRequirementsMet`, `:611-631`). This is exactly aeriea's "NSFW-first with SFW
  toggle = rendering layer": the simulation runs the same; the toggle attenuates
  display/availability. Implement SFW as a vocabulary/descriptor filter over one model.
- **Ongoing-occupancy as an event-sourced map** matches aeriea's deterministic-seeded,
  event-log-replay commitment. Model concurrent engagements as a `(part → occupant)` map
  mutated by logged START/STOP events; `isFree` and double-penetration fall out for free.

## 7. Gotchas / anti-patterns

- **Prose-in-code does not scale and does not serialize.** The two enum files are
  142 KB + 192 KB precisely because every part embeds the full pace×tense×reaction prose
  for every other part. This is the single largest maintenance cost in the engine and the
  thing aeriea must *not* copy. Push the text to data.
- **Global mutable `Main.sex` / `Main.game` singletons.** Pace, control, occupancy, prefs
  are read from global state mid-realization (`getPerformanceDescription` reaches into
  `Main.sex.getSexPace`). Convenient, but it makes a `SexType` *not* self-describing — you
  can't render one without the live world. aeriea should pass an explicit context object
  so realization is a pure function of (tuple, state, ctx).
- **Hand-tuned fudge constants buried in logic.** `stretchCount = 5` with a comment that it
  "simulates ~10 real stretches" (`GameCharacter.java:10041`), `minimumStretchPercentage =
  0.05` (`:10044`), the `*0.6` too-small threshold, `+0.10` lube bonus. These are
  reasonable but undocumented-outside-comments magic numbers; aeriea should hoist such
  tuning into named, data-side parameters so they're diffable and balance-tweakable.
- **O(parts) coupling in the gating switches too.** `getStretchDescription`,
  `getRelatedFetishes`, and `toResponse`'s known-area block all carry an explicit
  `switch(orifice)` / `switch(penetration)` with a `case` per constant. Adding a part means
  touching all of them. aeriea's part interface should carry these behaviors as methods on
  the part (LT does this for `getSexDescription` but not for the stretch/fetish logic),
  collapsing N switches to polymorphism.
- **Capacity clamp hides information.** Stretch is clamped to never exceed the actual
  inserted diameter (`setVaginaStretchedCapacity(diameter)`), which is correct but means
  the model can't represent "stretched beyond what's currently in it" — fine for LT, worth
  a conscious decision in aeriea if you want lingering-gape semantics distinct from
  Plasticity recovery.
