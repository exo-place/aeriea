# NPC mind & expression (language + embodied performance)

Status: **R&D DIRECTION / PILLAR — not a frozen spec** (2026-06-03)

Scope: the architecture *direction* for how aeriea's NPCs think and how
they *express* — the cognitive/personality simulation underneath, and the
multi-channel realization of communicative intent on top. Language /
text generation is **one channel** among several; the same intent also
renders as embodied performance (expression, gaze, gesture, posture,
proxemics, prosody, in-world action). This is an R&D pillar: it records
the two demands decided this session, the load-bearing spine that resolves
them, and the framing that makes it one consistent project stance. It is
**not** an implementation, and it is **not** a frozen spec. Genuinely
open pieces are marked open; no specifics are invented beyond what was
decided.

This pillar is how `DESIGN.md` realizes *Rich worldbuilding / NPCs* (the
3rd power fantasy), *World agency*, *Platform for depth*, and System 25
(*Conversational presence, contextual, not dialogue trees*). It applies
the project's "simulation underneath, rendering on top" architecture to
**cognition and language** the way `movement-substrate.md` applies it to
traversal and `affordance-substrate.md` applies it to interaction.

---

## The two demands (decided this session)

Two demands were committed this session, both as first-class, neither
admitting a copout.

### 1. Characters need a real brain

Not a mood int — a genuine cognitive / personality simulation. The
minimum shape (fields and update rules remain open; see *Open threads*):

- **Persistent memory** — episodic (what happened, with whom, when) and
  semantic (facts the NPC knows / believes about the world and people).
- **Beliefs / knowledge** — what this NPC holds true, which may be
  partial, wrong, or private.
- **Drives / goals** — what it wants, at multiple horizons.
- **An emotion model** — affective state that evolves, not a scalar mood.
- **A relationship model** — per-other-agent state (the player included):
  history, stance, trust, intimacy.
- **Theory-of-mind about the player** — a model of what the player knows,
  wants, and feels, distinct from ground truth.
- **Personality traits** — stable dispositions that *bias all of the
  above*: how memory is weighted, how emotion responds, how goals are
  ranked, how the NPC reads others.
