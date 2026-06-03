# NPC mind, dialogue, and language generation

Status: **R&D DIRECTION / PILLAR — not a frozen spec** (2026-06-03)

Scope: the architecture *direction* for how aeriea's NPCs think and how
they speak — the cognitive/personality simulation underneath, and the
language generation on top. This is an R&D pillar: it records the two
demands decided this session, the load-bearing spine that resolves them,
and the framing that makes it one consistent project stance. It is
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

## The spine — "simulation underneath, rendering on top" applied to LANGUAGE

The load-bearing pipeline:

> **Brain** (the deterministic cognition / personality simulation)
> **→ communicative intent** (a language-INDEPENDENT semantic act:
> speech-act type + propositional content + stance / affect + register +
> memory references)
> **→ NLG engine** (grammar + semantics + authored fragments + procedural
> + hybrid, deterministic)
> **→ surface text**.

The load-bearing abstraction is the **middle seam**: communicative intent
is **MEANING, not words**. The NPC decides *what it means to convey* —
the speech act (assert / ask / tease / reassure / refuse / confide …),
the propositional content, the stance and affect behind it, the register
it intends, and which memories / facts it is referencing — entirely
*before* any words exist. The NLG engine is what turns that meaning into
a surface utterance.

This seam is what makes the brain and the prose **separable**: the brain
is responsible for meaning; the NLG engine is responsible for words;
neither needs to know the other's internals. It is also what makes "the
same NPC reads differently across moods" *fall out for free* — one
communicative intent, realized differently as the brain's affect /
register vary, is one intent with mood-varied realization, not a separate
authored branch per mood (`DESIGN.md` → *Platform for depth*: "Same NPC
reads differently across moods"). And it is **where determinism lives**:
both the brain state and the communicative intent are deterministic
functions of `seed + event log`, and the NLG is deterministic given
(intent, brain state, seed) — so the whole chain is reproducible.

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

### The NPC's half — the brain→intent→NLG pipeline

The **NPC's half is its expression**: the brain → communicative intent →
NLG → surface text pipeline above. The NPC does not read a dialogue tree;
it generates an utterance from what it means to say.

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
`seed + event log`**. The NLG is **deterministic given (intent, brain
state, seed)**. The entire chain therefore replays bit-for-bit on one
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

## Peer R&D bet with the soft-body surrogate

The beyond-SOTA grammar-and-semantics generator and the physically-accurate
real-time soft-body sim are **PEER moonshots with the SAME shape**:

- a capability current real-time tech **cannot deliver online**;
- resolved by an **offline-accurate or build-time-trained model**, lowered
  to a **deterministic real-time surrogate**;
- with **online / per-query inference forbidden**.

This is one consistent project stance for "beyond-SOTA yet deterministic,"
spanning **physics** (soft-body / contact deformation / physics-driven
transformation) and **language** (semantic→surface generation). Neither is
a copout: in both cases the hard accuracy is paid for offline and the
runtime evaluates a deterministic surrogate, rather than either shipping a
cheap fake or calling an online black box in the hot loop.

Cross-link: the soft-body physics R&D direction in `DESIGN.md` →
*Secondary / soft-body physics* (and the *animation/fidelity bet*
framing) and the body/animation backlog in `TODO.md`. The language
generator is the linguistic instance of the same bet the soft-body sim is
the secondary-motion instance of.

---

## No-copouts mandate (the governing constraint)

At **every layer**, the honest construction is mandatory:

- **Brain** must be a real cognitive model — memory, beliefs, drives,
  emotion, relationships, theory-of-mind, personality — **not a mood
  scalar**.
- **Communicative intent** must be a genuine semantic representation —
  meaning, not words — **not a label that maps 1:1 to a canned line**.
- **Realization** must be real grammar + semantics, with authored /
  procedural / hybrid all first-class — **not mad-libs, and not an LLM
  call in the loop.**

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
- **Names.** Names for the brain, the intent representation, and the NLG
  engine are the lead's to set; none are coined here.
