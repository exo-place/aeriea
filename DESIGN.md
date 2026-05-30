# DESIGN (draft)

Working design doc for an unnamed project. Captures what's been
decided so far, what's still open, and what is explicitly *not* in
scope.

Status: pre-scaffolding. Engine likely Godot or Bevy via
[godogen](https://github.com/htdt/godogen).

## What this is

**A place to be.**

**The single non-negotiable goal: 100% immersion.**

Every design decision is evaluated against one test: does this preserve,
or break, the player's immersion? Any break — animation snapping, audio
mis-spatializing, NPC dialogue feeling robotic, UI overlay breaking the
spell, a clipping garment, a mistimed viseme, a glitched hand grasp —
fails the test. The "extra" framing (sometimes phrased "110%
commitment") is rhetorical emphasis on uncompromising posture: we don't
ship at 95% if 100% is what the design requires. Reality-grade
immersion in the moments that matter, with zero copouts.

Every other design decision in this doc — no combat, no grind, no quest
markers, deep customization, mirrors, parkour 2.0, KIM-grade NPCs,
world agency, NSFW-first, animation/physics quality — falls out of
this. See *Systems that compose 100% immersion* later for the concrete
~45-system enumeration of what this commitment touches.

Not a game to play. Not a content treadmill. Not a TiTS-with-movement
or a Warframe-without-combat. A *place* — somewhere worth being in,
where you spend time, where you exist. The mechanics serve the place;
they're not the point.

The lineage of "place, not game" includes the best moments of every
great MMO (old WoW, FFXIV housing, Warframe relays, Second Life,
ChatMUD) and the best moments of contemplative-experiential games
(AER, Sable, Sky). What those references *lack* — and what this
project provides — is full synthesis: the depth and variety of a
Warframe-grade sandbox, the customization and identity-fluidity of a
TiTS/FS-grade character system, the embodied movement of a parkour 2.0
game, the cosmetic investment of fashion-frame culture, all in
service of *being-in-a-place*.

## What makes a place worth being in

These are the qualities the project commits to. Anything that
contributes is in scope; anything that doesn't, defer.

- **Texture** — visually/sonically/tonally specific. It *feels* like
  somewhere, not a level.
- **Change** — weather, time, seasons, events; not static. (See
  *Sources of change* below — this is structurally load-bearing.)
- **Inhabitants** — other beings (NPCs, players, animals) give it
  presence and make it feel alive.
- **Many ways of being** — you can hang out, move fluently, socialize,
  curate your look, explore, be alone, do nothing. No single "right
  way" to be there.
- **Corners** — specific places within the place that feel like
  themselves: a particular vista, a particular hangout, a particular
  ruin. Not generic terrain.
- **Safety** — no threats forcing your hand. You're not on a clock,
  not at risk, not being chased.
- **Responsiveness** — your actions register. The world acknowledges
  that you were there.
- **Depth** — enough variety/detail that real time spent doesn't
  exhaust it.
- **Rhythms** — rituals and cycles you can fall into. Daily, seasonal,
  ad-hoc.
- **Habitability** — you can make a home in it. Persistent personal
  space, accumulated stuff, your spot.

## What it is *not*

Non-negotiable refusals. Listed to keep future scope creep honest.

- **Not a combat game.** Combat is structurally absent. The player's
  vocabulary does not include violence. No combat-as-spine; no
  combat-as-side-content either.
- **Not a quest-driven game.** No quest markers, no fetch chains, no
  scripted objective sequences as the primary content.
- **Not a quantity-gated grinder.** No "mine 1000 of X to unlock Y."
  No tradeskill XP bars. Quantity-of-identical-actions as a
  progression mechanism is the failure mode being refused.
- **Not a metroidvania.** Verbs are not gated to re-open the world.
- **Not a designed-answers platformer.** Geometry doesn't have one
  correct line; many lines are valid.
- **Not a finite narrative experience.** AER / Feather / Sable run
  out. The substrate must carry replay; developer-authored content
  treadmills will not.
- **Not a passive / contemplative experience.** The experiential
  posture does *not* mean walking-sim engagement. The player is active
  — moving fluently, expressing themselves, interacting richly.

## Core values

The qualities the design must honor even when inconvenient.

### Active experiential posture

Experience over game. No objectives, no win state, no fail state, no
progression-as-gate. The doing is the doing. You're not chasing
anything.

But *active*, not passive: Warframe-grade verb density, Ultrakill-grade
moveset fluency, returnable mastery of how you move and present. The
experience is *lived*, not *watched*.

### Variety of power fantasies

The Warframe lesson. Most games offer one power fantasy per class
(variations on damage / tank / heal). Warframe offers dozens of
*distinct flavors* of feeling powerful, and you choose which to
inhabit based on mood.

This project does the same with non-combat fantasies — each vessel /
form / build delivers a fundamentally different flavor of
*being-in-the-world*. The long-term hook isn't optimization of one
build; it's trying the next thing.

Currently committed (in priority order):

1. **Movement** — parkour 2.0 fluency. Embodied, weighty, composable.
2. **Cosmetics** — fashion-frame depth. Looking sick is endgame.
3. **Rich worldbuilding / NPCs** — being-in-a-world-with-characters
   that have presence and individual depth (TiTS/KIM-grade).
4. **Variety itself** (meta) — the *act of choosing which mode to
   inhabit today* is its own power fantasy. Warframe's lesson is that
   waking up and deciding "today I want to feel like X" with many real
   options is distinctly satisfying. The variety isn't just a means to
   per-mode power; it's its own pleasure.
5. **Lived history** — your timeline-tree as accumulated trajectory.
   Deterministic seeded simulation + branching (see *Architecture
   commitments*) makes your past a first-class object you can inhabit,
   explore, and branch from. Git-for-yourself; the empowerment of
   being able to see and re-enter your own arc, not just one
   continuous line. Rare and distinct — most games only give you
   one save-slot's worth of "you."

The list will grow as more concrete fantasies are committed, but
these five are the foundation.

### Cosmetic depth / fanservice

Not the spine, but a major value. The project invests in cosmetics at
Warframe scale — Tennogen-grade visual depth, not "pick a colour
swatch." Combined with the TiTS/FS lineage, "cosmetic" extends past
outfits to **the body itself** — forms, transformations, species,
presentation all on the customization surface.

The cosmetic *economy* (browsing, shopping, acquiring, curating drip)
is itself a real activity, not an afterthought. Resonite/NeosVR
notably lack this even though they have user-imported assets.

**Live expressive system, not static loadouts.** VRChat-style
toggles, sliders, and items are core, not nice-to-have:

- **Toggles** — avatar components you switch on/off live during play
  (show/hide hat, wings, particle effects, accessories, glow).
- **Sliders** — continuous parameters adjusted in-play, not just at
  chargen (feature size, color, glow intensity, expression, body
  proportions).
- **Items** — holdable / wieldable props you pull out (drinks, cigs,
  plushies, instruments, signs, flowers, toys), often interactive
  with other players (give a flower, share a smoke, hand someone a
  sign). Each item is a tiny social-interaction primitive and a
  small individually-authorable piece of content.

This is distinct from Warframe-style appearance slots (which are
session-level loadout swaps) and from static cosmetic curation. It's
a *live moment-to-moment expression surface*. Items also become a
content type the community can author at scale (huge content
multiplier for density-of-available-content).

**Positioning vs VRChat and Warframe**: Warframe is *gamey but less
personal* — high curation, low personal-expression depth. VRChat is
*personal but uncurated* — high personal-expression, wild-west
quality. The project aims for **more structured and curated than
VRChat, more personal than Warframe** — curated authorship surface
(quality bar, moderation) with deep personal expression within it.
Community items/avatars exist but pass through a quality gate; the
default-shipped experience feels intentional, not chaotic.

**Mirrors are foundational, not a nice-to-have.** In first-person /
VR with heavy avatar/body investment, the player literally cannot see
themselves otherwise. Mirrors are the entire feedback loop for
cosmetic curation, body expression, embodiment-checking, and
self-appreciation. Without good mirrors, all the cosmetic / body
investment is invisible to the player themselves — they spent hours
making the avatar but only see other people / can't appreciate their
own work. That's the failure mode mirrors prevent.

Practically:
- **Mirrors throughout the world** — bathrooms, bedrooms, hallways,
  fitting rooms, dance floors, gym walls, public spaces. Built into
  the architecture, not optional props.
- **Diegetic integration with body/cosmetic UI** — looking in a
  mirror is the natural way to access wardrobe / transformation /
  slider UI. The mirror IS the interface.
- **Ambient reflections** — windows, polished surfaces, puddles, so
  you catch yourself even outside dedicated mirror moments.
- **Selfie / photo mode** — taking pictures of yourself / scenes
  with you in them as a real activity.
- **Real-time planar reflection** rather than cubemap fakes. Quest
  standalone budget is tight but feasible at lower res / selective
  quality.

### Movement that doesn't waste your time

Palia's failure: cozy life-sim activities are fine, but the player is
slow and the world is huge, so 90% of the session is commute.
Refusal: the player must move *fluently* so traversal is a pleasure,
not a tax.

- **Parkour 2.0** is the love. Mirror's Edge / Dying Light /
  Ghostrunner — negotiation with real geometry, embodied weight,
  momentum that matters.
- **Carving / momentum feel** (Redout 2). Control surface composes;
  every input modifies every other input; velocity preserved across
  inputs.
- **Compositional verb vocabulary** (Hollow Knight). Small clean
  primitives; the depth is in chains; mastery is real and felt.

### Character investment that lasts

The reason Warframe sticks and AER/Feather/Sable don't: you're
*building something* — a character, a loadout, a presence that
accumulates over hundreds of hours. The project provides this without
leaning on grind/quantity-gates.

### World agency

A place to be is empty if the player is the only agent in it. NPCs
texting you (KIM), NPCs going about their own routines, weather
shifting, ephemeral events happening, the cadence of the town moving
regardless of whether you engage — these are what make the place feel
*populated* rather than just *contented*. The world is *up to things*,
and the player is one agent among many, not the sole driver.

Practically: NPCs have their own state (simulation-driven, optionally
LLM-driven), schedules, moods, lives that proceed in your absence and
sometimes reach toward you. Events happen on the world's clock, not
the player's. Weather, time, seasons drive their own changes.
`existence`-style state simulation extended to inhabitants, plus
`fuwafuwa`/`ashwren` patterns for autonomous-presence behavior.

### Density of available content, not forced cadence

The design property is **how much there is to encounter in the
world**, not **how often the world delivers content at you**. Push
cadence is annoying; pull availability is the goal. The player sets
their own engagement rate.

Practically: the world is packed with small varied things to find —
NPC moments, micro-events, situations, easter eggs,
microinteractions, optional details — but nothing is forced on a
schedule. You wander into them by being-in-the-place at your pace.
Animal Crossing minus its scheduled-event-pushing; BotW shrines
without the markers; Stardew when you ignore quest markers. The
village/world is *dense*, not *demanding*.

This complements *World agency*: world agency is about NPCs/events
acting on their own; density-of-available-content is about there
being *lots of stuff* for the player to find regardless. Together
they make the place feel inhabited and worth exploring.

### Sandbox openness

Higher-level genre. Open-ended, no win state, the game doesn't push
you down a track. You log in and decide what to do today.

### Platform for depth

"Rich worldbuilding / NPCs" only materializes if the structure
*accommodates* depth — most games can't have deeply realized
characters or places because NPCs exist for functional purposes
(quest giver, vendor, lore drop), and locations are static stages.
The Warframe KIM observation: the parts of the game with the most
care/effort are the parts that have a structural *space* for it.

The project's platform-for-depth is a layered approach, drawing on
real prior art:

- **Authored content** is essential. NPCs with written personalities,
  places with designed character, dialogue and prose that someone
  actually wrote. Cannot be replaced by simulation or generation.
- **Simulation underneath rendering on top** — pattern from
  `existence`. Deterministic state simulation (mood, weather, time,
  relationships, body, history, etc.) drives how authored surfaces
  are rendered. Same NPC reads differently across moods; same plaza
  feels different across times of day or weather; same activity has
  different texture based on player state. Depth = the gap between
  hidden simulation and rendered surface.
- **Procedural recombination** — pattern from HHS+, Accidental
  Woman, Lilith's Throne. Authored fragments + simulation state +
  generative composition = many more rendered scenes/encounters
  than any one author could write.
- **LLM-compatible but not LLM-required** — local LLM viability and
  the controversy around LLMs are both unsettled. Build the depth
  substrate to stand on its own using proven patterns (simulation +
  authoring + procedural), but design interfaces so LLM-driven
  characters or LLM-augmented systems can slot in later. Don't
  foreclose; don't depend on what isn't viable yet.

General principle: **don't commit to architectures that preclude
future approaches, don't depend on tech that isn't viable yet.**
Keep things composable, modal, additive.

## Sources of change

Experiences without change are finite. Even an active, verb-dense,
well-built place exhausts itself if nothing in it ever shifts. So
change is structurally required — not as a content treadmill, but as
ongoing evolution of player, world, content, community, or all.

- **Player-side change** — accumulating investment: cosmetic library,
  learned movement style, evolving presentation, built relationships,
  personal history.
- **Content-side change** — Warframe-cadence cosmetic and vessel
  drops; new looks, new forms, new things to acquire and try.
- **World-side change** — weather, day/night, seasons, ephemeral
  events; the world differs when you return.
- **Social-side change** *(if multiplayer)* — other players, community
  drift, culture evolving around the shared space.
- **Procedural / generative change** *(if scope allows)* —
  algorithmic novelty so revisited places have variation.

Open: which sources the project leans on hardest.

## Architecture commitments

### Deterministic seeded simulation

Following `existence`: all simulation state is derivable from `seed +
action log`. No nondeterministic RNG sources outside the seeded
timeline; no background mutating state outside the simulation. Save
format = seed + ordered action log.

This enables:
- **Replay / sharing**: send seed + action log, recipient runs it
  against their game and gets the same world.
- **Timeline branching**: from any point in the log, branch to an
  alternate; git-for-game-state. Save-scumming as a first-class
  feature; lived-history as a literal tree, not a line.
- **Speedrun / leaderboard substrate**: action logs are the proof.
  Verification = re-run + plausibility check on inputs (Trackmania
  precedent: server-side replay re-sim catches log forgery;
  client-side input-attestation à la TMCP catches input forgery).
  Communities choose their own anti-cheat posture.
- **Reconnect via snapshot** (not replay): rejoining clients just
  pull the current world state from the server. Action log is for
  sharing and leaderboards, not for live reconnect.

Constraints this imposes:
- No client-side gameplay state that affects outcomes.
- Float determinism is hard across platforms; commit to fixed-point
  for the sim layer, or accept that replay validity is bounded by
  runtime (Trackmania accepts the latter — fine for our case).
- All sources of variability (NPCs, weather, time-of-day, events)
  derive from the seeded timeline.

### Platforms and presentation

**Cross-platform from the start**: flat (KB+M / gamepad) + PCVR +
Quest standalone (and equivalent mobile-class standalone VR).

VR (especially Quest standalone) is first-class, not an afterthought.
Rationale: the kind of game this is (embodied presence,
self-expression, social being-with) is exactly what VR is *for*.
VRChat shows the upside; the gap is in the structured/curated/game
parts that VRChat doesn't deliver, which is what we're filling.

**Diegetic UI** — menus live on the body or in the world, not as
screen overlays. Wrist menus, palm panels, in-world objects. Works
for both VR (proprioceptive — your hands know where your wrists are)
and flat (rendered as on-body UI, controlled differently). No
abstract HUD layer.

**Multiple radial menus** (Warframe gear-wheel / emote-wheel
pattern): one wheel doesn't scale; many specialized wheels do. Maps
naturally to per-controller buttons in VR, modifier-keys + wheel on
flat.

**Items physically held in hand** (VR), or carried diegetically
(flat). Pulling out an instrument is a physical gesture, not a menu
selection.

**Face tracking and visemes**:
- Visemes (lip-sync) are table stakes for NPCs feeling alive. Player
  avatar lip-sync from voice/TTS keeps social presence intact.
- Face tracking when available (Quest Pro, Vision Pro, Pico 4 Pro);
  fall back to AI-driven expression from voice tone + emotional
  state when not.
- NPC facial expressions driven by simulated mood/state (`existence`
  pattern extended). Reactions legible without dialogue.
- Avatars need rigged faces (ARKit blendshapes or similar) —
  significant art-pipeline commitment, but the payoff (avatars that
  feel alive rather than mannequin-with-voice) is essential to the
  game's premise.

**VR comfort**: configurable. Teleport, snap turn, smooth-with-vignette,
full smooth. Most players adapt to smooth movement within a day;
some don't. Defaults forgiving, options available.

**Performance budget**: Quest standalone is mobile-class
(Snapdragon XR2). Polycount, shaders, simulation tick rate all
constrained. Deep-sim layer must be efficient enough to run on
mobile, or degrade gracefully on weaker platforms.

**Cross-platform parity**: a flat player and a VR player on the same
server must see each other and play together. Avatar/animation
systems must work for both. Avoid VR-exclusive content; offer
gracefully-translated equivalents for flat.

### Netcode (self-hosted multiplayer)

**Mix by responsibility** — different parts of the state use different
protocols. This is normal modern multiplayer architecture, just
explicit:

- **Client-side prediction** for own character movement. Parkour 2.0
  has to feel responsive; no waiting on server round-trip for your
  own jump.
- **Server-authoritative** for shared world state (NPC state, place
  state, item state, persistent changes).
- **Deterministic lockstep** for the seeded sim layer. NPCs / weather
  / time all derive from server seed + ordered input log; clients
  run the same sim and stay in sync.
- **Eventually consistent** for non-critical state (cosmetic changes
  others see, KIM messages, presence indicators).

**Not mix-by-connection** — all clients use the same protocols.
Per-client model selection forces the server into worst-case
guarantees for all clients and isn't worth the complexity.

Latency budget: with no PvP combat, 100–200ms is fine. The worst case
(two players doing synced parkour together) doesn't need
frame-perfect sync. State size and bandwidth: delta-compress
aggressively, only send what changed.

## Reference set

What each reference contributes.

- **Warframe** — variety of power fantasies, fanservice/cosmetic
  investment, persistent character, "yes-and" sampler structure,
  hub-as-place.
- **Trials in Tainted Space**, **Flexible Survival** — deep character
  customization and transformation; body as customization surface;
  identity fluidity; rich individual-NPC content.
- **HHS+**, **Accidental Woman**, **Lilith's Throne** — life-sim
  sandbox structure with deep simulation, heavy authoring, and
  procedural recombination. Proven pattern for delivering hundreds of
  hours of content without LLMs.
- **`existence`** (our own prior art) — simulation-underneath
  rendering-on-top pattern; deterministic state drives generative
  surface; ~67k LOC of working code demonstrating the architecture.
  Power-anti-fantasy in posture (opposite of this project), but the
  *structural* lessons carry.
- **ChatMUD** — persistent textual world as a place; hangout-as-content;
  built on a programmable substrate (MOO-lineage).
- **Redout 2** — compositional momentum carving; the trigger for the
  whole desire.
- **AER, Sable, Owlboy, Feather, Sky** — open contemplative worlds
  worth being in; reference for *place* quality. Limited by being
  passive and finite — what this project takes from them is
  posture/tone, not pacing or scope.
- **Hollow Knight** — small distinct learnable composable verbs;
  mastery felt; chains are the depth.
- **Mirror's Edge / Ghostrunner / Dying Light** — parkour 2.0 movement
  lineage.
- **Ultrakill** — fluency vocabulary; movement-as-medium.
- **Minecraft, No Man's Sky** — sandbox structure with player-set
  goals and procedural/infinite substrate.
- **Resonite / NeosVR** — in-world programmability reference. The
  project doesn't compete on this axis; included only as low-priority
  nice-to-have (see below).

## Nice-to-haves (low priority)

### Player-authored content / in-world creation

ChatMUD-style player programming and Warframe-style dojo decoration
both gesture at this. Useful but not core. Resonite / NeosVR already
occupy the in-world-programmability niche. Worth including at the
Warframe-decoration tier — limited, present, better-than-nothing,
not the spine.

## Activity surfaces (working list)

A non-exhaustive, non-final list of concrete venues and activities
the game should support, drawn from observed modern-life patterns
(see persona-research notes). This is *a* list, not *the* list —
each item needs its own design pass on how the activity actually
plays out (loop, friction, dopamine source, content authoring), and
the list itself will grow/shrink as design progresses.

**Venues / activity sites:**
- Clothes shops (boutiques, thrift, vintage, fast-fashion) — browsing,
  try-on integrated with body/cosmetic customization
- Arcade / game centers — in-world minigames
- Go-karts / bowling / mini-golf / pool halls — low-stakes
  competitive activities
- Bars / clubs / dance floors — substance + social + music
- Restaurants / cafes — eating, dates, working-from-cafe,
  coffee-shop-reading
- Movie theater
- Karaoke / music venues / concerts
- Gym / yoga studio / pickup sports
- Parks / trails / beach / nature — walking-for-its-own-sake, dog
  walks
- Library / bookstore — sacred-reading, browsing
- Mall / shopping district
- Pet store / dog park
- Garden / community garden — slow caregiving
- Your home — decoration, hosting, parallel play, wind-down
- Friends' homes / NPC homes — visiting, hangout
- Festivals / markets / public events — ephemeral content
- Museums / galleries

**Activity types these support:**
- Clothes shopping (try-on tied to customization)
- Dates (multi-stage: ask → plan → go somewhere → scene)
- Drinking with friends
- Eating out
- Working out
- Walking your pet
- Reading at a cafe (the sacred-thing mode)
- Browsing for its own sake
- Group hangouts at someone's place
- Performing (karaoke, open mic, dance)
- Attending a concert / festival
- Watching a movie (alone or paired)
- Casual competitive minigames (pool, karts, arcade)

**Parallel play threads through almost all of these** — most are
nicer with someone in the room/voice even if you're each doing your
own thing. NPC-presence-as-co-presence is a design property the
activity surface should preserve.

Each activity above needs its own design (still TBD): what's the
moment-to-moment loop, what gives it dopamine, what's the content
authoring strategy, what makes it returnable rather than one-and-done.

## Open questions

- **Project name.**
- ~~**Engine**~~ — **decided (provisional): Godot** via godogen.
  Chosen for faster prototyping, mature scene/asset pipeline, and the
  fact that content authoring tooling matters more than raw perf at
  this stage. Drop to Rust via gdext for hot paths (deep simulation,
  perf-critical systems) when needed. Revisit if/when Godot's
  limitations dominate.
- ~~**Multiplayer model**~~ — **decided: self-hosted servers**
  (Minecraft / Valheim / Project Zomboid model). Online multiplayer
  without live-service obligations: ship the binary, communities run
  their own servers, no back-compat burden, no live-ops, no
  centrally-operated anything. Communities self-segregate (including
  on NSFW content). Trade-off: discovery is harder, no single shared
  world, no centrally-operated cosmetic store unless explicitly built
  out.
- ~~**Setting / fiction**~~ — **decided: modern (elastic).**
  Recognizably modern-life-coded textures: apartments, street markets,
  phones, real-feeling people in real-feeling places. The elastic
  part: "modern" includes nostalgia-coded periods (1990s, 2000s) and
  slightly-near-future, but the texture is always lived-in modern,
  not sci-fi-exotic or fantasy-worldbuilt. The observation behind
  this: the Warframe places that work best as *places* (Dormizone,
  Cetus, 1999/Höllvania, KIM) are exactly the ones that lean into
  modern intimacy rather than sci-fi spectacle. Modern is the
  aesthetic of inhabitance; sci-fi/fantasy work harder for awe but
  worse for *being-there*.
- **Further power fantasies beyond the five committed** — the design
  expects the list to grow as more concrete fantasies are identified.
  Five is the current foundation, not the cap.
- ~~**Adult-content posture**~~ — **decided: NSFW-first with SFW
  toggle.** All systems (body, transformation, relationships,
  intimacy, identity) are designed assuming NSFW is the default. NPCs
  are written as full sexual/intimate beings. The SFW toggle is a
  *rendering* layer (clothes the NPCs, censors prose, removes
  scenes), not a content rewrite — the underlying systems remain
  NSFW-shaped. Depth and care goes into the adult content; SFW is the
  abridged version. Distribution constrained accordingly (Itch.io,
  direct, possibly Steam adult section). TiTS / Lilith's Throne /
  Accidental Woman as the reference for this posture, vs. modded
  Skyrim NSFW (SFW-first) as the failure mode.
- **Content authoring strategy** — procedural? AI-assisted?
  Hand-authored? Community? Hybrid?
- **Persistence model** for character investment — what *accumulates*
  if not gear/stats/levels?
- **Sources of change priority** — which sources the project leans on
  hardest.

## Systems that compose 100% immersion

The 100% immersion goal isn't "good rendering" or "good NPCs." It's
all of these systems hitting a quality bar simultaneously, every
moment, every player, every situation. Dropping the ball on any
one — animation snap, audio mis-spatialization, mirror with wrong
reflection, robotic NPC, hand clip — breaks the spell for that
moment.

### Visual / rendering
1. Rendering quality (lighting, materials, shading) — perceptually real
2. Mirror rendering (real-time reflection at quality)
3. Visual consistency (no pop-in, LOD seams, shadow issues, z-fighting)
4. Environmental detail (foliage motion, ambient particles, lived-in surfaces)

### Animation / body
5. Body animation (movement, weight, momentum, follow-through)
6. Body deformation (volume preservation, soft body, muscle)
7. Cloth simulation (real physics, body-coupled)
8. Hair simulation (strand or convincing fake)
9. Face animation (visemes, saccades, blinks, micro-expressions)
10. Hand / finger IK (grasp, contact, gesture)
11. Foot IK (uneven ground, weight shift, stance)
12. Breathing / passive body life

### Physics / interaction
13. Object physics (mass, momentum, contact)
14. Hand-object interaction (grasp, throw, place naturally)
15. Body-environment contact (sit, lean, touch surfaces)
16. Two-way coupling (cloth on body, body on cloth, body on furniture)

### Audio
17. Spatial audio (HRTF, reverb, occlusion)
18. Voice (acting or TTS at human quality)
19. Environmental ambience
20. Foley (footsteps, cloth rustle, body sounds)

### VR-specific
21. Tracking (head, body, hand, face, eye)
22. Comfort (latency <20ms, 90+fps, no jitter, correct IPD)
23. Avatar calibration to player body

### Characters / NPCs
24. NPCs as autonomous agents (own schedules, moods, lives)
25. Conversational presence (contextual, not dialogue trees)
26. Eye contact / gaze attention / body language
27. Memory and continuity of you across sessions

### World
28. Persistent world state
29. Day/night, weather, seasons, events on world clock
30. World agency (things happen without you)
31. Lived-in detail

### Identity / customization
32. Body customization consistent across activities
33. Outfit/items that respect physics + body
34. Self-perception via mirrors
35. Touching self / experiencing your body

### UI / friction
36. Diegetic UI (in-world, on-body, no HUD overlays)
37. No loading screens / instant transitions
38. No confirmation dialogs / menu friction
39. Voice / gesture / glance input where natural

### Continuity / narrative
40. Past actions register and matter
41. Relationships evolve with continuity
42. Lived history visible (timeline tree, your home, your stuff)

### Multiplayer
43. Other players' presence at parity quality
44. Low-latency interaction
45. Cross-platform avatar/animation parity

Each system has its own quality bar that doesn't break the spell.
The bar is high. The "no copouts" commitment makes scope demanding —
this is the multi-year R&D-shaped reality of the project.

## Production reality

Rough scale (focused indie on licensed engine, content excluded):
200k–800k LOC of systems code, plus a content pipeline. With AI
codegen at full leverage, the binding constraint is *design clarity*,
not engineering throughput.

The 100% immersion commitment plus the no-scope-reduction commitment
plus the Quest-standalone target means **this is a multi-year R&D-
shaped project, not a one-time ship**. Phased fidelity is acceptable:
ship v1 with "decent" animation/sim/NPC quality (better than indie
norm, worse than goal); each subsequent year invest in specific
systems and ship improvements. The bet is that focused-small-team +
AI codegen leverage + multi-year compounding can out-execute
dysfunctional-AAA on specific narrow axes (Dwarf Fortress, Factorio,
Toribash, VRChat as precedent for small-team-beats-big on a narrow
axis).

Mocap explicitly not the bet — scales linearly with content, breaks
at edge cases, doesn't compound. Instead: specialized cheap runtime
sims (PBD cloth, dynamic bones with shape matching, purpose-built
soft body solvers for key areas, procedural overlays for life,
learned/ML approaches as the tech matures over the timeline).

Shipping less than the full synthesis is unacceptable per design
intent — half the place is not a smaller place, it's a tech demo.
Multi-year commitment, scoped accordingly.