- **Autonomous inner life that continues between sessions** — the NPC
  thinks and acts when you are not there (the `fuwafuwa` / `ashwren`
  "thinks/acts when you're not there" pattern; `existence`-style state
  simulation extended to inhabitants). This is the same commitment
  `DESIGN.md` → *World agency* names ("lives that proceed in your
  absence and sometimes reach toward you").

This brain is **seeded-deterministic and part of the world sim** — its
state is a function of `seed + event log` exactly like the rest of the
simulation (`DESIGN.md` → *Deterministic seeded simulation*; the
`existence` pattern).

### 2. Text generation: every honest approach is first-class — no copouts

Hand-authored fragments **and** procedural recombination **and** hybrid
**and** a beyond-SOTA grammar-and-semantics-grounded generation engine
are **all FIRST-CLASS**. None is a fallback for another; the system
treats them as peers and may use any mix.

Two approaches are explicitly **ruled out** as copouts / defects:

- **Template mad-libs** — a label that maps 1:1 to a canned line with
  slots. A copout: it is not language generation, it is string
  substitution, and it cannot carry the brain's nuance.
- **Per-query / hot-loop LLM** — forbidden by the ecosystem principle
  ("the LLM is an oracle at the leaves, never the control loop";
  determinism is a hard invariant). Also a copout: it offloads the hard
  problem to an online black box and breaks determinism.

The authored / procedural / hybrid layer is the *proven* substrate
(`DESIGN.md` → *Platform for depth*: HHS+ / Accidental Woman / Lilith's
Throne deliver hundreds of hours without LLMs; see also
`reference-analysis.md` on LT's composable engine). The beyond-SOTA
generator is the R&D frontier (below). Both are honest; both are in.

---

## The spine — "simulation underneath, rendering on top" applied to EXPRESSION

The load-bearing pipeline:

> **Brain** (the deterministic cognition / personality simulation)
> **→ communicative intent** (a modality-INDEPENDENT semantic act:
> speech-act type + propositional content + stance / affect + register +
> memory references)
> **→ multi-channel realization** (a set of *deterministic projections* of
> the one intent — text/NLG, facial expression, gaze, gesture, posture,
> proxemics, prosody, in-world action)
> **→ surface performance** (the utterance plus the embodied behavior).

The load-bearing abstraction is the **middle seam**: communicative intent
is **MEANING, not a particular channel's output** — not words, not a
keyframe, not a viseme. The NPC decides *what it means to convey* — the
speech act (assert / ask / tease / reassure / refuse / confide …), the
propositional content, the stance and affect behind it, the register it
intends, and which memories / facts it is referencing — entirely *before*
any channel realizes it. Each realizer turns that one meaning into its
own surface: the NLG engine into a surface utterance, the embodied
realizer into expression / gaze / gesture / posture / proxemics / prosody
/ action. **Text / NLG is one realizer among several**, not the
privileged one.

This seam is what makes the brain and its realizers **separable**: the
brain is responsible for meaning; each realizer is responsible for its
channel; none needs to know the others' internals. It is also what makes
"the same NPC reads differently across moods" *fall out for free* — one
communicative intent, realized differently as the brain's affect /
register vary, is one intent with mood-varied realization across *every*
channel, not a separate authored branch per mood (`DESIGN.md` → *Platform
for depth*: "Same NPC reads differently across moods"). And it is **where
determinism lives**: both the brain state and the communicative intent
are deterministic functions of `seed + event log`, and each realizer is
deterministic given (intent, brain state, seed) — so the whole chain is
reproducible.

### Realization channels (the projections of one intent)

The same (intent, brain state, seed) projects onto multiple channels,
each a deterministic realizer:

- **Text / NLG** — the surface utterance (the language channel; detailed
  throughout this doc).
- **Facial expression** — affect and emphasis on the face.
- **Gaze / eye-contact** — where the NPC looks, and at whom.
- **Gesture** — hand/arm motion that carries or punctuates meaning.
- **Body posture** — the whole-body stance behind the affect.
- **Proxemics** — orientation, approach, and spacing in the world (how the
  NPC positions itself relative to the player and others).
- **Prosody / voice** — the vocal realization (timing, intonation, affect).
- **In-world action** — doing something, as an expressive act.

All are **deterministic projections of the same (intent, brain state,
seed)** — exactly like the text realization, and replayable on one runtime
under the same cross-platform-float caveat.

**Text = unit test; embodied 3D/VR performance = release build.** This is
the same relationship `reference-analysis.md` §6 draws for the world —
"the text MUD is the unit test for the interaction graph; the 3D client is
the release build" — now applied to NPC *expression*: the text rendering
is the litmus / lower bound (and keeps the pure-text-standalone bar intact,
below), and the embodied performance is the full rendering of the same
intent. This is **especially load-bearing in VR**, where gaze,
micro-expression, and proxemics *are* the immersion test — a correct
utterance with dead eyes and wrong spacing fails it.

---

## The two halves of a conversation (resolves the open substrate question)

A conversation has two halves, and they are built differently.

### The player's half — affordances

The **affordance substrate is the PLAYER's half**. The player expresses
themselves through composable **social verbs** (ask / tease / comfort /
flirt / challenge / share / …) whose **guards** read the NPC's brain
state and whose **effects** mutate it — the *same* verbs / guards /
effects engine as `affordance-substrate.md`, applied to a "social node"
instead of a valve or a pedestal. This is how player agency in
conversation stays composable rather than tree-shaped, and it is why
conversation passes the pure-text litmus by construction (see below).

> **Open:** whether conversation *literally reuses* the affordance
> substrate (a social node is just an interactable whose state is the NPC
> brain) or *extends* it (a parallel kit sharing the guard/effect
> vocabulary) is **unresolved** — the project lead said "I don't know."
> Either way, the player-agency half is **affordance-shaped**: composable
> social verbs gated by and mutating brain state. Recorded as open; the
> shape is decided, the substrate-identity is not.

### The NPC's half — the brain→intent→realization pipeline

The **NPC's half is its expression**: the brain → communicative intent →
multi-channel realization pipeline above (text being one channel). The
NPC does not read a dialogue tree; it generates an utterance — and an
embodied performance — from what it means to say.

So: **the player never walks a dialogue tree; the NPC never reads one.**
The player's half is an affordance graph; the NPC's half is generated
expression. This is exactly how `DESIGN.md` System 25 —
*conversational presence, not dialogue trees* — is realized, and it
**passes the pure-text litmus** (`reference-analysis.md` §6) **by
construction**: the affordance graph (composing social-verb edges) plus
the NLG (the enumerable expression) *is* the text layer. There is no
separate "rendering" hiding a thin graph; the graph and the language are
the thing.

---

## Determinism & the LLM line

NPC brain state and communicative intent are **deterministic functions of
`seed + event log`**. Each realizer (text/NLG and every embodied channel)
is **deterministic given (intent, brain state, seed)**. The entire chain
therefore replays bit-for-bit on one
runtime, consistent with the seeded-sim commitment and the same
cross-platform-float caveat the movement / affordance substrates carry.

**Per-query / online LLM in the loop is forbidden** — the ecosystem
principle: "the LLM is an oracle at the leaves, never the control loop …
build-time-only inference … per-query LLM in the hot loop is a defect"
(CLAUDE.md, Ecosystem Design Principles).

**Build-time-TRAINED, deterministic-eval components are permitted.** A
fixed-weight learned realizer — trained offline, evaluated deterministically
at runtime — is **not** a hot-loop LLM and is compatible with the
build-time-inference / deterministic-hot-loop principle precisely because
it is deterministic. This is the exact precedent the soft-body R&D note
already establishes for a trained surrogate (`DESIGN.md` → *Secondary /
soft-body physics*; TODO.md body/animation backlog): "a trained soft-body
net is fully compatible with the build-time-inference / deterministic-
hot-loop principle precisely because it is deterministic — it is not a
per-query LLM." The same reasoning licenses a build-time-trained language
realizer.

---

## Peer R&D bets — language, physics, and embodied performance

The beyond-SOTA grammar-and-semantics generator, the physically-accurate
real-time soft-body sim, and the **embodied expression realizer** are
**PEER moonshots with the SAME shape**:

- a capability current real-time tech **cannot deliver online**;
- resolved by an **offline-accurate or build-time-trained model**, lowered
  to a **deterministic real-time surrogate**;
- with **online / per-query inference forbidden**.

This is one consistent project stance for "beyond-SOTA yet deterministic,"
spanning **language** (semantic→surface generation), **physics**
(soft-body / contact deformation / physics-driven transformation), and
**embodied performance** (intent→expression / gaze / gesture / posture /
proxemics / prosody / action). None is a copout: in every case the hard
accuracy is paid for offline and the runtime evaluates a deterministic
surrogate, rather than either shipping a cheap fake or calling an online
black box in the hot loop. The embodied realizer specifically is **not**
canned / hand-keyed emotes-as-the-only-vocabulary, and **not** a runtime
black box — the same deterministic-surrogate shape as its two peers.

**The embodied realizer consumes the animation / soft-body pillar.**
Expression is partly *rendered through the same deformation surrogate*:
facial soft-tissue, secondary motion, and contact deformation are how
the affect on a face or in a posture actually shows. So the systems
interlock — the embodied realizer decides *what* to express from intent,
and the soft-body sim is part of *how* that expression is physically
realized.

Cross-link: the soft-body physics R&D direction in `DESIGN.md` →
*Secondary / soft-body physics* (and the *animation/fidelity bet*
framing) and the body/animation backlog in `TODO.md`. The language
generator, the soft-body sim, and the embodied realizer are three
instances of one bet — the linguistic, the secondary-motion, and the
expressive-performance instances respectively.

---

## No-copouts mandate (the governing constraint)

At **every layer**, the honest construction is mandatory:

- **Brain** must be a real cognitive model — memory, beliefs, drives,
  emotion, relationships, theory-of-mind, personality — **not a mood
  scalar**.
- **Communicative intent** must be a genuine semantic representation —
  meaning, not a particular channel's output — **not a label that maps
  1:1 to a canned line (or a canned emote)**.
- **Text realization** must be real grammar + semantics, with authored /
  procedural / hybrid all first-class — **not mad-libs, and not an LLM
  call in the loop.**
- **Embodied realization** must be a deterministic surrogate over the
  expression channels (face / gaze / gesture / posture / proxemics /
  prosody / action) — **not a fixed library of hand-keyed emotes as the
  only vocabulary, and not a runtime black box.**

This is the governing constraint on the whole pillar, and it is the
direct descendant of `DESIGN.md`'s 100%-immersion north star ("NPC
dialogue feeling robotic … fails the test") and the *no-copouts* posture
that runs through the design.

---

## Open threads (explicitly unresolved — not invented here)

- **Brain architecture.** The exact fields and the update rules
  (how memory decays / consolidates, how emotion responds, how traits
  bias updates) are open.
- **The generator's concrete approach.** The semantic-representation
  formalism for communicative intent, the realization grammar, and which
  components are build-time-learned (vs hand-built / procedural) are open.
- **The intent→embodied-channel mapping.** How one communicative intent
  projects onto facial expression / gaze / gesture / posture / proxemics /
  prosody / action — the per-channel realizers and their formalisms — is
  open (the embodied analogue of the generator's concrete approach).
- **Cross-channel coherence & timing.** How the channels stay mutually
  consistent and synchronized (utterance vs gesture vs gaze vs prosody —
  e.g. beat alignment, turn-taking, who-looks-when) so the performance
  reads as one coherent act rather than independent streams, is open.
- **Substrate identity for the player's half.** Whether conversation
  reuses vs extends the affordance substrate (above) is open.
- **NPC memory representation / storage** in the sim record; the concrete
  **relationship-state model**; and **KIM-style async text-presence**
  integration (NPCs reaching toward the player between sessions —
  `DESIGN.md` → *World agency*, persona research) are open.
- **Content-authoring mix weights** — the balance of hand-authored :
  procedural : hybrid : generated. Ties directly to the open
  *content-authoring strategy* question (`DESIGN.md` → *Open questions*;
  TODO.md).
- **Names.** Names for the brain, the intent representation, and the
  realizers (the NLG engine and the embodied-performance realizer) are the
  lead's to set; none are coined here.
