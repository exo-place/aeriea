# Simulation depth & deterministic lazy materialization

Status: **FOUNDATIONAL R&D DIRECTION — open problem, not a frozen spec** (2026-06-15)

Scope: this doc records the architecture *direction* for the substrate that holds
the depth the prose realizer renders — the deep, self-consistent simulated
character and world that `prose-generation.md` establishes the prose can never
exceed. It is the **substrate-architecture upstream of the prose realizer**: that
doc's *Depth is upstream* section names this substrate as the binding constraint
on "beats handwritten" and explicitly sites it outside its own scope; this doc
takes that sited problem up. It resolves one specific paradox — how a simulation
can be both *unreasonably deep* and *causally deterministic* without either
confabulating detail after the fact or paying to generate everything at full
fidelity from `t=0`. It contains **no engine code** and touches no entrypoint; it
is a design direction, not an implementation and not a frozen spec. The
resolution (deterministic lazy materialization) is sound, but several genuinely
hard sub-problems — chiefly *constrained deterministic refinement* — are
unsolved, and each is marked open. No mechanisms are invented beyond what was
decided; no names are coined.

---

## Why this exists

`prose-generation.md` establishes its single most load-bearing scope boundary:
**prose depth is upper-bounded by simulation depth.** The realizer is a lens — it
can "render the depth the substrate holds, faithfully and at high quality; it
**cannot create depth the substrate lacks**." This is forced by faithfulness:
depth the simulated brain does not actually hold, "if rendered anyway, *invented*
interiority: that is **confabulation**, which faithfulness flatly forbids." So
the realizer is "**necessary and nowhere near sufficient**," and "the binding
constraint on 'beats handwritten' is the **brain and the world**, not the
realizer."

