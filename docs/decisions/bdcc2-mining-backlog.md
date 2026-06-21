# BDCC2 → aeriea system-mining backlog (Path A, the NON-embodiment systems)

Status: **BACKLOG — derived read-only from both repos (2026-06-22); not yet
implemented**

Scope: a prioritized backlog of BDCC2's **non-embodiment** sandbox systems to
mine into aeriea **as replaceable surface behind aeriea's OWN seams** (Path A) —
so aeriea is *at least as good as BDCC2 as a sandbox* without being thinner on
table-stakes. This is the **complement** of `bdcc2-integration-plan.md`, which
already covers the embodiment systems (face = extracted, gaze = built-in, body /
locomotion = aeriea-has, skin / clothing = entangled, hair / jiggle = moderate).
Those are **not** re-derived here.

"At least as good as BDCC2" is a **FLOOR, not feature-parity.** Mining is
selective by **fit to aeriea's DESIGN.md**, not by presence in BDCC2. Several
BDCC2 systems are BDCC2-specific (a prison-break BDSM combat sandbox) and are
explicitly flagged **DON'T-FIT** below — copying them would make aeriea *worse*,
not better.

Cross-links:
- `bdcc2-integration-plan.md` — the embodiment-systems sibling plan + the proven
  seam discipline + the `FaceAnimator` extraction template this backlog reuses.
- `DESIGN.md` — the FIT authority. Aeriea = embodied modern-life sandbox, 100%
  immersion, **no combat / no quests / no grind** (DESIGN.md "Things considered
  … rejected"), **deep NPCs with relationships, memory, schedules, moods**
  (DESIGN.md "World agency / inhabitants"), **NSFW-first with SFW as a rendering
  layer** (DESIGN.md "NSFW-first"), **items mechanically meaningful**
  (DESIGN.md "Items as mechanically meaningful").
- `affordance-substrate.md` — aeriea's interaction substrate (interactables /
  verbs / guards / effects / reactions, data-driven). Anything this substrate
  already does is a **SKIP** below.
- `npc-mind-and-language.md`, `prose-generation.md` — the NPC-mind + realizer
  pillar that several of these systems feed.
- `simulation-depth-and-materialization.md` — the simulation-underneath posture
  (deterministic seeded sim) every mined system must respect.

The persistent **Path-A discipline:** the named BDCC2-architecture couplings
that must be cut at every extraction are `GlobalRegistry` (the global singleton
hub), `GM.main.*` (the god-object accessor — `timeManager`, `characterRegistry`,
`pawn_registry`), `BaseCharacter` / `CharacterPawn` (state-in-object locus),
`WeakRef`-to-character back-pointers, and `Network.isServer()` gates. The
`FaceAnimator` cut (push affect *in* via a seam instead of letting the system
*pull* it off a `Doll`) is the template: **invert control so the system is a
pure function of aeriea-owned state, never a puller off BDCC2's locus.**

---

## Prioritized table (ranked by value × clean-extractability × fit)

Columns: **system** / **aeriea-has?** / **value** / **extractability** /
**fit** / **art-dep** / **verdict**.

