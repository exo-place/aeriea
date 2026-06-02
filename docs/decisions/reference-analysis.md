# Reference-game analysis via the affordance / interaction-graph rubric

Status: **evaluation / design-target** (2026-06-03)

Scope: an evaluation of three NSFW-first reference games — **Trials in
Tainted Space (TiTS)**, **Lilith's Throne (LT)**, and **Flexible
Survival (FS)** — strictly through the affordance / interaction-graph
framework developed in `rhizone/github-io`. The framework is treated as
a rubric, not paraphrased: each game is assessed on each of its axes
(interaction-graph topology; affordance types and their composition;
affordance opacity / legibility; affordance surfaces). The whole
evaluation is anchored on the concrete weakness the project lead named
the **#1 problem** to design against — the "walking sim" failure — and
ends by stating aeriea's positive design target in the framework's own
terms.

These three games are in aeriea's reference set for **deep character
customization, transformation, identity fluidity, rich individual-NPC
content, NSFW-first done right, and procedural recombination** (see
`../../DESIGN.md` → *Reference set*, *Platform for depth*). This doc is
about what they get *structurally wrong* on the interaction axis — so
aeriea can take their content depth without inheriting their
interaction thinness.

The framework instrument, read firsthand:

- `../../../rhizone/github-io/docs/interaction-graph.md` — the graph =
  states/nodes + affordance edges; topology failure modes.
- `../../../rhizone/github-io/docs/affordance-types.md` — the type
  taxonomy; which types compose.
- `../../../rhizone/github-io/docs/affordance-opacity.md` — opacity /
  legibility; "what can I do here, and how do I know?"
- `../../../rhizone/github-io/docs/affordance-surfaces.md` — surfaces,
  Miller's Law, removal-not-prioritization.

**Governing principle.** When barren nodes dominate an interaction graph
— as in the 2D-grid walking sim or the wait→wait→wait re-roll loop —
the result is not merely low-density design; it *feels* like pointless
grind: samey, repetitive, grinding for its own sake. The defect is
phenomenological: the same low-meaning action repeating with no
variation, no compounding, and no meaningful change of state. That
grind-feel is why barren-node-dominated graphs are the failure mode to
design against — and it is exactly what aeriea's refusal of
quantity-gated repetition of identical actions names, stated at the
graph level.

---

## 0. The framework in one paragraph (as used here)