The consequence is unforgiving and it is *this doc's whole reason to exist*:
"beats handwritten on quality" reduces, upstream, to having an **unreasonably
deep, self-consistent simulated character + world** — "memory, beliefs,
contradictions, personal history, self-image, relationships with real texture,
theory-of-mind, and a world of genuine semantic richness." That is the depth
ceiling the realizer surfaces but never lifts. Building a substrate that *holds*
that depth is the real moonshot, and `prose-generation.md` relocates it here
("a larger problem, sited upstream, that this doc *depends on* but does not
solve").

But pursuing that depth collides with the project's hardest invariant, and the
collision has two horns. Naming them precisely is the rest of this section's job;
the next section states them, and the one after resolves them.

## The tension, stated precisely

Both horns are real. Either one alone would be fatal; together they look like a
contradiction. The resolution dissolves the contradiction rather than choosing a
horn.

### Horn 1 — causality forbids naive post-hoc refinement

Determinism in aeriea is a hard invariant, not a preference. NPC "brain state and
communicative intent are **deterministic functions of `seed + event log`**"
(`npc-mind-and-language.md` → *Determinism & the LLM line*), the brain "is a
function of `seed + event log` exactly like the rest of the simulation," and "the
entire chain therefore replays bit-for-bit on one runtime" (under "the same
cross-platform-float caveat the movement / affordance substrates carry").

That invariant *forbids* the obvious way to get more depth: inventing
character/world detail **after the fact**. If, when the player finally asks about
an NPC's childhood, you fabricate a childhood that was *not* a determined
consequence of causally-prior state, you have asserted something the seeded
timeline never entailed. That is precisely the **confabulation** faithfulness
forbids (asserting past your evidence), and it **breaks replay**: a re-run from
the same `seed + event log` would have to reproduce a detail that no prior state
determined. Post-hoc invention is the determinism violation wearing a depth
costume.

### Horn 2 — eager full fidelity is impossible

The opposite tactic — determine *everything* at full fidelity from `t=0`, so
nothing is ever invented later — fails on two counts at once:

- **Prohibitive cost.** Generating every NPC's complete interior life, every
  object's full provenance, every relationship's complete texture, eagerly and at
  full fidelity, for an entire persistent world, is not affordable — least of all
  on the per-tick budget the project already commits to ("most of the world is
  reasoned about *coarsely and nearly for free* … real compute is spent **only on
  the focal thing**," `semantic-layer.md` → *Semantic LOD*).
- **Unbounded depth.** Even granting infinite compute, the depth is genuinely
  *unbounded*: you can always probe one level deeper (the NPC's memory of their
  parent → that parent's cooking → the specific dish → its smell on a specific
  afternoon → …). There is no finite "full fidelity" to eagerly compute; the
  whole is infinite, so "compute it all up front" is not even well-defined.

So depth cannot be invented late (Horn 1) and cannot be computed early (Horn 2).

## The resolution: deterministic lazy materialization

The paradox dissolves once you **separate when a fact is COMPUTED from when it is
causally DETERMINED.** They are not the same time, and conflating them is what
generates the false choice between the two horns. A fact can be *determined* by
`seed + rules` from `t=0` while being *computed* only when something first needs
it. Lazy evaluation over the seeded timeline is the whole idea.

### Latent vs committed

Unobserved detail is **latent**: deterministically derivable, but not yet
binding. The NPC's childhood, the wine's vintage, the scar's origin — all are
*derivable* from the seed and the rules the instant the world exists, but until
something *forces* them they are unevaluated thunks, constraining nothing.

Once a latent fact is **observed** — rendered to the player, reasoned over by an
NPC, otherwise entering the event log — it **crystallizes**: it becomes part of
the causal record and from then on **constrains all future materialization**.
Latent is the unforced thunk; committed is the forced, recorded value. (Exactly
*what* forces a thunk — the commitment boundary — is itself an open question; see
*Crystallization* and *Open threads*.)

### Purity = causality

The load-bearing claim is that a latent fact is a **pure function of `(seed,
causally-prior event log, stable fact-identity)`**. Its value is *fixed* by
`seed + rules` from `t=0`; you have simply not evaluated the thunk yet.
Materializing it on first observation is therefore **reading ground truth, not
inventing it** — the value was always there to be read. This is **referential
transparency over the seeded timeline**: forcing the thunk early or late yields
the *same value*, because the value is a function of nothing but `seed`, the
causally-prior log, and the fact's stable identity — never of *when* you asked.

This is *exactly why it is not Horn 1's post-hoc confabulation.* Confabulation
asserts what is **not** determined; this asserts the value that **is**
determined, derived on demand. The distinction is the entire difference between a
faithfulness violation and a faithful read. Same surface behavior (a detail
appears the first time it is needed), opposite causal status (invented vs.
derived).

Concretely, this is **procedural generation done correctly** — the
**derive-don't-store** discipline, made *causal* by purity. It is the same shape
as deriving a planet's terrain from its coordinates plus a world seed rather than
storing the whole galaxy: the planet was always *that* planet; visiting it
*reads* it, it does not *author* it. Aeriea's twist is to make the derivation a
function of the **causally-prior event log** as well as the seed — so that what
has *already happened* (and already crystallized) participates in deriving what
is read next. That causal dependence is what graduates ordinary procgen into a
determinism-respecting depth substrate.

## Bounding the unbounded: faithful-coarsening LOD

Purity answers Horn 1. It does **not** by itself answer Horn 2's unboundedness —
purity says each latent fact has a fixed value, but there are infinitely many
latent facts, and you still cannot force them all. The answer to unboundedness is
that **you never materialize the infinite whole**: you materialize only the thin
slice currently in focus, at the fidelity that slice's attention earns.

This is `semantic-layer.md`'s **foveated reasoning** ("mipmaps for meaning")
applied to materialization. Most of the world is reasoned about "*coarsely and
nearly for free* … and real compute is spent **only on the focal thing** — the
NPC you are talking to, the object in your hand," on "a per-tick budget,
allocated by attention / focus." You pay only for the **foveal slice** you
actually render; the periphery stays coarse and cheap, and the unbounded depth
beneath the periphery stays *latent* (derivable, unforced, free).

Progressive refinement is what makes this safe to do incrementally, and it is
safe **only because of the mipmap correctness spine.** Quoting it from
`semantic-layer.md` → *Semantic LOD*:

> The coarse level must be a *faithful coarsening* of the fine level. A glance
> and a deep inspection of the same thing must **never contradict** — the cheap
> answer must be a true summary / prefix of the expensive one, never a
> different answer. Otherwise you get **"popping"**: knowledge visibly
> *changing* as you lean in, which breaks immersion AND determinism. The LOD
> levels must be **coherent, seed-stable projections of one ground truth**.

The materialization corollary: when you **later** materialize fine detail for
something previously known only coarsely, that fine detail is **constrained to be
consistent with the coarse fact already committed**. Refinement *elaborates
within* prior commitments — it adds detail beneath the summary — but it **never
overturns** the summary. Leaning in reveals *more*, never *contradictory*,
exactly as a mipmap level reveals more of the same image and never a different
image. A coarse commitment ("an older NPC, gruff, ex-military bearing") is a
*prefix* every later fine materialization (the specific regiment, the specific
war, the specific loss) must extend, not contradict.

So the foveal slice is bounded (you pay for what you render), and progressive
refinement *within* the slice is safe (the coarse commitment fences the fine
draw). Horn 2 is answered: not by computing the unbounded whole, but by never
needing to.

## Crystallization: latent → committed

Crystallization is the act that moves a fact across the line from latent
(derivable, non-binding) to committed (recorded, binding). It is the hinge of the
whole scheme, and it is where this substrate plugs into the existing determinism
machinery.

- **Commit-on-observation.** A latent fact crystallizes when it is first
  *observed* — rendered to the player, reasoned over by an NPC, or otherwise
  forced into the event log. Before that moment it constrains nothing; after it,
  it constrains everything downstream.
- **The event log is the causal spine.** Crystallized facts enter the **event
  log** — the same `seed + event log` that all simulation state is a function of
  (`npc-mind-and-language.md`). This is the reuse that makes the scheme honest
  rather than a parallel mechanism: a materialized fact is not a side-cache, it is
  a *recorded event*, and replay reconstructs it exactly as it reconstructs every
  other event. There is no second source of truth.
- **Committed facts constrain future materialization.** Once `apple#7`'s color
  has crystallized, every later materialization that touches it — the NPC who
  remembers eating it, the still-life that depicts it — must be consistent with
  the committed color. The crystallized set is the **accumulated constraint
  environment** that every subsequent fine draw must satisfy. This is the same
  faithful-coarsening discipline as the LOD spine, now operating across *time and
  facts* rather than across *levels of one fact*: nothing later may contradict
  what is already on the record.

The crystallized set therefore only grows, and every growth is a tightening
constraint on what may be materialized next. (How *much* a single observation
crystallizes — does mentioning an NPC's parent commit the parent's whole life,
or only the fact of the parent? — is the *commitment boundary* problem, open
below.)

## The hard invariant: no order-dependent fill

There is exactly one way lazy materialization can go wrong, and forbidding it is
a hard invariant of this substrate:

> **Materialization is a pure function of *causally-prior* state and stable
> fact-identity — NEVER of access order.** What you observe *first* must not
> change the answer.

If observation **order** leaks into the materialized value — if probing fact A
before fact B yields a different B than probing B first — then the value is no
longer a pure function of `(seed, causally-prior log, fact-id)`; it is also a
function of the access path. The consequences are exactly the failures the project
treats as defects:

- **Replay diverges.** A re-run that happens to force thunks in a different order
  produces different state — the seeded timeline no longer reproduces, violating
  the bit-for-bit invariant (`npc-mind-and-language.md`; `movement-substrate.md`
  §3). This is the same class of bug as iterating a Dictionary in
  nondeterministic order, which `movement-substrate.md` catches with the
  golden-trace hash — here it would be the *materializer* leaking order instead.
- **Multiplayer desyncs.** Two clients observing the same world in different
  orders would crystallize different facts — the world forks. Order-independence
  is the precondition for a shared, self-hosted, replayable world.
- **It becomes *real* post-hoc confabulation.** If the answer depends on when you
  looked, then looking *is* what set the answer — the fact was not determined by
  causally-prior state, it was authored by the act of observation. That is Horn 1
  sneaking back in. Order-dependence is the exact failure mode that collapses the
  faithful-read back into invention.

This is why the resolution insists materialization depend **only** on
*causally-prior* state (the seed and the already-committed log) plus the fact's
**stable identity** — and on nothing about the access path. The whole scheme
stands or falls on this invariant.

## Reconciliation with the determinism invariant

Deterministic lazy materialization is **not a loosening** of `seed + event log`
determinism — it is a **strict refinement** of it. The contract is unchanged:
every fact is a deterministic function of `seed + event log`. What is added is
*laziness* — a fact is *evaluated* only when first forced — and the **no-order
invariant** guarantees the laziness is *transparent*: forcing early or late, in
any order, yields the same value, so the lazily-evaluated timeline is bit-for-bit
identical to a hypothetical eagerly-evaluated one. Lazy evaluation that preserves
the result is the textbook meaning of referential transparency, applied to the
seeded sim.

So this substrate inherits, unchanged:

- **Bit-for-bit replay** on one runtime, because materialization is pure over
  `(seed, causally-prior log, fact-id)` and the crystallized facts live in the
  same event log everything else replays from.
- **The cross-platform-float caveat** that the movement, affordance, prose, and
  NPC-mind substrates all carry (`npc-mind-and-language.md`;
  `movement-substrate.md` §3 — replay validity bounded by runtime, with the
  fixed-point door kept open). Materialization arithmetic is float arithmetic and
  is subject to the same caveat; this substrate does not solve cross-platform
  float determinism any more than its peers do, and stays shaped so a later
  fixed-point swap is a leaf change.
- **The build-time-only inference line.** Nothing here calls a model in the hot
  loop. Materialization is deterministic derivation over the seeded timeline; any
  learned component (e.g. a build-time-trained generator that *produces* latent
  detail) is the already-sanctioned offline-trained, deterministic-eval shape
  (`npc-mind-and-language.md` → *Determinism & the LLM line*), never per-query
  online inference.

In one line: this is `seed + event log` determinism with the addition that *when*
a fact is computed is decoupled from *when* it is determined — and the no-order
invariant is what keeps that addition free of cost to determinism.

## Relationship to depth-is-upstream and faithfulness

This substrate is the concrete answer to the question `prose-generation.md`
leaves upstream: **how do you get unbounded depth WITHOUT confabulation?** The
answer is *materialize on demand, faithfully.*

- **Unbounded depth** comes from latency: the depth is *always there* (a pure
  function of the seed), derivable to any level the player probes, without ever
  being eagerly computed. There is no finite authored ceiling — only the
  foveal-budget ceiling on what is *rendered* at once.
- **Without confabulation** comes from purity: every materialized detail is the
  *determined* value, derived from causally-prior state, never invented. This is
  the substrate-side guarantee of the realizer-side "zero confabulation" rule.
  The realizer may "assert only what is true of the model's state"
  (`prose-generation.md`); this substrate is what makes that state *deep enough
  to be worth asserting* while keeping every assertion a faithful read.

The prose realizer is therefore a **downstream consumer** of this substrate.
Rendering is one of the things that **forces a thunk**: when the realizer renders
the foveal slice, it *triggers materialization* of exactly that slice
(content-determination / salience over the sim's true state,
`prose-generation.md` → *Generator architecture §1*, now understood as forcing
the latent facts it selects). The realizer "renders the depth this substrate
holds and can **never exceed it**" — which is precisely *Depth is upstream* read
from the substrate side: the realizer is the lens, this is the depth the lens
focuses. And the faithful-coarsening spine that this doc uses to bound the
unbounded is the *same* spine `prose-generation.md` already owes at the prose
surface ("a coarse mention must be a **true summary of the fine** detail … No
'popping' at the language layer") — the prose realizer is honoring, at the
language layer, the materialization discipline this doc defines at the substrate
layer.

## Open threads

The resolution is sound; the following are genuinely **OPEN** and are *not*
claimed solved. The first is the hard technical core.

- **Constrained deterministic refinement — THE CRUX (OPEN).** When you
  materialize fine detail, it must satisfy **all** prior commitments
  *simultaneously*: the coarse summary already shown, *plus every other
  crystallized fact* it touches. Independent seeded draws are easy; seeded draws
  that must satisfy an **arbitrary accumulated constraint set** while staying a
  pure deterministic function of `(seed, causally-prior log, fact-id)` are
  **constraint satisfaction under a determinism requirement**. This is the hard
  technical core of the whole scheme, and it is unsolved. (It rhymes with the
  soft-body surrogate's *predict-then-project* shape in `TODO.md` — a draw
  followed by projection onto a constraint manifold — but here the manifold is the
  arbitrary, growing set of crystallized facts, not a fixed volume/penetration
  constraint, which is strictly harder.)

- **Stable fact-identity / canonical key namespace (OPEN).** Purity requires every
  latent fact to have a **canonical identity independent of the access path** —
  e.g. "NPC#7's affective memory of parent#2's cooking" must denote *the same
  thunk* however it is reached (through NPC#7, through parent#2, through a
  conversation about food). Without a stable key, "the same fact" forced via two
  paths could diverge — which is exactly the no-order violation. Designing this
  canonical namespace over an unbounded, lazily-growing fact space is nontrivial
  and unsolved.

- **The commitment boundary (OPEN).** What *exactly* crystallizes a latent fact —
  direct observation by the player, an NPC *inferring* it, a passing *mention*? —
  defines the edge of the binding set, and therefore how fast the constraint
  environment grows and how much later refinement is fenced. Too eager and you pay
  Horn 2's cost; too lazy and facts that *should* bind stay free and can drift.
  The boundary is undecided.

- **Cost of coarse-everywhere (OPEN).** Even coarse reasoning over a large world
  has **nonzero** cost; "coarsely and nearly for free" is not *free*. The per-tick
  attention budget (`semantic-layer.md`) must be a real, enforced budget, and how
  it is sized, allocated, and kept affordable across a persistent world is open
  (it ties to the still-open *LOD axis* — what detail varies along —
  `semantic-layer.md`).

- **Multiplayer / replay commit ordering (OPEN).** Order-independence is **doubly**
  load-bearing under concurrent observers: if two clients can crystallize facts
  in different orders, the no-order invariant must still hold *across clients*. How
  a single, well-defined commitment ordering is established over a distributed,
  self-hosted set of observers — what the canonical commit order even *is* when
  observations are concurrent — is unresolved.

These are unsolved. The architecture is a *direction* — a sound resolution of the
causality-vs-cost paradox — not an implementation, and its hard core
(constrained deterministic refinement) is owned, not designed away.

---

## Cross-links

- `docs/decisions/semantic-layer.md` — **the LOD machinery this extends.** This
  doc adopts its faithful-coarsening / "mipmaps for meaning" / foveated-reasoning
  spine verbatim as the answer to unboundedness, and **adds the half it lacks**:
  the *causal-lazy-materialization* discipline (latent vs committed, purity =
  causality, commit-on-observation, the no-order invariant) that turns
  level-of-detail over *known* facts into determinism-respecting materialization
  of *as-yet-uncomputed* ones.
- `docs/decisions/npc-mind-and-language.md` — **the depth this materializes, and
  the determinism invariant this refines.** Its *first* demand (the real
  cognitive/personality brain — memory, beliefs, drives, emotion, relationships,
  theory-of-mind, personality, autonomous inner life) is the prime example of
  depth that must be deep, causal, and bounded at once; its `seed + event log`
  determinism invariant is exactly what this doc refines (lazily, transparently).
- `docs/decisions/prose-generation.md` — **the downstream consumer.** Its *Depth
  is upstream* framing sites this substrate as the binding constraint it depends
  on but does not solve; rendering the foveal slice is what *forces* materialization
  here, and the realizer renders this substrate's depth and can never exceed it.
