# DESIGN

Working design doc for **aeriea** (pronounced "area"; name tentative —
see Naming). Captures what's been decided so far, what's still open,
and what is explicitly *not* in scope. Comprehensive synthesis from
the co-design conversation that produced the project — it is intended
to capture every meaningful decision, refusal, value, architectural
commitment, system, activity, trade-off, nuance, persona-research
finding, and open question raised across that conversation, including
the subtler points and the things ruled *out* on the way to what was
ruled *in*.

Status: pre-prototype. Engine decided (provisional): Godot via
[godogen](https://github.com/htdt/godogen). Repo scaffolded. Name
decided (tentative): **aeriea**.

## What this is

**A place to be.**

**The single non-negotiable goal: 100% immersion.**

Every design decision is evaluated against one test: does this preserve,
or break, the player's immersion? Any break — animation snapping, audio
mis-spatializing, NPC dialogue feeling robotic, UI overlay breaking the
spell, a clipping garment, a mistimed viseme, a glitched hand grasp,
a mirror with the wrong reflection — fails the test. The "extra"
framing (sometimes phrased "110% commitment") is rhetorical emphasis on
uncompromising posture: we don't ship at 95% if 100% is what the design
requires. Reality-grade immersion in the moments that matter, with zero
copouts. The extra 10 is *not* "exceeds reality" — reality-equivalent
is the bar.

The user-explicit derivation chain: no copouts on animation traces to
"any flaw breaks immersion"; stylization is not acceptable because
it's less than full immersion; mocap edge cases are unacceptable
because any glitch breaks immersion; no combat / no grind because they
force out-of-character modes; deep customization because it lets you
be immersed in being *yourself*; mirrors are foundational because you
experience your own immersion; VR is first-class because it's the most
immersive medium; face tracking / visemes / breathing / saccades
because every channel of immersion matters; physical sim quality
because the body has to read as real; NSFW-first because intimate
moments are the test of immersion; density-of-content not
forced-cadence because immersion = your own pace; deep NPCs + world
agency because a place that's alive populates immersion.

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
great MMO and the best moments of contemplative-experiential games:

- Old WoW
- FFXIV housing wards
- Warframe relays (Dormizone / Cetus / 1999 Höllvania)
- Second Life
- ChatMUD
- AER, Sable, Sky (the contemplative-experiential side)

What those references *lack* — and what aeriea provides — is full
synthesis: the depth and variety of a Warframe-grade sandbox, the
customization and identity-fluidity of a TiTS/FS-grade character
system, the embodied movement of a parkour 2.0 game, the cosmetic
investment of fashion-frame culture, all in service of
*being-in-a-place*.

### The shape stated three ways

- **TiTS/FS-grade identity/transformation/content depth, in 3D, with
  parkour 2.0 movement and Warframe-grade visual cosmetics.** (The
  gap TiTS/FS leave is embodiment; that's exactly what aeriea adds.)
- **Palia's content axis wedded to Hollow-Knight-composable verbs
  and Redout/Ultrakill/Sable-grade movement.** Palia's content,
  parkour-2.0 traversal: the commute *becomes* part of the pleasure.
- **Warframe-shaped sampler of power fantasies, each fantasy
  non-combat.** Swap between flavors of being-in-the-world by mood,
  like swapping frames.

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
- **Habitability** — you can make a home in it, and *authoring* that
  home is a first-class pursuit (see *Authoring your environment*).
  Persistent personal space you decorate and build, accumulated stuff,
  a soundscape you curate — your spot, looking and sounding the way you
  made it.

## What it is *not*

Non-negotiable refusals. Listed to keep future scope creep honest.

- **Not a combat game.** Combat is structurally absent. The player's
  vocabulary does not include violence. No combat-as-spine; no
  combat-as-side-content either. Rationale: combat is a
  "conflict-resolution monoculture" — every encounter collapses to
  the same verb of "reduce HP to 0", flattening design space and
  forcing the world to be populated with things-that-must-die. The
  aesthetic is **co-presence over opposition**: "what is this thing,
  and what's it like to be near it," not "how do I remove it."
- **Not a quest-driven game.** No quest markers, no fetch chains, no
  scripted objective sequences as the primary content.
- **Not a quantity-gated grinder.** No "mine 1000 of X to unlock Y."
  No tradeskill XP bars. The failure-mode framing is precise:
  "quantity-gated repetition of identical actions" *regardless of how
  nice the action is individually*. Tony Hawk runs aren't grindy
  because each run is a *fresh creative act with variance*;
  mining-in-batches-of-6 has no variance — it's the same input loop
  until the meter fills. Reducing the quantity doesn't remove the
  pattern; it shortens the labor.
- **Not a metroidvania.** Verbs are not gated to re-open the world.
- **Not a designed-answers platformer.** Geometry doesn't have one
  correct line; many lines are valid. The world is *permissive* the
  way Warframe's geometry is — wide corridors, big rooms, gaps you
  can fudge, surfaces that behave the same. You can't really "miss" a
  jump in a way that matters. Expression is *into a sandbox*, not
  *into a designed question*.
- **Not a finite narrative experience.** AER / Feather / Sable run
  out. The substrate must carry replay; developer-authored content
  treadmills will not.
- **Not a passive / contemplative experience.** The experiential
  posture does *not* mean walking-sim engagement. The player is active
  — moving fluently, expressing themselves, interacting richly. (The
  reference set's contemplative games are referenced for posture/tone,
  *not* for pacing/scope.)

### Things considered, clarified, or rejected along the way

These were on the table at some point in the conversation and were
ultimately ruled out, reframed, or downgraded. Capturing them so the
reasons don't have to be re-derived later.

- **"Movement is the whole game"** — wrong framing. Movement is a
  pillar (the canvas you display your look on, the per-second dopamine
  engine) but not the whole. Early framing tunnel-visioned on it from
  the parkour-2.0 references and was corrected.
- **"Fashion is the spine"** — wrong, because "fashion is not
  something you can do all day every day." Cosmetics are a major
  value but not *the* central thing.
- **"Scenes as the core content unit"** — too shallow.
- **"Ongoing relationships and arcs as the entire game"** — alone,
  insufficient. Naming any singular 'content unit' is reductive,
  a copout, and misleading. aeriea is a sampler; it does not have a
  single spine. "Spine" itself is a sloppy framing the project should
  not reach for; aeriea doesn't have one.
- **Activity-frequency-management as the design axis** — wrong axis.
  Frequency is the wrong lens; all that matters is that things
  *exist* at all. Forcing high frequency is, objectively, annoying.
  Push-cadence is anti-pattern; pull-availability is the goal. (See
  Density-not-Cadence.)
- **WarioWare / Dumb-Ways-to-Die tempo as a design framework** —
  discussed as a pattern-of-short-novel-hits but explicitly rejected
  as a tempo for this game. Animal Crossing tempo even is the *wrong
  axis*; the actual axis is *existence not frequency*.
- **Resonite/NeosVR-style in-world programmability as a major
  feature** — reframed rather than flatly rejected. Resonite's
  ProtoFlux is the anchor example of *spatially diegetic but
  semantically exposed* compositional power: manipulated in-world with
  your hands, but still a floating logic / node graph — a dev tool
  rendered in 3D, in the world but not in the fiction. That exposed
  graph is the immersion break aeriea refuses; what aeriea aims at is
  full-diegetic compositional depth (the *Noita* end of the axis).
  Resonite's perf is also garbage and it lacks a real cosmetic-shopping
  economy. The precise stance lives in *Compositional power and the
  diegetic-integration axis*. (Note: this concerns exposed
  *programmability* surfaces specifically. Space and soundscape
  authoring — decorating, building, and curating your spot — is a
  separate matter and is a committed first-class power fantasy with
  real depth; see *Variety of power fantasies* and *Authoring your
  environment* below. What aeriea refuses is exposed scripting
  surfaces, not the decoration/curation pursuit.)
- **VRChat's custom-avatar workflow** — requires Unity, which is
  insane. aeriea will not make players open Unity to bring an avatar
  in. Resonite/NeosVR-style in-engine creation is the better
  reference.
- **Mocap as the animation strategy** — technically feasible but
  rejected on its merits. Mocap is limited and you will be hunting
  edge cases forever. It is the most feasible path; it is not a good
  solution, even if the alternative is beyond SOTA. Mocap scales
  linearly with content, doesn't compound, and breaks at edge cases —
  and edge cases *multiply* with body sliders, item sliders,
  situation variance.
- **Stylized aesthetic as the way out of the animation problem** —
  considered as a copout for missing realism, then ruled inadmissible.
  Stylized art is fine if chosen affirmatively for its own reasons,
  but cannot be the answer to "we can't hit perceptual realism."
- **Pre-baked simulation results as the animation strategy** — leads
  to the 500GB-of-simulated-animations problem under combinatoric
  body variation. Doesn't scale.
- **Per-client mix-and-match netcode** — rejected as too complex.
  Mix-by-responsibility yes; mix-by-connection no.
- **Replay-the-missed-log to catch up on reconnect** — unnecessary.
  Reconnect via snapshot; action log is for sharing/leaderboards,
  not for live reconnect.
- **Shipping a smaller place / scope reduction** — explicitly
  unacceptable per design intent. "Half the place is not a smaller
  place, it's a tech demo." Dropping target hardware support is
  unacceptable; Quest standalone stays in scope.
- **"Movement game in 2D"** — no; parkour 2.0 is 3D. Hollow Knight is
  referenced for *what movement means* (compositional verb
  vocabulary), not for being 2D.
- **Pursuit / dating as a "missed" pattern in games** — early framing
  claimed games skip pursuit; this is not true. Persona, BG3,
  Stardew, every dating sim covers it. Not a missing pattern, just a
  particular surface aeriea will support.

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
6. **Authoring your environment — your space, your sound.** The
   counterpart to cosmetics, at full parity. Cosmetics is curating how
   *you* look; this is curating the *space you inhabit* — how your spot
   looks and how it sounds. One fantasy covering both the visual and
   the sonic: decorating and building your personal space (furniture,
   decor, layout, lighting, the arrangement of a place that's yours)
   *and* curating its soundscape (Somachord-style playlist / jukebox
   music curation, ambient bed, the sound of your spot). The verbs are
   the same ones the design already commits to for cosmetics —
   browsing, acquiring, arranging, curating, expressing — pointed at
   surroundings instead of body. And like cosmetics it carries a real
   economy: acquiring furniture / decor / music tracks, arranging a
   space, curating a soundscape are *real activities* and an investment
   vertical, not an afterthought. References: Warframe (Somachord music
   curation; orbiter / dojo decoration), Palia house-building, Animal
   Crossing interiors, VRChat world / space personalization.

**The list grows.** Six is the current foundation, not the cap.
Further power fantasies will be committed as concrete ones are
identified. The doc's job is to record them as they land, not to
freeze the catalogue.

### Cosmetic depth / fanservice

Not the spine (there is no spine), but a major value. The project
invests in cosmetics at Warframe scale — Tennogen-grade visual depth,
not "pick a colour swatch." Combined with the TiTS/FS lineage,
"cosmetic" extends past outfits to **the body itself** — forms,
transformations, species, presentation all on the customization
surface.

The cosmetic *economy* (browsing, shopping, acquiring, curating drip)
is itself a real activity, not an afterthought. Resonite/NeosVR
notably lack this even though they have user-imported assets.

#### Live expressive system (VRChat-shape)

VRChat-style toggles, sliders, and items are **core, not
nice-to-have**, and are distinct from session-level loadout swaps.
They are a *live moment-to-moment expression surface*:

- **Toggles** — avatar components you switch on/off live during play
  (show/hide hat, wings, particle effects, accessories, glow).
- **Sliders** — continuous parameters adjusted in-play, not just at
  chargen (feature size, color, glow intensity, expression, body
  proportions).
- **Items** — holdable / wieldable props you pull out (drinks, cigs,
  plushies, instruments, signs, flowers, toys), often interactive
  with other players (give a flower, share a smoke, hand someone a
  sign). Each item is a tiny social-interaction primitive and a
  small individually-authorable piece of content (community-multiplier
  on density-of-available-content).

This is distinct from Warframe-style appearance slots (which are
session-level loadout swaps) and from static cosmetic curation.

#### Mid-session form swapping

A specifically-VRChat thing distinct from session-level appearance:
*change shape on the fly, as a verb*. Mid-conversation transformation.
Embodiment in non-human / unusual forms — giant, tiny, monstrous,
anthropomorphic, abstract. Scale and proportions change, not just
look. Body-form play.

#### Items as mechanically meaningful, not just visual

A *game game* needs customization that's mechanically meaningful, not
purely display. Items / toggles / sliders are first-class gameplay
surfaces:

- **Items** do things (instrument actually plays, drink actually
  intoxicates, sign actually communicates).
- **Sliders** can affect what scenes are accessible / how NPCs react /
  what clothes fit / what activities you can do, not just aesthetics.
- **Toggles** change contextual state (clothed/unclothed affects scene
  availability; active accessory toggle changes social context).

UX caveat noted explicitly: mixed-purpose surface (some toggles are
cosmetic, some are mechanical, some context-gating) creates a UX
minefield, plus all the failure modes of parameterized bodies
(clipping, animation breaking, items used at wrong moments, perf
tanking with many things active). Needs careful design.

#### Positioning vs VRChat and Warframe

- **Warframe** is *gamey but less personal* — high curation, low
  personal-expression depth.
- **VRChat** is *personal but uncurated* — high personal-expression,
  wild-west quality, requires Unity to author avatars.
- **aeriea** aims for **more structured and curated than VRChat, more
  personal than Warframe** — curated authorship surface (quality bar,
  moderation) with deep personal expression within it. Community
  items/avatars exist but pass through a quality gate; the
  default-shipped experience feels intentional, not chaotic. In-engine
  creation tools (Resonite-shape), not "open Unity."

#### Mirrors are foundational

In first-person / VR with heavy avatar/body investment, the player
literally cannot see themselves otherwise. Mirrors are the entire
feedback loop for cosmetic curation, body expression,
embodiment-checking, and self-appreciation. Without good mirrors, all
the cosmetic / body investment is invisible to the player themselves —
they spent hours making the avatar but only see other people / can't
appreciate their own work. That's the failure mode mirrors prevent.

Surfaced explicitly as "the most important part (of VRChat at least)"
that earlier framings had missed.

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

#### NSFW-first with SFW toggle

All systems (body, transformation, relationships, intimacy, identity)
are designed assuming NSFW is the default. NPCs are written as full
sexual/intimate beings. The SFW toggle is a *rendering* layer (clothes
the NPCs, censors prose, removes scenes), **not** a content rewrite —
the underlying systems remain NSFW-shaped. Depth and care goes into
the adult content; SFW is the abridged version.

Reference posture: TiTS / Lilith's Throne / Accidental Woman.
Failure-mode posture (rejected): modded Skyrim NSFW, which is
SFW-first with NSFW bolted on.

Distribution constrained accordingly: Itch.io, direct download, the
adult section on Steam if eligible.

### Movement that doesn't waste your time

Palia's failure: cozy life-sim activities are fine, but the player is
slow and the world is huge, so 90% of the session is commute.
Refusal: the player must move *fluently* so traversal is a pleasure,
not a tax.

The aesthetic upside: if movement is Redout-grade and expressive, the
"commute" between activities *becomes* the pleasure. The walk to the
fishing spot is the *other* good thing about the fishing trip.

- **Parkour 2.0** is the love. Mirror's Edge / Dying Light /
  Ghostrunner — negotiation with real geometry, embodied weight,
  momentum that matters.
- **Carving / momentum feel** (Redout 2). Control surface composes;
  every input modifies every other input; velocity preserved across
  inputs. Redout 2 was the stated *trigger* for the whole desire — the
  thing that started the project — but the desire is for the carving
  feel *unbolted from the track*, applied to a Sable-shaped world.
- **Compositional verb vocabulary** (Hollow Knight). Small clean
  primitives; the depth is in chains; mastery is real and felt.
  (Referenced for *what movement means*, not for being 2D.)
- **Brain-on, not brain-off** — parkour 2.0 is the brain-on mode
  (bullet jump + aim glide are muscle memory; the *line through the
  level* is the creative act). Distinct from Warframe-style
  movement-as-traversal-tool.

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

### Comfort over novelty for routine play

(From the persona research — see *Persona research*.) The game should
not push novelty constantly. Most sessions are people seeking
familiar/warm, not new-thing-please. The design must support
comfort-mode play alongside novelty-mode play. Comfort rewatches,
your spot, your routine, the people you already know — these need to
*work* in aeriea, not be subordinated to "what's new this week."

### One sacred thing per player-type

(From the persona research.) Each persona has ONE thing they reach
for that genuinely refills them. Casey's trail run with the dog;
Alex's painting minis; Maria's Saturday nap; Sam's coffee-shop read;
Riley's fic writing. Not the same thing for each. This *validates*
the variety-of-power-fantasies value: different players have
different anchors, and aeriea must provide enough breadth that each
player can find their sacred thing in here.

### Parallel play as a design property

Threads through almost every activity. Most are nicer with someone in
the room/voice even if you're each doing your own thing.
NPC-presence-as-co-presence is a design property the activity surface
should preserve everywhere. From the persona research: *everyone*
does parallel play (partner watching a show while you craft, roommate
playing their game while you play yours, voice-chat-while-doing-own-
thing).

### The fragmented modern evening

(From the persona research.) Evenings are 5-7 small activities
switching, not deep focus on one. Design for this. A session is not
"one deep activity"; it's a short opener, a wander, an encounter, a
cosmetic snack, a parallel-play stint, and a wind-down. The pacing
and the structural commitments (pull-availability, density,
parallel-play) all serve this.

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
  than any one author could write. Proven pattern delivering hundreds
  of hours of content per game *without* LLMs.
- **LLM-compatible but not LLM-required** — local LLM viability and
  the controversy around LLMs are both unsettled. Build the depth
  substrate to stand on its own using proven patterns (simulation +
  authoring + procedural), but design interfaces so LLM-driven
  characters or LLM-augmented systems can slot in later. Don't
  foreclose; don't depend on what isn't viable yet.

Existing prior art in the user's ecosystem that informs this layer:
`hologram` (Discord RP bot with knowledge graph + RAG — persistent
characters with structured memory), `ashwren` (autonomous AI presence,
contemplative, reads and thinks across sessions — a character with an
inner life that continues when you're not there), `fuwafuwa`
(autonomous presence with emotional-state tracking and probabilistic
freetime scheduling — moods and own schedule), `aspect` (card-based
identity exploration), `noncanon` (local-first collaborative
worldbuilding), `defocus` (world substrate for stateful simulation),
`chub-stage-factory` (Chub-stage design workspace), `playmate` (most
directly relevant; designing aeriea from scratch and bringing
`playmate` back in as cross-reference once the scaffolding stabilizes).

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

## Setting / fiction

**Decided: modern (elastic).** Recognizably modern-life-coded
textures: apartments, street markets, phones, real-feeling people in
real-feeling places. The elastic part: "modern" includes
nostalgia-coded periods (1990s, 2000s) and slightly-near-future, but
the texture is always lived-in modern, not sci-fi-exotic or
fantasy-worldbuilt.

The observation behind this: the Warframe places that work best as
*places* (Dormizone, Cetus, 1999/Höllvania, KIM) are exactly the ones
that lean into modern intimacy rather than sci-fi spectacle.
Dormizone is an apartment with a TV and personal stuff. Cetus is a
street market with vendors. 1999 is literally a 1990s aesthetic with
apartments and a band. KIM is a phone. The sci-fi trappings exist but
the *places* feel like real life — recognizable, lived-in, modern.

Modern is the aesthetic of *inhabitance*; sci-fi/fantasy work harder
for awe but worse for *being-there*.

### Transformation lore (sketch, WIP)

The body-as-cosmetic / transformation framing (see *Cosmetic depth*,
*Mid-session form swapping*) has an in-fiction grounding: bodily
malleability is **ambient and normal** in the world, delivered
"Second Dream"–style — mundane on the surface, with a withheld deeper
truth surfaced as an earned reveal. **The origin is decided: technological
advancement** — the world is a slightly-near-future point where body-tech
matured to the degree that malleable bodies are normal infrastructure, the
way phones are now. This same body-tech is also the in-fiction answer to
*why the avatar is superhuman* (bodies are assembled / regrown / fabricated
/ projected to spec; superhuman feats are simply "what that body can do").
The tech is ambient, not spectacle — places stay lived-in-modern per this
section's modern-elastic decision. Broader lore (lineages, composability
carveout, reveal staging, names) remains WIP; see
`docs/decisions/transformation-lore.md`.

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
  Verification = re-run + plausibility check on inputs. **Trackmania
  precedent**: server-side replay re-sim catches log forgery;
  client-side input-attestation à la TMCP (donadigo.com/tmcp, the
  third-party verifier) catches input forgery. Communities choose
  their own anti-cheat posture. (Notable: action logs *are* forgeable
  in principle; Trackmania has "solved" this with the TMCP approach;
  public info on TMCP's internals is limited.)
- **Reconnect via snapshot** (not replay): rejoining clients just
  pull the current world state from the server. Action log is for
  sharing and leaderboards, not for live reconnect.
  Replay-the-missed-log was explicitly considered and ruled
  unnecessary.

Constraints this imposes:
- No client-side gameplay state that affects outcomes.
- Float determinism is hard across platforms; commit to fixed-point
  for the sim layer, or accept that replay validity is bounded by
  runtime (Trackmania accepts the latter — fine for our case).
- All sources of variability (NPCs, weather, time-of-day, events)
  derive from the seeded timeline.

Open concern: single seed + action log format in *multiplayer*
without hurting multiplayer. Not blocker, not solved — flagged.

### Platforms and presentation

**Cross-platform from the start**: flat (KB+M / gamepad) + PCVR +
Quest standalone (and equivalent mobile-class standalone VR).

VR (especially Quest standalone) is first-class, not an afterthought.
Rationale: the kind of game this is (embodied presence,
self-expression, social being-with) is exactly what VR is *for*.
VRChat shows the upside; the gap is in the structured/curated/game
parts that VRChat doesn't deliver, which is what we're filling.

Dropping target hardware support is unacceptable; Quest standalone
stays in scope through every phase.

**World scale: 1 Godot unit = 1 meter, avatar at real human scale.**
Because VR is first-class, the world renders in *real meters* — a
1.75 m doorway must be 1.75 m to the headset, or presence breaks. So
the avatar is built at real human dimensions and 1 unit = 1 meter
everywhere; gravity is real (9.8 m/s²). The heightened movement
(big jumps, wall-runs, bullet-jumps) is framed **diegetically** — the
avatar is a superhuman/augmented body doing what *that* body can do,
not an arcade exaggeration of a normal human. The numbers stay in real
units; only the *capability* is above baseline. The full convention,
the reference avatar dimensions, and the movement-magnitude table
(real value / human baseline / multiplier) live in
`docs/decisions/units-and-scale.md`. The in-fiction grounding for *why*
the avatar is superhuman is now being **addressed (in progress, not
closed)** by the transformation-lore sketch: a body assembled / regrown
/ fabricated / projected to spec is superhuman because that is "what
that body can do." See `docs/decisions/transformation-lore.md` (WIP).

**Diegetic UI** — menus live on the body or in the world, not as
screen overlays. Wrist menus, palm panels, in-world objects. Works
for both VR (proprioceptive — your hands know where your wrists are)
and flat (rendered as on-body UI, controlled differently). No
abstract HUD layer.

**Multiple radial menus** (Warframe gear-wheel / emote-wheel
pattern): one wheel doesn't scale; many specialized wheels do. Maps
naturally to per-controller buttons in VR, modifier-keys + wheel on
flat. Warframe has multiple Q-menus already as precedent;
proprioceptive controls like relative-to-wrist (or even on-wrist) are
very hype.

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

**Self-hosted multiplayer model.** Minecraft / Valheim / Project
Zomboid shape. Online multiplayer *without* live-service obligations:
ship the binary, communities run their own servers, no back-compat
burden, no live-ops, no centrally-operated anything. Communities
self-segregate (including on NSFW content).

Trade-off (acknowledged): discovery is harder, no single shared
world, no centrally-operated cosmetic store unless explicitly built
out. The trade-off is accepted explicitly — the cost of maintaining
an audience and preserving back-compat is greater than the cost of
decentralized discovery.

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

### Engine and stack

- **Godot** (provisional) — chosen for faster prototyping, mature
  scene/asset pipeline, and the fact that content authoring tooling
  matters more than raw perf at this stage. Scaffolded via
  [godogen](https://github.com/htdt/godogen) (which despite the name
  supports both Godot and Bevy).
- **godogen caveat surfaced during scaffolding**: godogen is
  actually an agent-driven generator (runs an autonomous agent inside
  the repo to build the game from a description), not a static folder
  template. We have a substantial design doc already, so the
  autonomous-agent approach could conflict or duplicate. Used static
  scaffolding instead.
- **Drop to Rust via gdext for hot paths** (deep simulation,
  perf-critical systems) when needed. Revisit engine choice if/when
  Godot's limitations dominate.

### Movement as a data-driven substrate

The movement kit is **fully composable and configurable as data**, not a
hand-written controller. The state machine, its transitions (with guards),
and its effects are a single serializable definition over a small closed
vocabulary of *primitive* conditions (`on_ground`, `speed_h >= X`,
`input_buffered`, `wall_detected`, …) and *primitive* effects
(`set_velocity_y`, `add_velocity`, `carve`, `apply_gravity`,
`set_collider_height`, …) — never embedded closures or source text. The
backlog verbs (bullet jump, air burst, charge, wormhole, teleport, aim,
wall-cling) are a *starting vocabulary*; the novel substrate is that they
are recomposable data units a designer layers on without touching engine
code — the thing that makes this **not** a Warframe ripoff.

One definition projects two ways (library-first,
projection-from-one-definition): an **interpreter** loads the JSON at
runtime for live designer preview / hot-reload, and a **compiler** lowers
the *same* definition to branching code (GDScript first, Rust/gdext later)
for the perf edge. Interpreter and compiled output must produce identical
trajectories from one definition — proved by golden traces (same seed +
input log → identical state trajectory). The interpreter is a pure
fixed-tick, single-sample-per-tick stepper, fitting the deterministic
seeded-sim commitment above.

Full spec, schema, worked examples (jump/slide/wall-run), and the
incremental slice plan: **`docs/decisions/movement-substrate.md`**.

### Interaction as a data-driven affordance substrate

Interaction is the *graph*: dense, composable command edges per node (no barren
nodes, no wait→wait→wait self-loops — see `reference-analysis.md`). The "second
kit" rhymes with movement: an interactable is **recomposable data** — its verbs,
the **guards** that gate them (a closed union of serializable predicates over
self / held / focus / world state — the load-bearing case being a guard that
reads *another object's* state, e.g. "place full jug"), and its **effects** (a
closed union of state-transition primitives: toggle/set-state, add-fill,
arm/trigger, consume-into-socket, grab/release, apply-impulse) are data, never
hardcoded nodes. Cross-object wiring (valve→spout→jug→pedestal→beacon) is
declared **refs + events + reactions**, not signals; convergence (`armed ∧
reached`) is a first-class `all`-composed guard. The prompt is a pure projection
of the live verb set, making the pure-text litmus mechanical. Same dual path as
movement (interpreter is the spec; compiler with golden-trace equivalence), same
determinism posture; physics (carry spring, box-stacking, overlap) stays
in-engine — only the verb/guard/effect/event graph extracts. Full spec, schema,
the worked valve→…→beacon chain, and the slice plan:
**`docs/decisions/affordance-substrate.md`**.

## Reference set

What each reference contributes.

- **Warframe** — variety of power fantasies, fanservice/cosmetic
  investment, persistent character, "yes-and" sampler structure,
  hub-as-place, KIM as the structural pattern for character depth,
  Dormizone/Cetus/1999 as the "modern is the aesthetic of inhabitance"
  evidence, multi-radial-menus (gear wheel / emote wheel), Somachord
  music curation and orbiter / dojo decoration (the environment-
  authoring power fantasy).
- **Trials in Tainted Space**, **Flexible Survival** — deep character
  customization and transformation; body as customization surface;
  identity fluidity; rich individual-NPC content; NSFW-first posture
  done right.
- **HHS+**, **Accidental Woman**, **Lilith's Throne** — life-sim
  sandbox structure with deep simulation, heavy authoring, and
  procedural recombination. Proven pattern for delivering hundreds of
  hours of content without LLMs.

  > **Interaction-structure evaluation.** TiTS, Lilith's Throne, and
  > Flexible Survival are evaluated *as interaction graphs* — through
  > the affordance / interaction-graph rubric — in
  > `docs/decisions/reference-analysis.md`. That doc diagnoses the
  > "walking sim" failure (2D-grid traversal + wait-to-re-roll a
  > stochastic event) in the framework's terms, shows where each game
  > exhibits or escapes it (notably Lilith's Throne's composable sex
  > engine), and states aeriea's positive target: a dense composable
  > graph that must stand on its own **as pure text**, because the
  > affordance structure lives in the simulation, not the rendering.

- **`existence`** (our own prior art) — simulation-underneath
  rendering-on-top pattern; deterministic state drives generative
  surface; ~67k LOC of working code demonstrating the architecture.
  Power-anti-fantasy in posture (opposite of this project), but the
  *structural* lessons carry.
- **ChatMUD** — persistent textual world as a place; hangout-as-content;
  built on a programmable substrate (MOO-lineage).
- **Redout 2** — compositional momentum carving; the trigger for the
  whole desire. The carving feel unbolted from the track.
- **Mirror's Edge / Ghostrunner / Dying Light** — parkour 2.0 movement
  lineage.
- **Ultrakill** — fluency vocabulary; movement-as-medium.
- **AER, Sable, Owlboy, Feather, Sky** — open contemplative worlds
  worth being in; reference for *place* quality. Limited by being
  passive and finite — what this project takes from them is
  posture/tone, not pacing or scope.
- **Hollow Knight** — small distinct learnable composable verbs;
  mastery felt; chains are the depth. (Referenced for *what movement
  means*, not for being 2D.)
- **Minecraft, No Man's Sky** — sandbox structure with player-set
  goals and procedural/infinite substrate.
- **Animal Crossing / Stardew / Paralives** — life-sim sandbox
  tempo reference; Paralives released into Early Access during the
  design conversation, directly adjacent (life-sim, customization-
  heavy, no-combat, sandbox) — worth a survey once aeriea has a
  shape to compare against.
- **VRChat** — live expressive system (toggles/sliders/items),
  mid-session avatar/form swapping, embodiment in non-human forms,
  pure-social-presence-as-activity, mirrors as foundational, world /
  space personalization (the environment-authoring power fantasy). The
  *content* aeriea ships at quality; the *workflow* (Unity-required
  custom avatars) is rejected.
- **Resonite / NeosVR** — in-world compositional-power reference, in-
  engine creation workflow (the *good* answer to VRChat's
  Unity-required avatars). ProtoFlux is the anchor for *spatially
  diegetic but semantically exposed* power — in the world but not in
  the fiction — which is the immersion break aeriea refuses, aiming
  instead for full-diegetic compositional depth (see *Compositional
  power and the diegetic-integration axis*). Perf and cosmetic-economy
  gaps are real — aeriea fills those. Space / soundscape *authoring*
  is a separate, committed power fantasy (see *Authoring your
  environment*).
- **`playmate`** — most directly relevant prior art in the user's
  ecosystem; bring back in as cross-reference once aeriea's
  scaffolding stabilizes.

### Authoring your environment (space + soundscape)

A committed first-class power fantasy at full parity with cosmetics
(see *Variety of power fantasies*). Where cosmetics curates how *you*
look, this curates the *space you inhabit* — how your spot looks and
how it sounds — using the same verbs (browsing, acquiring, arranging,
curating, expressing).

- **Space / decoration** — decorating and building your personal
  space: furniture, decor, layout, lighting, the arrangement of a
  place that's yours. Warframe orbiter / dojo decoration, Palia
  house-building, Animal Crossing interiors, VRChat world / space
  personalization are the references. Real depth, not a token gesture.
- **Soundscape / music curation** — curating the sound of your spot:
  Somachord-style playlist / jukebox curation, ambient beds, the
  music that plays where you are. This is the player-facing
  counterpart to the *Environmental ambience* rendering system (system
  19) — soundscape authoring is a thing the player *does*, not only a
  thing the engine renders.
- **A real economy** — acquiring furniture / decor / music tracks,
  arranging a space, curating a soundscape are real activities and an
  investment vertical, exactly as the cosmetic economy is. Content-side
  change (Warframe-cadence drops) applies here too: new furniture, new
  decor, new tracks to acquire and arrange.
- **Concrete persistence accumulator** — this fantasy partly answers
  the open *Persistence model* question: your home, your accumulated
  stuff, and your curated soundscape are things that *accumulate*
  without gear/stats/levels. (It doesn't resolve that question on its
  own; it supplies one concrete accumulator.)

## Compositional power and immersion

### Compositional power and the diegetic-integration axis

"Programmability" was too blunt a word for what's actually in question
here. The real axis is **degree of diegetic integration** — how
integrated into the *fiction* a system of compositional / systemic
power is. It's a spectrum, not a binary. From least to most integrated:

- **Out-of-band** — a separate editor / console outside the world.
  Pure immersion break.
- **Spatially diegetic but semantically exposed** — Resonite's
  ProtoFlux: you manipulate it in-world with your hands, but it's a
  floating logic / node graph, a dev tool rendered in 3D. *In the
  world, not in the fiction.* Resonite stopped here because full
  diegetic integration wasn't one of their goals.
- **In-fiction composition** — Noita's wand-building: the "program" is
  expressed as world-objects (spells, wands) and hidden inside the
  play; you never feel like you're writing code. This is also exactly
  the project's own "simulation underneath, rendering on top" and
  "small composable verbs" commitments applied to systemic power.
- **Full diegeticism** — compositional / systemic power expressed
  *entirely* through in-fiction objects and actions, with zero exposed
  graph / editor / language. Largely unsolved in the medium.

The 100% immersion north star applied to this question: an exposed
logic graph is an immersion break *by definition*. So the stance is
**not** "programmability is out of scope." It is: **non-diegetic
programmability — out-of-band tooling, or exposed logic graphs à la
ProtoFlux — is the immersion break we refuse; full-diegetic
compositional depth is the frontier we aim at.** Compositional /
systemic emergence is welcome and on-thesis; the constraint is that it
must climb as far up the diegetic-integration axis as it can.

This preserves the still-valid refusal the earlier "out of scope"
framing was reaching for: aeriea does *not* become a programmable
metaverse or a general-purpose authoring environment, because that
means exposing out-of-band tooling and semantically-exposed logic
graphs — the bottom of the axis. (This is distinct from space /
soundscape authoring, a committed power fantasy — see *Authoring your
environment* above. The decoration / curation pursuit stays in; what
the axis rules against is exposed scripting surfaces, not the act of
arranging your space.)

How far full diegeticism is actually reachable, and for which systems,
is a genuine open question — an aspiration aligned with the thesis,
not a solved build commitment (see *Open questions*).

## Persona research and the activity surface

Concrete activities for aeriea were derived by dispatching subagent
personas to report how they spend free time after work/school.
Capturing the personas' names and the findings here since this
research informs much of the comfort/sacred-thing/parallel-play/
fragmented-evening values and the activity surface below.

### The personas (six honest reports)

- **Casey** — trail run with the dog as sacred thing.
- **Alex** — painting minis as sacred thing; co-presence with Sarah.
- **Maria** — Saturday nap as sacred thing; parallel time with husband.
- **Sam** — coffee-shop read as sacred thing; roommate co-watching.
- **Riley** — fic writing as sacred thing; character.ai admission
  generalizes to "parasocial/parallel-play with a responsive thing is
  real, embarrassing, and important to design for."
- **Jordan** — parallel time with roommate.

### Cross-cutting patterns (universal)

1. **Scrolling/phone** — every persona, 30-60 min, feels bad, does
   it anyway. The dominant modern free-time activity.
2. **Eating/snacking as activity** — standing at counter, on couch,
   paired with media.
3. **Co-presence without conversation** — partner/roommate/parallel-
   play. *Everyone does this.*
4. **Background media** — comfort rewatches (The Bear, Hannibal, Love
   Island UK). Comfort/familiarity beats novelty for routine sessions.
5. **One sacred thing** — each persona has ONE thing they reach for
   that genuinely refills them. Different per persona.
6. **Bed scrolling** — universal, hated, done anyway.
7. **Substance/altered-state** — wine, beer, weed, coffee. Habitual,
   not always enjoyed, real.
8. **Texting bright spots** — small intermittent connection valued
   more than admitted.

### What gives real dopamine (the explicit good-feeling moments)

- Hands-busy meditative activity (painting, baking, fic writing,
  lubing keyboard switches).
- Parallel-presence with someone (roommate co-watching,
  voice-chat-while-doing-own-thing).
- Going outside for its own sake (river loop, walk to library,
  errands as activity).
- Comfort consumption (rewatch, romance novel, familiar game).
- Parasocial/parallel-play with a responsive thing (character.ai
  named explicitly — embarrassing but real).

### What this validates / reveals for the design

- **KIM-grade NPC text-presence is a real dopamine source** — every
  persona had a "small text from someone matters" moment.
- **Parasocial/parallel-play is huge** — Riley's character.ai
  admission generalizes. People want a responsive *presence* that
  doesn't demand much.
- **Comfort > novelty for routine play** (see *Comfort over novelty*).
- **Fragmented texture** — evenings are 5-7 small activities
  switching (see *Fragmented modern evening*).
- **One sacred thing per player-type** (see *One sacred thing*) —
  validates the variety-of-power-fantasies value.
- **Substance/altered-state is universal** — could be a real mechanic
  (`existence` already has NT sim).
- **Hands-busy low-stakes activity** as a mode — painting, baking,
  crafts. Different from achievement/grind.
- **Going somewhere for its own sake** — movement-as-mood, not
  movement-as-transit.
- **Bed/wind-down content** — low-effort end-of-day stuff. KIM
  messages, scrolling, comfort consumption.

### Friendslop and adjacent dopamine

**Friendslop** = casual silly multiplayer-with-friends games.
Examples: Among Us, Lethal Company, Content Warning, Lockdown
Protocol, Webfishing, Backseat Drivers, Guilty as Sock!, Mage Arena,
Peak, R.E.P.O., RV There Yet?, Burglin' Gnomes, Flock Around, Gamble
With Your Friends.

Common pattern: shared experience with friends; the game is a light
framework for that; jank and emergence are *features*; clipping and
sharing the goofy moments is the metagame.

Implication for aeriea: **embrace jank and emergence as features,
design NPCs to be company not just content, build clipping/sharing
in from the start.** Real mode aeriea should support — even though
aeriea must also be just-as-fun singleplayer.

**"Dumb ways to die" pattern** — Happy Wheels / Trials / QWOP /
Getting Over It / Goat Simulator. (Initially mis-categorized as
WarioWare-style microgame format; corrected.) Dopamine: failure-as-
content, physical-comedy timing, the *clip* you create. Crosses into
friendslop territory if multiplayer, stays single-player viable
(failing alone is still funny).

**Important caveat**: the WarioWare / Animal-Crossing-tempo / KIM-
cadence discussion reached for *frequency* as a design axis. This is
rejected. The axis is not "how often the world hits you with small
novel things"; it's "are the novel things *available* to encounter at
all." Forcing high frequency is annoying; existence is the design
property, not cadence.

### Activity surfaces (working list)

A non-exhaustive, non-final list of concrete venues and activities
the game should support, drawn from observed modern-life patterns.
This is *a* list, not *the* list — each item needs its own design
pass on how the activity actually plays out (loop, friction, dopamine
source, content authoring), and the list itself will grow/shrink as
design progresses.

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
- Your home — decoration / building, soundscape curation, hosting,
  parallel play, wind-down (see *Authoring your environment*)
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
- Decorating / building your space (furniture, decor, layout, lighting)
- Curating your soundscape (Somachord-style playlist / jukebox music
  curation, ambient beds)
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

## Naming

**Decided (tentative): aeriea.**

- Pronounced **"area"**.
- Visual: aerie (lofty dwelling / nest — ties to "place" and the
  aerial/movement vocabulary).
- Aural: area.
- Maps directly to "a place to be" via the audio meaning.

**Aerie** (the cleaner spelling) was considered first and rejected:
- Real trademark collision with the Aerie women's apparel/intimates
  brand (American Eagle subsidiary). For a game heavy on cosmetics +
  body customization + NSFW-first + fashion-frame, the worst possible
  trademark overlap. SEO impossible; legal exposure if it ever ships
  at scale; players searching the game would hit the apparel site.
- Pronunciation varies (AIR-ee / AY-ree / EYE-ree).

**aeriea** trades the cleanness of the real word for trademark
clearance and SEO. Concern raised about spelling ambiguity (people
will auto-correct to "area" in writing; the "ie" insertion is
non-obvious). Concern downgraded citing precedent: if the
"competition" in a sense is VRChat, super concerns with ambiguous
spelling are misplaced — VRChat, Resonite, NeosVR all lack
search-optimized names and the communities find them anyway.

Name is **tentative**; still being considered but stable enough to
scaffold under.

## Open questions

- **Project name** (tentative: aeriea; still under consideration).
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
- ~~**Setting / fiction**~~ — **decided: modern (elastic).** See
  *Setting / fiction* section above.
- ~~**Adult-content posture**~~ — **decided: NSFW-first with SFW
  toggle.** See *NSFW-first with SFW toggle* under Cosmetic depth.
- **Further power fantasies beyond the six committed** — the design
  expects the list to grow as more concrete fantasies are identified.
  Six is the current foundation, not the cap.
- **Content authoring strategy** — procedural? AI-assisted?
  Hand-authored? Community? Hybrid? (Likely all four; weights TBD.)
- **Persistence model** for character investment — what *accumulates*
  if not gear/stats/levels? (Partly answered by *Authoring your
  environment*: your home, your accumulated stuff, your curated
  soundscape are concrete accumulators. Not fully resolved — that
  fantasy supplies one accumulator, not the whole answer.)
- **Sources of change priority** — which sources the project leans on
  hardest.
- **Single seed + action log in multiplayer** — the determinism
  architecture needs more thought to confirm it doesn't hurt
  multiplayer.
- **Per-activity design** — each activity in the activity surface
  needs its own design pass on loop, friction, dopamine source,
  content authoring, returnability. The list itself will grow/shrink
  as design progresses.
- **How far full diegeticism is reachable** — for compositional /
  systemic power, nobody has fully solved expressing it *entirely*
  through in-fiction objects and actions (zero exposed graph / editor
  / language). How far up the diegetic-integration axis aeriea can
  climb, and for which systems, is an open aspiration aligned with the
  thesis — not a solved build commitment. See *Compositional power and
  the diegetic-integration axis*.

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
20. Foley (footsteps matching terrain, cloth rustle, body sounds)

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

### Things historically missing in games

Games have failed at these consistently for decades, AAA included:

- **Movement** — weight transfer, momentum, follow-through; canned
  animation can't react to physics; even AAA mostly fakes it; seams
  show.
- **Saccades** — eyes do micro-jitter constantly IRL; most game eyes
  dead-stare or vacantly pan. Cheap to fake with procedural jitter but
  few games bother. RDR2 / TLOU2 do; most don't.
- **Lipsync** — phoneme→viseme is everywhere and looks plasticky.
  Good lipsync needs setup per character + good performance capture.
  Mostly bad even in AAA.
- **Breast volume preservation and deformation** — dynamic bones
  jiggle but don't preserve volume; arms passing through; bra
  deforming breast properly. Needs specialized soft-body solvers with
  two-way coupling. Western AAA mostly ignores; some Japanese games
  (DOA, Honey Select) invest seriously.
- **Cloth-body two-way interaction** — bra deforming breast, shirt
  straining at flexed arm, sock indenting calf. Real research problem.
- **Finger contact on objects** — IK rarely lands; fingers clip or
  float.
- **Weight shift in stance** — standing characters don't actually
  balance / shift; they're T-pose-with-tweaks.
- **Foot on uneven ground** — IK common, rarely perfect.
- **Visible breathing** — chest rise rarely matches the rest of body
  state.

These are not "nice-to-haves" — they're the specific historical gaps
the 100%-immersion commitment requires aeriea to close.

## Production reality

### Scale and shape

Rough scale (focused indie on licensed engine, content excluded):
200k–800k LOC of systems code, plus a content pipeline. With AI
codegen at full leverage, the binding constraint is *design clarity*,
not engineering throughput.

The 100% immersion commitment plus the no-scope-reduction commitment
plus the Quest-standalone target means **this is a multi-year R&D-
shaped project, not a one-time ship**.

### Phased fidelity (the explicit deal)

Phased fidelity is acceptable: ship v1 with "decent" animation/sim/
NPC quality (better than indie norm, worse than goal); each subsequent
year invest in specific systems and ship improvements. Not
stylization-as-copout; *just better than current indie norm, en route
to better*.

The bet: focused-small-team + AI codegen leverage + multi-year
compounding can out-execute dysfunctional-AAA on specific narrow
axes. Precedent: Dwarf Fortress, Factorio, Toribash, VRChat. Small
teams beat big teams on a narrow axis through deep ownership and
time, where AAA can't compound (people leave, knowledge fragments,
focus shifts patch-to-patch).

Diagnosis of AAA dysfunction: AAA studios typically hire a lot of
people that are not only new to the industry but also somehow
constantly burnt out (minor hyperbole). aeriea's edge is the inverse:
focused, retained, AI-leveraged.

Shipping less than the full synthesis is unacceptable per design
intent — half the place is not a smaller place, it's a tech demo.
Multi-year commitment, scoped accordingly.

### The animation/fidelity bet (the constraints conversation)

Several wrong answers were considered before landing on the actual
plan. Capturing the rejected paths because each one has a specific
reason it doesn't work.

- **Mocap + motion matching as the strategy** — rejected (see *Things
  considered*). Scales linearly, doesn't compound, breaks at edge
  cases, edge cases multiply with sliders.
- **Generic FEM / brute-force real-time physical sim** — too
  expensive at runtime, especially Quest.
- **Pre-baked sim results** — 500GB-of-simulated-animations problem
  under combinatorics.
- **Hand-keying** — same combinatorics problem at authoring scale.
- **Stylized aesthetic as the answer** — only acceptable if chosen
  for its own merits, never as the answer to "we can't hit realism."
- **Scoping down** — unacceptable per design intent.
- **Dropping Quest standalone target** — unacceptable.

What's **left** (the actual plan):

- **Specialized cheap solvers per phenomenon**, not generic physics:
  - **PBD (position-based dynamics)** for cloth — GPU-friendly,
    scales by garment count. Used everywhere now.
  - **Mass-spring + shape matching** for soft body / jiggle (VRChat
    dynamic-bones is this; well-trodden; very cheap; scales
    naturally with body type).
  - **Specialized soft-body solvers** for specific use cases
    (breast/glute/belly/fat/hair) — purpose-built, much cheaper
    than generic FEM, math largely solved (industry references:
    Cyberpunk, MGS V, certain Japanese games). Scales with body
    sliders *for free* because parametric.
  - **GPU compute everywhere** — mobile GPUs can do this; PBD /
    mass-spring parallelize trivially.
  - **Hierarchical LOD on sim** — high-res where the camera/mirror
    is looking; downgrade off-screen / distant.
- **Primary motion via ML-based motion synthesis that retargets
  across body types** — bet on the tech maturing. Trained offline,
  cheap at runtime, output respects body variation. By multi-year
  ship date (~2028), should be production-ready.
- **Procedural overlays** (IK, breathing, sway, footplant, look-at) —
  cheap, ubiquitous, sell aliveness.
- **Hand-keyed / mocap only for true signature moments**, kept small.
- **Build internal tooling that compounds** — every animation / cloth
  / sim improvement upgrades all existing content automatically.
  Quest perf optimization is part of the design from day one, not
  "we'll optimize later."

The bet, stated bluntly: (a) specialized sim is cheap enough on
Quest, and (b) ML motion synthesis is production-ready by ship date.
If either fails, that's where the project's R&D burden lands.

Mocap explicitly not the bet — scales linearly with content, breaks
at edge cases, doesn't compound. Instead: specialized cheap runtime
sims (PBD cloth, dynamic bones with shape matching, purpose-built
soft body solvers for key areas, procedural overlays for life,
learned/ML approaches as the tech matures over the timeline).

**Secondary / soft-body physics as the secondary-motion instance of
this bet.** Jiggle bones (spring-driven dynamic bones) are the
industry baseline for secondary motion — ears, tails, flesh, soft
tissue. They are not sufficient: they do not preserve volume and
do not self/world-collide, so the result reads as wobbly sticks
rather than mass. The goal is volume-preserving, physically accurate
secondary motion with proper self- and world-collision. A full
physically accurate soft-body sim is prohibitively expensive in
realtime, so the plan mirrors the broader bet: use an accurate
offline simulator and produce a cheap realtime *surrogate* that
approximates it — evaluated dynamically at runtime (responds to
arbitrary motion and collisions), not canned baked animation. Two
viable surrogate shapes: (a) **reduced-order / subspace deformable
dynamics** — project the accurate sim onto a small modal basis,
physical and orders of magnitude cheaper; (b) **learned dynamics**
— a neural net trained against the offline accurate sim, as the
frontier / fallback option. Either surrogate must be deterministic
(fixed weights / deterministic evaluation) to satisfy the seeded-
simulation invariant. A trained soft-body net is fully compatible
with the build-time-inference / deterministic-hot-loop principle
precisely because it is deterministic — it is not a per-query LLM,
and should not be confused for one. Status: open R&D bet, same
multi-year horizon as the primary-motion ML bet above.

A high-want fidelity target — immersion-defining, feasibility
uncertain — is **fine-grained contact deformation**: fingers (or other
articulated parts) pressing into soft tissue and the tissue responding
locally, deforming and bulging around the contact point, with proper
two-way coupling between the rigid articulated part and the deformable
body. This is the hard case for the cheap-surrogate plan: reduced-order
/ subspace (modal) models capture global wobble well but smear out
arbitrary *local* deformation — a small modal basis handles coarse
jiggle but handles a finger poke poorly. This requirement therefore
pushes toward **learned or hybrid surrogates** (a cheap global base
plus local contact-detail handling, or a contact-aware enriched
subspace) rather than pure modal reduction. Two-way fine contact is
also the expensive part of the offline accurate sim — which is
acceptable, since the offline sim is where accuracy is paid for and the
surrogate is what gets baked/learned from it.

A finger poke is already the hard case for modal reduction, but it is
not the hardest rung. **Full-hand cupping, squishing, or grasping** is
harder: it introduces multiple simultaneous contact regions, large-
deformation (large-strain) loading across a wide area, and a visible
volume-redistribution requirement — displaced tissue must bulge
*between and around* the fingers — and with fingers splayed, tissue
actively redistributes up through the gaps between spread fingers, not
only around the periphery — not just at a single point. This is
where genuine volume preservation shifts from cosmetic to load-bearing.
It stresses the surrogate harder than a poke does: not localized
high-frequency detail, but *coordinated multi-region large-strain
deformation under grasp*. The correct mental image for the target
fidelity is the cupping/squishing case, not the poke; the poke is a
waypoint on the same ladder.

The realtime surrogate likely requires an **iterated solve, not a single
feed-forward pass**. Hard constraints — volume preservation and non-
penetration / contact — generally cannot be guaranteed by a one-shot
predictor: a neural net or reduced model will drift, slightly gaining or
losing volume, letting a fingertip sink in. The standard remedy is
**iterative constraint projection** (XPBD / position-based-dynamics
style: project distance, volume, and contact constraints over several
Gauss-Seidel passes until satisfied) — the same PBD already named for
cloth above. The surrogate is therefore plausibly a **hybrid: predict,
then project** — a learned or reduced predictor handles the expensive
global response, followed by a few cheap constraint-projection passes
to enforce volume and contact exactly. This iteration is most likely
*required* for the large-deformation cupping/squishing case. Determinism
is preserved as long as the stopping rule is deterministic — a fixed
iteration count is one sufficient case; so is iterate-until-convergence
with a deterministic error metric, threshold (epsilon), and max-iteration
cap. A convergence-based solve whose actual iteration count varies with
the input is still fully deterministic. Separately, the canonical (rest)
volume that the volume-preservation constraint targets must be a
read-only rest-state invariant: if the solver feeds its own output back
as the new target volume, volume drifts by feedback and the preservation
guarantee is defeated — compatible with the seeded-simulation invariant.

**R&D direction: physics-driven bodily transformation.** The same predict-then-project surrogate opens a direct path to physically plausible transformation sequences. Rather than lerping vertex positions from shape A to shape B (geometry that reads as sliding), treat the transformation as an *authored moving rest-state target* and let the surrogate dynamically track it — so in-between frames are the physics resolving toward the new shape: flesh redistributing, jiggling, settling, flowing. The payoff is the genuine phenomenology of what a physically realistic transformation would feel like IRL. This reuses the surrogate exactly: predict toward the evolving target each frame, project to satisfy volume and contact constraints. Reconciliation with the canonical-volume invariant: the invariant prohibits the *solver* from writing its output back as the new target (that is solver-feedback drift, which defeats preservation). A transformation deliberately re-authors the rest target over time as an *external authored drive* — categorically different. Volume during a transformation may be intentionally conserved (pure redistribution: flesh moves, total mass unchanged) or intentionally changed (growth, shrink) per the transformation's semantic intent; either is fine, since the target is authored input, never solver output. The invariant is unaffected. This bridges the body-customization / transformation system (the TiTS / Flexible Survival / Lilith's Throne transformation lineage — identity fluidity, deep species/body change, NSFW-first; see *NSFW-first with SFW toggle* and *Cosmetic depth*) and the soft-body physics R&D bet; cross-reference `~/git/rhizone/playmate` (`frond`) for the body/transformation/tag system. Status: R&D direction, not a committed spec.

### Perceptual vs physical realism (a useful distinction)

Worth keeping the distinction in mind: **physically accurate**
simulation is currently in the film-VFX-render-farm domain (hours
per frame). **Perceptually indistinguishable** is a different bar —
humans can't tell once you fake well enough, and real-time has
gotten good at faking. The goal is the latter, achieved via
specialized cheap solvers, careful design around weak spots, and
focal-area budgeting (pour budget into face, hands, body in mirrors;
cheaper elsewhere).

Weak spots to design *around*: static stress poses (cloth wrapping
under load, flesh squishing under pressure), extreme body-variation
proportions, close inspection (<30cm in VR), wet hair / fine detail,
hand grasping that needs actual physics contact not animation.

## The execution shape from here

Honest take from the conversation: pin and start executing. The doc
has decent shape; scaffolding + a first prototype slice will likely
teach more than further speculation. Several open questions
(per-activity design, content authoring detail, persistence
specifics) will get clearer from *building* than from chat.

**Concrete next steps:**

1. **Scaffold via godogen** — done; static scaffolding used in lieu
   of godogen's autonomous-agent flow, given the substantial design
   doc already in hand.
2. **First prototype slice** — choose between:
   - **Movement prototype** (parkour 2.0 carve/momentum feel) — the
     per-second dopamine engine the design depends on. Recommended
     first because (a) load-bearing, (b) feel-able within days, (c)
     informs setting/level design.
   - **Simulation substrate** (`existence`-pattern at 3D scale) —
     the deterministic seeded sim layer, NPC state, time/weather.
3. Iterate from there; bring `playmate` back in as cross-reference
   once scaffolding stabilizes.

## Meta-commitments (carry-forward)

- **No copouts.** Stylization-as-escape-from-realism, scope-reduction,
  dropping target hardware, mocap-as-the-bet, single-spine framing —
  all explicitly rejected.
- **Shipping less than the full synthesis is unacceptable.** Half the
  place is not a smaller place, it's a tech demo.
- **Multi-year R&D-shaped commitment.** Phased fidelity is acceptable;
  scope reduction is not.
- **Don't commit to architectures that preclude future approaches;
  don't depend on tech that isn't viable yet.** Composable, modal,
  additive.
- **The list grows.** Power fantasies, activities, references —
  the doc records as commitments land. It does not freeze the
  catalogue.