Per `interaction-graph.md`: **"Every affordance is an edge in the
graph."** The interaction graph is **"affordance structure: what can
you DO at any moment, and what does it lead to,"** answering **"what can
you do, and how do you know?"** Nodes are states; edges are affordances
of several *types* (`affordance-types.md`): **commands** (labeled,
executable, "highly composable and discoverable"), **gestural**,
**ambient** ("inform rather than act"), **navigational** ("change
context without transforming content"), **directional**, and
**data-entry** ("two-way channels … bindings between UI and state").
The decisive property is composition: per the type table, commands are
**"Composable: Yes"** while gestural, navigational, directional, and
data-entry affordances are **"Rarely"** or **"No."** **Opacity**
(`affordance-opacity.md`) is the gap between what is possible and what
is legible — *"Software hides what you can do."* **Surfaces**
(`affordance-surfaces.md`) are how a slice of edges is rendered, bound
by **Miller's Law** as **"a hard limit on human cognitive
architecture"** where **"the gain is removal, not prioritization."**

This evaluation uses one more distinction from the graph doc's failure
table that turns out to be the whole story here: a **barren node** is a
state with few outgoing edges — *"You can get here but there's nothing
to do"* — and the related shape problems **over-connected nodes**,
**sparse connections**, and **missing shortcuts**.

---

## 1. The symptom, diagnosed in the framework's terms

The project lead identified the single most important failure to avoid,
made concrete as two observable behaviors:

1. **Traversal on a 2D grid** — movement between tiles / locations is
   the dominant interaction; you spend most inputs *getting somewhere*.
2. **"wait → wait → wait" to trigger a sub-50%-chance event** — you
   repeat one generic action to re-roll a stochastic gate, hoping the
   event fires.

Diagnosed in the framework's vocabulary, verbatim where load-bearing:

> The 2D-grid walking-sim symptom is a **degenerate interaction-graph
> topology**: the dominant edge type is **navigational** — affordances
> that, per `affordance-types.md`, *"change context without
> transforming content"* — and navigational affordances are scored
> **"Composable: No."** So the player's moment-to-moment edges do not
> compose; each move is a context change that produces another node
> whose only meaningful edges are *more navigation*. In graph terms the
> map is a lattice of **barren nodes** — *"You can get here but there's
> nothing to do"* — connected almost exclusively by navigational edges.
> The interaction graph's defining question, *"what can you DO at any
> moment, and what does it lead to,"* resolves at most tiles to: *you
> can move; it leads to another tile.* That is a walking sim by
> definition, independent of whether the tile is drawn as ASCII, a 2D
> sprite grid, or a 3D space — the thinness is in the **affordance
> structure**, not the rendering.
>
> The "wait → wait → wait for a <50% event" symptom is the **same
> barren node observed in the time dimension instead of the space
> dimension**. `wait` is a single low-information **command** edge
> whose target node is *the same node* (or a stochastic neighbor), so
> repeating it is traversal of a **self-loop**. It is the framework's
> **"barren node"** failure — *"there's nothing to do"* — papered over
> with an RNG gate: the design substitutes *probability of an edge
> appearing* for *an edge that is reliably present and composes*. It
> also fails on the **opacity** axis: the affordance that matters (the
> event) is **invisible state** behind a hidden roll — the player
> cannot answer *"what can I do here, and how do I know?"*, only *"can
> I re-roll, and hope."* And it fails on **surfaces** in the inverse
> way to a cluttered menu: rather than too many edges, the surface
> offers **one** repeated edge, so there is nothing to *scan* — the
> Miller's-Law problem run backwards into a barren surface.

The compact statement: **a walking sim is a thin affordance graph — a
field of barren nodes joined by non-composing navigational edges (in
space) and stochastic self-loops on a single command (in time).** It is
the *opposite* of compositional density. The framework already names
the cure under *"Clean graphs, not filtered messy graphs"* and the
Normalize case study: **"collapsing them into three primitives:
`view`, `edit`, `analyze`"** — *"fewer concepts that compose beats many
specialized concepts that don't."* Walking-sim-ness is the absence of
the compose relation, not the presence of too few rooms.

---

## 2. Trials in Tainted Space

**Interaction-graph topology.** TiTS is a room/planet graph traversed by
compass-direction navigation (N/S/E/W, plus Approach / Leave). The
dominant edge type at the world layer is **navigational** — *"change
context without transforming content"* — so the world graph is exactly
the lattice-of-barren-nodes described in §1. Most rooms are barren
nodes whose outgoing edges are *more navigation* plus an occasional
parse-button (Talk, Examine, a scene). The "content" lives at leaf
nodes (encounters, NPC scenes); the graph between them is connective
tissue, not play. This is **sparse connections** ("related things are
many hops apart") wearing the costume of exploration.

**Affordance types present, and composition.** Almost everything is a
**command** edge (a labeled parse button: *Appearance*, *Masturbate*,
*Talk*, a combat verb) or a **navigational** edge (a direction). Per the
type table commands *are* composable in principle — but TiTS's commands
are overwhelmingly **terminal**: a button opens a self-contained scene
or stat readout and returns you to the node. They do not chain into one
another to build emergent states. The deep customization the reference
set prizes (`DESIGN.md` → *Reference set*) is real but lives mostly in
**data-entry**-shaped surfaces (set a name, a color, a slider-equivalent
via menu), and data-entry is **"Composable: No."** So TiTS is
*content-deep but composition-shallow*: many edges, little compose
relation between them. Combat is the one subsystem with genuine
command-composition (statuses, cooldowns, item use interacting) — and
notably it is the part that feels most game-like, which is consistent
with the framework: composition is where play lives.

**Opacity.** TiTS is comparatively **legible**: it is text, so every
available edge is enumerated as a labeled command on the surface —
*"actions as data,"* very nearly. There is little hidden-feature or
modifier-key opacity. But it exhibits the §1 time-axis opacity: many
encounters are RNG-gated on entering a room, so *"what can I do here"*
includes invisible stochastic edges that only the dice know about. The
content is legible; the *availability* of content is not.

**Surfaces.** The button list per room is usually within Miller's range,
so individual surfaces scan fine. The failure is not a 40-control
ribbon; it is the inverse — **barren surfaces** where the in-range
button set is mostly navigation and stat-inspection, so there is little
*to* scan that changes the world.

**Verdict.** TiTS exhibits the walking-sim pattern at the world layer
(navigational lattice of barren nodes) and the wait-to-roll pattern at
the encounter layer (RNG-gated edges), while escaping it locally only
inside combat, the one composable subsystem. aeriea wants TiTS's
*content depth and customization surface* (`DESIGN.md`) without its
non-composing world graph.

---

## 3. Lilith's Throne

LT is the most interesting of the three because it **partially escapes**
the symptom in one subsystem and exemplifies it in another — a clean
illustration that walking-sim-ness is per-subsystem, not per-game.

**Interaction-graph topology.** The world layer is the canonical
**2D-grid walking sim**: a tile map of a city you traverse tile-by-tile,
where most tiles are **barren nodes** joined by **navigational** edges,
with a stochastic encounter roll on movement — i.e. *both* of §1's
named symptoms literally co-located: grid traversal **and** wait/move-to-
re-roll a sub-certain encounter. By the rubric this is the textbook
degenerate topology.

**Where it escapes — the sex engine, on the same rubric.** LT's systemic
sex engine is a genuinely dense, composable graph, and it scores well on
*every* axis:

- *Topology:* a sex scene is a node-rich state space (positions,
  participant orientations, which body parts are engaged with which) with
  many outgoing edges per node — the opposite of a barren node. Edges
  reconfigure state rather than dead-ending.
- *Types & composition:* the edges are **commands** that **compose** —
  actions combine with positions, body configuration, fluids, arousal,
  fetish/preference state, and transformation effects to produce
  outcomes no single edge authored. This is exactly the framework's
  **"generalize, don't multiply"** virtue: a modest primitive vocabulary
  (act × target × position × body-state) yields a combinatorial space.
  It is also `DESIGN.md`'s *procedural recombination* (authored
  fragments + simulation state + composition) realized as an interaction
  graph.
- *Opacity:* mixed. The available acts are enumerated (legible
  commands), but preference/arousal/fetish weighting is partly
  **invisible state** that changes which edges do what — a real opacity
  cost, though a *systemic* one rather than a hidden-menu one.
- *Surfaces:* the act list can drift **over Miller's limit** in a busy
  scene — the failure mode flips from TiTS's barren surface to LT's
  *cluttered* surface (`affordance-surfaces.md`: a long list "stops being
  a *scanning* surface and becomes a *searching* surface"). The cure the
  doc names — *removal, not prioritization*; show *"the 5–7 things this
  user most likely wants to do right now"* — is exactly what a contextual
  sex-scene surface should do and mostly doesn't.

So LT demonstrates the thesis from both sides in one binary: **the same
game is a walking sim while you walk the grid and an immersive sim once
you are inside the composable subsystem.** The difference is entirely
whether the local edges compose, not the rendering — both layers are
rendered the same way (text + minimal UI).

**Verdict.** LT's sex engine is the closest existing reference to
aeriea's target interaction structure (dense, composable, systemic,
procedurally recombinant) and should be studied as a *positive*
exemplar on the rubric — while its city-grid traversal is precisely the
negative exemplar to design against.

---

## 4. Flexible Survival

**Interaction-graph topology.** FS (in both its MUD and single-player
lineages) is the strongest case of the §1 symptom in *both* dimensions
at once. The MUD heritage makes movement a room-graph traversal
(navigational edges between barren rooms), and its core transformation/
infection loop is heavily **time- and RNG-gated**: progress is often
*"wait / repeat a generic action until the stochastic transformation or
event fires."* That is the wait→wait→wait self-loop on a single command
named directly in §1 — the design substitutes *probability of an edge*
for *a present, composing edge*.

**Affordance types present, and composition.** Predominantly **command**
and **navigational** edges, with the transformation system expressed as
**data-entry**-adjacent state (your TF gauges / parts) that *renders*
descriptive variety but is **"Composable: No"** as an affordance —
changing your form changes flavor text and some gates, but the player's
*moment-to-moment edges* don't compose into emergent action sequences
the way LT's sex graph does. The variety is in the **content rendered
from state**, not in a composable action graph. By the framework this is
the same diagnosis as TiTS: content-deep, composition-shallow.

**Opacity.** Higher opacity than TiTS or LT. The infection/TF system has
substantial **invisible state** (thresholds, weighted roll tables) and
the player frequently cannot answer *"what can I do here, and how do I
know?"* — the relevant edge is a hidden roll, the canonical
`affordance-opacity.md` complaint. The MUD surface also leans on
*tribal-knowledge* commands (verbs you must already know to type),
which the opacity doc names directly as the *"keyboard shortcut with no
hint"* / hidden-affordance bottom tier.

**Surfaces.** Parser/MUD surface: the available edges are *not* rendered
as a scannable set at all — you must *know the verb*. This is the most
opaque surface of the three by the rubric (no enumeration → maximal
search cost), even though it has the *fewest* visible items.

**Verdict.** FS most fully embodies the failure aeriea is designing
against: navigational lattice **plus** stochastic self-loops **plus**
high opacity. aeriea takes from FS the *transformation/identity-fluidity
content ambition* (`DESIGN.md` → *Reference set*) and explicitly rejects
its interaction structure.

---

## 5. Cross-cutting reading

| Axis | TiTS | LT (world) | LT (sex engine) | FS |
|------|------|-----------|-----------------|-----|
| Dominant edge type | navigational + terminal command | navigational | composing command | navigational + terminal command |
| Local composition | low (combat only) | none | **high** | low |
| Barren-node lattice? | yes (world) | yes (grid) | no | yes (rooms) |
| Wait/RNG self-loop? | at encounters | on movement | no | **pervasive** |
| Opacity | low (legible text) | low–med | medium (systemic) | **high** (tribal/hidden) |
| Surface failure | barren | barren | occasionally cluttered | unenumerated |

The pattern: all three are **content-deep and composition-shallow at the
world layer**, and the one place any of them becomes an immersive sim
(LT's sex engine) is exactly the one place the local edges *compose*.
Composition is the variable that separates "walking sim" from "immersive
sim" on this rubric — not fidelity, not rendering, not content volume.

---

## 6. The aeriea design target (the positive inverse)

Stated in the framework's terms, aeriea's interaction-structure target
is the inversion of §1:

> **Dense, composable interaction graph; few barren nodes; few
> non-composing navigational lattices; no stochastic self-loops standing
> in for play.** Every state the player occupies should offer a small
> (Miller-compliant, ≤7) set of edges that are predominantly **composing
> commands / gestural / directional** affordances — affordances that
> *transform state and chain into one another* — rather than
> **navigational** edges that merely *"change context without
> transforming content."* Where navigation exists (traversal between
> places), traversal itself must carry composing edges so the move is
> play, not tax — which is exactly `DESIGN.md`'s *parkour 2.0 / "movement
> that doesn't waste your time"*: the commute *becomes* the pleasure
> precisely because the traversal edges compose (carve × jump × wall-run
> × momentum) instead of being bare context-changes. Stochastic gates,
> where present, must never be the *only* edge: the player must always
> have a present, composing affordance, so there is never a "wait → wait
> → wait to re-roll" as the dominant verb.

This is the same commitment the design doc already makes elsewhere,
re-expressed on this rubric:

- **Movement substrate as composing edges.** The data-driven movement
  kit (`movement-substrate.md`; bullet jump proven as pure-data
  composition) is literally a *composable command/directional vocabulary*
  — the framework's *"generalize, don't multiply … fewer concepts that
  compose"* applied to traversal. It is the antidote to the navigational
  lattice.
- **Simulation underneath, rendering on top.** `DESIGN.md`'s core
  architecture *is* the framework's separation of the interaction graph
  (the sim — the real affordance structure) from its projection (the
  rendering). The graph lives in the simulation; the 3D / VR / text view
  is a projection of it.
- **Density, not cadence; pull not push.** `DESIGN.md`'s
  *density-of-available-content* is the rubric's *"clean graph"* with
  many real edges available to pull — not a push-cadence RNG self-loop.
- **Diegetic UI / radial menus.** `DESIGN.md`'s on-body / multi-radial
  surfaces are the framework's *good affordance surface*: ≤7 items,
  removal-not-prioritization, spatial muscle memory (`affordance-
  surfaces.md` → radial menus + Fitts's Law + Miller-compliant 8
  segments).

### The key principle the lead emphasized: it must stand as pure text

> **If aeriea's interaction structure does not survive being rendered as
> pure text, it is a walking sim — and no amount of 3D fidelity will fix
> it.** The affordance / interaction graph lives in the *simulation*, not
> the *rendering* (this is `DESIGN.md`'s "simulation underneath,
> rendering on top," stated as an interaction-graph claim). A thin
> affordance graph is a walking sim whether rendered as text or as 3D;
> a dense, composable one is an immersive sim in either. Rendering is a
> *projection* (`interaction-graph.md`: *"Same underlying graph,
> different rendering. The 'paradigm' is the graph, not the pixels."*).
> Therefore fidelity can only ever *amplify* whatever the graph already
> is. 3D makes a dense graph more immersive and a thin graph more
> tediously beautiful.

This is consistent with `DESIGN.md`'s 100%-immersion north star rather
than in tension with it: immersion is *not* purchased by rendering
fidelity over a barren graph — a gorgeous walking sim still breaks the
"place worth being in" test because there is *"nothing to do"* (the
barren-node failure). Immersion is purchased by a dense composable graph
that fidelity then renders.

### Litmus test (falls out of the above)

**The pure-text reduction.** Strip aeriea to a text projection of its
interaction graph — every affordance rendered as an enumerated edge,
every state as text, no 3D, no VR, no animation. Then ask, at a
representative state:

1. **Composition:** are most available edges *composing* (they transform
   state and chain), or *navigational/terminal* (they change context or
   dead-end)? If the dominant verb is "go" or "wait," it is a walking
   sim.
2. **Barren-node check:** is there a state whose only edges are
   navigation? That state is a barren node — *"you can get here but
   there's nothing to do."*
3. **Self-loop check:** is there any state whose intended progression is
   "repeat one command to re-roll a hidden gate"? That is the
   wait→wait→wait failure; the gate must not be the only edge.
4. **Miller check:** does each state's edge set scan at ≤7, achieved by
   *removal* (only what's real now), not prioritization?

If the text reduction is *fun to play as a MUD*, the graph is dense and
the 3D/VR rendering will only amplify it. If the text reduction is
boring, no rendering will save it. **The text MUD is the unit test for
the interaction graph; the 3D client is the release build.**

> *Uncertain / to validate:* the litmus is a design heuristic, not yet
> an empirically validated gate. It is also possible that some aeriea
> affordances are *irreducibly* gestural/directional (a parkour line, a
> VR hand-grasp) and lose meaning in text even though the underlying
> graph is dense — the text reduction may under-credit genuinely
> spatial/embodied composition. Treat a *boring* text reduction as a
> strong negative signal, but a *thin-looking* one as a prompt to check
> whether the composition is spatial rather than as a verdict. This
> caveat is flagged, not resolved.

---

## 7. What aeriea takes vs. rejects from these three

- **Takes:** TiTS/FS deep customization, transformation, identity
  fluidity, NSFW-first posture; LT's systemic, composable, procedurally
  recombinant *engine pattern* (the positive rubric exemplar); all three
  as proof that authored-fragments + simulation + recombination delivers
  hundreds of hours without LLMs (`DESIGN.md` → *Platform for depth*).
- **Rejects:** the 2D-grid navigational lattice of barren nodes; the
  wait→wait→wait stochastic self-loop as a progression verb; MUD-style
  tribal-knowledge opacity (unenumerated verbs); content-depth used as a
  substitute for composition-depth at the world layer.

The one-line synthesis: **keep their content graph, replace their world
graph.**