| # | BDCC2 system | aeriea-has? | value | extractability | fit | art-dep | verdict |
|---|---|---|---|---|---|---|---|
| 1 | **MemorySystem** (per-NPC memory of events: id, decay, mood-effect, priority, stacking) | NO | HIGH (table-stakes for "responsive world"; NPCs that *remember* you) | **CLEAN** (pure RefCounted records + decay math; couplings are `GM.main.timeManager` + `characterRegistry` lookups — replace with aeriea time-source + NPC-id keying) | **FITS** (DESIGN "your actions register / responsiveness"; feeds the realizer) | none (code only) | **MINE-NOW** |
| 2 | **RelationshipSystem** (pairwise affection / lust between any two chars; short-term annoyance; decay; introduced-set) | NO | HIGH (table-stakes for deep NPCs / "ongoing relationships") | **CLEAN-ish** (RefCounted entries + decay; couplings: `GM.GB` balance consts + `characterRegistry` — both swappable to aeriea data) | **FITS** (DESIGN "ongoing relationships," NSFW-first lust channel) | none | **MINE-NOW** |
| 3 | **MoodValues + Mood model** (mood / anger / lust scalar bank aggregated from memories → an affect read) | Partial (`npc_realizer` has `mood`×`rapport` ad hoc; `ExprState` has affect channels) | HIGH (the **bridge**: memory+relationship → affect → already-built expression seam + realizer) | **CLEAN** (small scalar aggregation; this is the glue that makes #1/#2 *show*) | **FITS** (closes the loop to `ExprState` / `apply_expression`) | none | **MINE-NOW** |
| 4 | **TimeManager** (seconds-of-day + day count, day-rollover hook, deterministic accrual) | NO (no time-of-day clock found in scripts/) | HIGH (table-stakes; gates schedules, memory decay, weather, "rhythms") | **CLEAN** (77 lines, self-contained; cut `Network.isServer()` gate; make tick deterministic off aeriea's seeded timeline) | **FITS** (DESIGN "weather, time, seasons … rhythms you fall into") | none | **MINE-NOW** |
| 5 | **ReactionSystem** (data-driven dialogue/line generator: banks of defs + fills + a small embedded expression language: lexer/parser/runner over `%token%` substitution with conditionals) | Partial (aeriea has `npc_realizer.gd` + the realizer pillar; this is a *richer authored-line engine*) | MED-HIGH (authored conversational presence; complements, not replaces, aeriea's realizer) | **MODERATE** (the lexer/parser/runner are self-contained; but it overlaps aeriea's realizer design — **mine the DATA MODEL/ideas, assess the code against `prose-generation.md` before porting**, don't blindly adopt a second text engine) | **PARTIAL** (aeriea already committed to its own realizer; this is reference + possible bank-format mining) | none | **MINE-LATER** (after realizer pillar lands; assess overlap) |
| 6 | **AI goal/action stack** (`PawnAI` + `AIGoalHandler`: goals decompose to actions — Wander, GoTo, Follow, Face, SitAndChill, LeanAndChill, Interaction) | NO (aeriea has movement+interaction substrates but no NPC *autonomy* layer) | MED-HIGH (NPCs "going about their own routines" — DESIGN world-agency) | **MODERATE** (the goal→action decomposition pattern is clean; individual actions are coupled to `CharacterPawn` nav + BDCC2 combat goals. Mine the **architecture pattern + the SFW actions** (Wander/GoTo/Follow/SitAndChill); drop combat/leash goals) | **FITS** (the SFW subset); combat/leash goals **DON'T-FIT** | none | **MINE-LATER** (mine the pattern + SFW actions; selective) |
| 7 | **Buffs/BuffsHolder** (timed/stacking status effects holder attached to a character; items contribute buffs) | NO (closest: interaction `add_fill` / state slots, but no timed status-effect layer) | MED (status/conditions = sandbox depth: tipsy, tired, aroused, cold) | **CLEAN** (BuffsHolder + Buff are small RefCounted; couplings minimal) | **FITS** (modern-life conditions: intoxication, fatigue, arousal — all NSFW-first-relevant) | none | **MINE-LATER** |
| 8 | **Inventory + ItemBase** (per-char inventory, equip slots, items carry buffs + interact-options + descriptions) | Partial (aeriea interaction substrate has grab/carry/sockets + `consume_into_socket`, but **no persistent owned-inventory / equip-slot model**) | MED (DESIGN "items mechanically meaningful"; held props, worn cosmetics) | **MODERATE** (Inventory couples `GM.inventoryRegistry`, signals, `BaseCharacter` ref; ItemBase extends BDCC2 `GenericPart`/`CharOption` chain — needs decoupling from char-part hierarchy) | **PARTIAL** (the *owned-inventory + buff-bearing-item* idea fits; BDCC2's item set is bondage-gear — those are NSFW content, see #14, not the model) | none for model; art for meshes | **MINE-LATER** |
| 9 | **SoundscapeSystem / Audio** (positional ambient soundscape, footsteps, ambient banks) | NO (no audio system found in scripts/) | MED (texture/atmosphere — DESIGN "sonically specific … *feels* like somewhere") | **MODERATE** (Audio.gd + SoundscapeSystem; couplings to BDCC2 world chunks; the *pattern* ports, the SFX are art) | **FITS** (place texture) | **YES** — OpenNSFW SFX/Voice packs carry their own PDF terms; footstep/ambient SFX need their own license; do **not** ship BDCC2 audio assets without sign-off | **MINE-LATER** (mine the system pattern; source own audio) |
| 10 | **Serializer / SAVE / Bins** (typed save/load helpers: `loadVar` with type-checking, binary `Bins`, `SyncState`) | NO (no save system found) but **aeriea's model differs**: deterministic seed + action-log replay (DESIGN architecture) means save = seed+log, not object-graph serialization | LOW-MED (aeriea's persistence is seed+log by design, not state-dump) | N/A | **DOESN'T-FIT (mostly)** — BDCC2 serializes mutable object state; aeriea's invariant is *state derivable from seed+action-log*. The `SAVE.loadVar` type-checking idiom is a tiny nicety, not a system to mine. | none | **SKIP / DON'T-FIT** (aeriea's persistence is architecturally different) |
| 11 | **World / WorldChunk** (spatial chunking to find nearby points-of-interest) | Partial (aeriea has `interaction_world.gd` + regions; `in_region` guard) | LOW (aeriea already locates interactables; chunk POI-query is a perf detail) | CLEAN but low-value | PARTIAL | none | **SKIP** (aeriea's interaction_world covers the need; revisit only if POI-query perf bites) |
| 12 | **Interactable / PawnInteractable / InteractAction** (BDCC2's affordance/verb system on pawns + props) | **YES** | n/a | n/a | n/a | n/a | **SKIP** — this is exactly aeriea's `affordance-substrate` (interactables/verbs/guards/effects/reactions), and aeriea's is **data-driven** where BDCC2's is GDScript subclasses. Aeriea's is the better design here; do not regress to BDCC2's. |
| 13 | **Combat** (CombatMove/Combo/AI, Curves, Moves) | NO | — | clean-ish but irrelevant | **DOESN'T-FIT** — DESIGN.md: "**Not a combat game. Combat is structurally absent.**" | n/a | **DON'T-FIT** (explicitly rejected by DESIGN) |
| 14 | **SexEngine** (1600-line turn-based sex-scene engine: activities, consent/resist/force states, participant AI, dialogue chains, couple-anim system, leash) | NO | MED (DESIGN is NSFW-first; intimacy IS in scope) **but** the *form* is wrong | **DEEPLY ENTANGLED** (the single most entangled non-embodiment system: `Node3D` hub + `AnimScenePlayer` + `CoupleAnimsSystem` + `SexParticipantAI` + `SexType`/`SexActivity` registry tree + camera rig + consent-state machine; couples `GM.main`, the doll, anims, leash). It is BDCC2's `Doll`-equivalent for intimacy — a **Path-B hub**. | **PARTIAL/DOESN'T-FIT-AS-IS** — aeriea wants embodied, immersion-first, continuous intimacy expressed through the *same* body/expression/interaction seams, **not** a separate turn-based menu-driven scene mode (DESIGN "scenes as the core content unit — too shallow"; "100% immersion"). The **force/non-consent** machinery and **leash/bondage** framing are BDCC2-prison-specific. | art (anims, SFX) | **DON'T-FIT AS-IS** (mine *vocabulary/ideas* — activity taxonomy, arousal/affect channels — into aeriea's own continuous-intimacy-through-the-body-seams design; **do not** port the engine. Treat like the `Doll`: reference, not base.) |
| 15 | **LeashSystem** (leashing/dragging a pawn) | NO | LOW | clean-ish | **DOESN'T-FIT** (prison-BDSM-specific control mechanic; no place in a no-coercion-spine modern-life sandbox) | n/a | **DON'T-FIT** |
| 16 | **GameMode / Modes (CharacterCreator, Sandbox)** | **YES** (aeriea has its own `launcher` + scenes: character_creator, test_level, text_sandbox, interaction_sandbox) | — | — | — | — | **SKIP** (aeriea has its own scene/mode structure + its own char creator, per task framing) |
| 17 | **GlobalRegistry / GM / CharacterRegistry / PawnRegistry** (the singleton hubs) | n/a | — | — | **DON'T-FIT (architecture)** — these ARE Path B. aeriea's foundation explicitly refuses the locus/global-singleton model. | n/a | **DON'T-FIT** (never extract; these are the architecture Path A rejects) |

---

## Honest call-outs

- **The four MINE-NOW systems (#1–#4) form one coherent slice**, not four
  independents: **Memory → Relationship → Mood → (existing) ExprState/realizer**,
  all on the **TimeManager** clock. Mining them together lands the single
  biggest sandbox-richness gap aeriea has versus BDCC2 — **NPCs that accumulate
  history with you and visibly + verbally reflect it** — and it terminates in
  seams aeriea *already built* (the expression seam from the integration plan,
  and the realizer). This is the highest-leverage extraction available.

- **Aeriea is AHEAD of BDCC2 on interaction (#12).** BDCC2's interactables are
  GDScript subclasses; aeriea's are serializable data (guards/effects
  vocabulary). Do **not** mine BDCC2's interaction system — that would be a
  regression. This is the clearest case where "floor, not parity" means *don't
  copy*.

- **The SexEngine (#14) is the intimacy analogue of the `Doll` trap.** It is
  NSFW-first-relevant (so it's not DON'T-FIT for *theme*), but its *form* — a
  separate turn-based, menu/consent-state-machine scene mode with its own camera
  rig and participant AI — contradicts DESIGN's 100%-immersion + "scenes-as-core-
  unit is too shallow" stances. Mine its **vocabulary** (activity taxonomy,
  arousal channels) into aeriea's own continuous-intimacy-through-the-body-and-
  interaction-seams design; **do not** port the engine. Its force/leash/bondage
  machinery is BDCC2-prison-specific and DON'T-FIT.

- **Persistence (#10) is architecturally different, not missing.** Aeriea's
  determinism invariant (seed + action-log replay, DESIGN architecture) means
  there is no large mutable object graph to serialize. BDCC2's serializer solves
  a problem aeriea designed away. SKIP.

- **Combat (#13), Leash (#15), and the singleton hubs (#17) are hard
  DON'T-FITs** — the first two by explicit DESIGN rejection, the third because
  it *is* Path B.

---

## Recommended mining ORDER — the next ~5 extractions

The `FaceAnimator` extraction (`bdcc2-integration-plan.md` §6) is the proven
template: bring code in, cut the BDCC2-architecture couplings, invert control so
the system is a pure function of aeriea-owned state, verify deterministically
under xvfb, wire a test suite into `tests/run.sh`.

**0a. (Carry-over, known near-term win) Finish the expression-geometry import.**
The face *rig code* is extracted (`scripts/body/face/`, `expr_state.gd` exist);
the remaining work from the integration plan §3.2 is authoring the **CC0
expression clips on aeriea's MakeHuman head** and re-pointing the blend-tree
clip names. No license blocker (CC0 head). This unblocks *showing* everything
the MINE-NOW affect slice will compute. **Do this first — it's already in flight
and it's the consumer of steps 1–3.**

**0b. (Carry-over, known near-term win) Mine the clean built-in gaze.** Wire
Godot's built-in `LookAtModifier3D` (4.4+, present in aeriea's 4.6) on a
chest→neck→head chain behind aeriea's `set_look_target` seam (integration plan
§3.5). **No BDCC2 code** — it's an engine built-in; BDCC2 only showed the wiring
pattern. Cheap, clean, completes the expression channel.

**1. TimeManager (#4).** The clock everything else hangs on. Extract the 77-line
deterministic seconds-of-day + day-rollover model; cut `Network.isServer()`;
drive accrual from aeriea's seeded timeline so it replays. Smallest, cleanest,
and a hard dependency of memory decay + (future) schedules + weather. Test:
deterministic time accrual + day rollover.

**2. MemorySystem (#1).** Per-NPC memory of events with decay + mood-effect +
priority + stacking. Cut `GM.main.timeManager` → the step-1 aeriea clock; cut
`characterRegistry`/`WeakRef` back-pointers → key memories by aeriea NPC-id;
keep it a pure RefCounted data layer. Test: add memory → decays over the seeded
clock → mood-effect window expires deterministically.

**3. RelationshipSystem + MoodValues (#2 + #3).** Pairwise affection/lust +
short-term annoyance + decay, **aggregated with memory mood into a single affect
read**. Cut `GM.GB` balance consts → aeriea config data; cut registry lookups →
id-keyed entries. This is the glue step: its **output is an `ExprState`** (the
adapter `mood/affection/lust → valence/arousal/tension/attention`). Test: a
greet→compliment→slight sequence moves affection/mood deterministically and
produces the expected `ExprState`.

**4. AI goal/action stack — SFW subset (#6).** The goal→action decomposition
pattern + the SFW actions (Wander, GoTo, Follow, Face, SitAndChill,
LeanAndChill, Interaction). Drop all combat/leash goals. This gives NPCs
*autonomy* — "going about their own routines" (DESIGN world-agency) — on top of
aeriea's existing movement + interaction substrates and the step-1 clock (for
schedules). Cut `CombatPawnAI`, `LeashPawn`, `Obey`; route nav through aeriea's
movement substrate, not `CharacterPawn`. Larger/looser than 1–3; do it after the
memory/relationship/mood core proves the seam discipline on this domain.

After these five, **Buffs (#7)** and a **soundscape pattern (#9, with
own-sourced audio)** are the next-tier MINE-LATER candidates; the **Reaction
System (#5)** and **Inventory model (#8)** wait until the realizer pillar and the
items design (respectively) have landed enough to assess overlap honestly.

---

## Unknowns / flagged (not verified)

- **4.7→4.6 per-API diff not run** for any of these files (same standing caveat
  as the integration plan). The MINE-NOW set (memory/relationship/mood/time) is
  plain RefCounted GDScript + arithmetic — low 4.7-API-surface risk — but any
  4.7-only API surfaces at parse time under `xvfb-run godot4` (the standing CI
  guard). Flag carried, not hand-waved.
- **ReactionSystem ↔ aeriea realizer overlap** not yet resolved — needs a
  head-to-head read against `prose-generation.md` / `npc-mind-and-language.md`
  before any code is ported (hence MINE-LATER, not MINE-NOW).
- **OpenNSFW SFX/Voice PDF terms** not read (binary); any audio mining (#9) must
  source its own assets or read those terms first.
- **BDCC2 Inventory's exact decoupling cost from the `GenericPart`/`CharOption`
  part-hierarchy** estimated from headers, not a full trace — verify before
  committing #8.
- **Whether aeriea's seeded-timeline can host BDCC2's `_physics_process`-driven
  accrual without nondeterminism** — TimeManager ticks off frame delta; aeriea
  must drive it off the deterministic timeline instead (the one real cut in
  step 1). Validate in the step-1 test.
- All verdicts are **read-only assessments**; none of these extractions have been
  executed. The FIT calls lean on DESIGN.md as written (combat/quest/grind
  rejected; deep NPCs / NSFW-first / meaningful items wanted).
