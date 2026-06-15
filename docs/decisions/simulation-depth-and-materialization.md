# Simulation depth & deterministic lazy materialization

Status: **FOUNDATIONAL R&D DIRECTION — open problem; prior "lazy materialization resolves it" framing CORRECTED (see below), core unsolved** (2026-06-15)

Scope: this doc records the architecture *direction* for the substrate that holds
the depth the prose realizer renders — the deep, self-consistent simulated
character and world that `prose-generation.md` establishes the prose can never
exceed. It is the **substrate-architecture upstream of the prose realizer**: that
doc's *Depth is upstream* section names this substrate as the binding constraint
on "beats handwritten" and explicitly sites it outside its own scope; this doc
takes that sited problem up. It frames one specific paradox — how a simulation
can be both *unreasonably deep* and *causally deterministic* without either
confabulating detail after the fact or paying to generate everything at full
fidelity from `t=0`. It contains **no engine code** and touches no entrypoint; it
is a design direction, not an implementation and not a frozen spec.

> **Correction (2026-06-15).** An earlier version of this doc claimed that
> deterministic lazy materialization *resolves* this paradox — that referential
> transparency over the seeded timeline makes the lazily-evaluated world
> bit-for-bit identical to a hypothetical eager one, dissolving the
> depth-vs-causality-vs-cost tension. **That claim is wrong and is retracted
> here.** Referential transparency makes late computation *consistent*, never
> *causal*: lazy materialization is either *sound-but-not-cheap* (every
> causally-live thunk is forced at its causal moment — eager for the depth that
> actually drives behavior) or *cheap-but-lossy* (decisions run on coarse
> stand-ins — generating the committed timeline from a lossy projection, which is
> exactly the latent lossiness this project rejects for timeline generation) —
> **never both.** The core problem is **unsolved.** The sections below preserve
> the reasoning trail (what was tried, what part survives, and precisely where it
> fails) but the current stance is unambiguous: lazy materialization is a narrow
> lossless *deferral* mechanism, not a resolution of the tension.

Several genuinely hard sub-problems remain open; each is marked open. No
mechanisms are invented beyond what was decided; no names are coined.

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
the next section states them, and the ones after examine the lazy-materialization
move that was once thought to dissolve them — and show why it does not.

## The tension, stated precisely

Both horns are real. Either one alone would be fatal; together they look like a
contradiction. Lazy materialization (next) was thought to dissolve the
contradiction; it does not — it only addresses one horn at the cost of
re-opening the other, as the analysis after it shows.

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

## The lazy-materialization move (and the line it cannot cross)

The move is to **separate when a fact is COMPUTED from when it is causally
DETERMINED.** They need not be the same time: a fact can be *determined* by
`seed + rules` from `t=0` while being *computed* only when something first needs
it. Lazy evaluation over the seeded timeline is the whole idea.

This move is real and useful — but it does **not** dissolve the paradox, and the
sections that follow trace exactly how far it reaches and where it stops. The
short version, stated up front so nothing below reads as a resolution it is not:

> **Lazy materialization is sound-but-not-cheap OR cheap-but-lossy — never both.**
> If every thunk a decision causally needs is forced at the moment of that
> decision, referential transparency holds and lazy *equals* eager — but you have
> eagerly computed the depth that actually drives behavior, so Horn 2's cost is
> untouched on the causal core. If instead decisions run on coarse stand-ins to
> avoid forcing the full interior, you save cost — but the committed timeline was
> generated from a **lossy projection**, lazy *does not* equal eager, and the
> fine detail materialized later is consistent-on-read yet **caused nothing**.
> That second branch is precisely the latent lossiness rejected for timeline
> generation. Referential transparency buys *consistency*, never *causality*.

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

### Purity buys consistency, not causality

The part of the move that survives is this: a latent fact, *if* it is a **pure
function of `(seed, causally-prior event log, stable fact-identity)`**, has a
value *fixed* by `seed + rules` from `t=0`; you have simply not evaluated the
thunk yet. Materializing it on first observation is then **reading ground truth,
not inventing it** — the value was always there to be read. This is **referential
transparency over the seeded timeline**: forcing the thunk early or late yields
the *same value*, because the value depends on nothing but `seed`, the
causally-prior log, and the fact's stable identity — never on *when* you asked.

This is genuinely *not* Horn 1's post-hoc confabulation, and that much holds:
confabulation asserts what is **not** determined; a pure read asserts the value
that **is** determined, derived on demand. Same surface behavior (a detail
appears the first time it is needed), opposite causal status (invented vs.
derived).

**But here is the line referential transparency cannot cross.** "Forcing the
thunk early or late yields the same value" is a statement about *consistency of a
value*, not about *whether that value participated in causation*. It guarantees
that a fact read late equals the fact that would have been read eagerly. It does
**not** guarantee that the late fact *caused* anything that was committed in the
meantime. Those are different properties, and the earlier version of this doc
conflated them. Two cases fall out, and they exhaust the space:

- **The thunk was causally live** — some decision actually *needed* its value to
  produce a committed event. Then a faithful, replay-correct world must force it
  **at that decision's moment**: the decision function reads it, and its value
  enters the causal record through that decision. Forcing it then is forcing it
  *eagerly* with respect to the depth that drives behavior. Referential
  transparency is satisfied, lazy *equals* eager — and Horn 2's cost on the
  causal core is paid in full. Laziness saved nothing here.

- **The thunk was causally inert (or causally disjoint)** — no committed decision
  ever read it. Then deferring it is free and lossless: it constrains nothing
  while latent, and reading it later is a faithful read of a value that was always
  there. This is where laziness legitimately saves cost — but *only* on detail
  that **caused nothing**.

So the only way to get cheap is to keep the expensive interior *out* of the
decisions that generate the committed timeline — i.e. to let decisions run on
coarse stand-ins. The moment you do that, the committed timeline is a function of
the **lossy stand-in**, not of the fine detail; the fine detail materialized
afterward is consistent-on-read but **causally vacuous** — it caused none of what
was committed. That is exactly the latent lossiness the project rejects for
timeline generation. *Cheap requires lossy; lossless requires eager-on-the-core.*

Where purity *is* legitimately load-bearing is in **procedural generation done
correctly** — the **derive-don't-store** discipline for the inert/disjoint case
above. Deriving a planet's terrain from its coordinates plus a world seed rather
than storing the whole galaxy is lossless deferral: the planet was always *that*
planet; visiting it *reads* it, it does not *author* it — and crucially, nothing
already committed depended on the unvisited planet. Aeriea's twist is to make the
derivation a function of the **causally-prior event log** as well as the seed.
That twist is sound **only for facts nothing committed has yet entangled with**;
the instant a fact is a live input to a committed decision, deferring it is no
longer free — it is the eager case wearing a thunk.

## The hard constraint: no lossy timeline generation

This is the rule that the corrected analysis forces, recorded as a **design
decision**:

> **DECISION — the causal timeline must NOT be generated from lossy state.** No
> coarse approximation, no compressed or learned latent, no lossy projection of
> any kind may stand in for a fact that a committed decision causally depends on.
> A decision that drives the committed timeline must read the true value of every
> fact it causally needs. Generating the timeline from lossy stand-ins —
> committing events caused by approximations and reconciling the fine detail
> afterward — is **rejected**, because the reconciled detail is consistent but
> caused nothing, which is the latent lossiness this project does not allow into
> timeline generation.

A direct corollary fixes the only honest cost lever:

> **The only cost lever that does not smuggle in lossiness is reducing WHAT is
> simulated — the size of the live / causal set — never the FIDELITY of what is
> simulated.** You may legitimately decide that fewer things are causally live
> (fewer agents acting off-screen, fewer threads entangling before observation);
> you may **not** legitimately decide that a live thing is simulated at reduced
> fidelity and patched up later. The first shrinks the cost honestly; the second
> is lossy timeline generation by another name.

## Valid uses of "lazy" (narrow)

Given the constraint, the legitimate scope of "lazy" is narrow and explicit:

- **Lossless deferral of a causally-DISJOINT subgraph.** An independent causal
  thread — one that nothing already committed depended on — may be computed on
  demand, deterministically, when it is first needed. Because nothing committed
  entangled with it, forcing it late yields the same world as forcing it early.
- **Causally-INERT detail that no decision ever reads.** Pure description that
  decorates the world without feeding back into any committed decision may stay an
  unforced thunk indefinitely.

And the use that is **NOT** valid:

- **Coarse approximation of an ENTANGLED cause.** A fact that a committed decision
  causally needs may not be replaced by a cheap stand-in at decision time and
  refined afterward. That is the cheap-but-lossy branch — rejected above.

## Bounding the unbounded: faithful-coarsening LOD

> **Scope of this section (corrected).** Faithful-coarsening LOD is legitimate as
> a discipline for **DESCRIBING / OBSERVING already-committed state** — the
> difference between a glance at and an inspection of something that *already
> happened*. It is **illegitimate as a means of GENERATING the causal timeline**:
> you may not let a coarse projection *cause* committed events and then reconcile
> the fine detail. The earlier version of this doc blurred these two; the
> distinction is load-bearing. Everything below applies to the *observation /
> description* side, where the no-popping spine is exactly right, not to timeline
> generation, where the hard constraint above forbids it.

LOD addresses how much of the world you must *render or summarize for the
observer* at once — but it does **not**, by itself, answer Horn 2's
unboundedness for the *causal* world, because the off-screen causal set (next
section's open crux) is a separate cost from the observed slice. For the observed
slice: **you never materialize the infinite whole**; you materialize only the
thin slice currently in focus, at the fidelity that slice's attention earns.

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

The materialization corollary, **for observation/description only**: when the
observer *later inspects* something they previously saw only at a glance, that
finer description is **constrained to be consistent with the coarse fact already
committed**. Refinement *elaborates within* prior commitments — it adds detail
beneath the summary — but it **never overturns** the summary. Leaning in reveals
*more*, never *contradictory*, exactly as a mipmap level reveals more of the same
image and never a different image. A coarse commitment ("an older NPC, gruff,
ex-military bearing") is a *prefix* every later fine description (the specific
regiment, the specific war, the specific loss) must extend, not contradict.

Read carefully, this is the *inert-detail* lazy case (above), not a cost lever on
the causal core: it is legitimate precisely when the fine detail being filled in
**caused nothing** that was committed in the interim — it only describes, more
finely, something already on the record. If instead the coarse summary had been
allowed to *drive a decision* and the fine detail were reconciled to it
afterward, this would be the rejected cheap-but-lossy branch: the summary, not the
true detail, would have caused the committed event.

So the *observed slice* is bounded (you pay for what you render), and progressive
*description* within it is safe (the coarse commitment fences the fine draw).
That bounds the **observation** cost. It does **not** bound the cost of a deep
*living* world, where things act causally off-screen before anyone observes them
— that is the un-cheated open crux, below.

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

This is why materialization must depend **only** on *causally-prior* state (the
seed and the already-committed log) plus the fact's **stable identity** — and on
nothing about the access path. The lossless-deferral discipline stands or falls on
this invariant.

## Reconciliation with the determinism invariant

Lazy *deferral*, kept within its valid scope (disjoint-subgraph + inert detail),
is **not a loosening** of `seed + event log` determinism — it is consistent with
it. The contract is unchanged: every fact is a deterministic function of
`seed + event log`. What deferral adds is that a fact is *evaluated* only when
first forced, and the **no-order invariant** keeps that deferral *transparent*:
forcing early or late, in any order, yields the same value.

> **Retraction.** An earlier version of this section claimed that "the
> lazily-evaluated timeline is **bit-for-bit identical to a hypothetical
> eagerly-evaluated one**," and offered that as a general property of the scheme.
> **That sentence is retracted.** It is true *only* for facts that are causally
> inert or disjoint — facts no committed decision read — and for facts that, being
> causally live, were forced *at their causal moment* (i.e. eagerly with respect
> to the decision that needed them). It is **false for causally-entangled state
> materialized lazily**: if a live fact is replaced by a coarse stand-in at the
> decision and reconciled later, the committed timeline differs from the eager one
> (it was caused by the stand-in), so lazy ≠ eager. Referential transparency
> equates the *value read late* with the *value read early*; it does **not** equate
> a *timeline generated from stand-ins* with one *generated from true values*.
> Consistency, not causality.

Within that valid scope, this substrate inherits, unchanged:

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

In one line: lazy *deferral* is `seed + event log` determinism with the addition
that *when* an inert-or-disjoint fact is computed is decoupled from *when* it is
determined — and the no-order invariant keeps that addition free of cost to
determinism. It does **not** decouple cost from causation for entangled facts;
that is the open crux below.

## Relationship to depth-is-upstream and faithfulness

This substrate addresses **one** of the two questions `prose-generation.md`
leaves upstream — *how do you get depth WITHOUT confabulation?* — and answers it:
*materialize on demand, faithfully*, within the valid lazy scope. It does **not**
answer the other — *how do you get a deep, living world at bounded COST?* — which
the corrected analysis re-opens as the un-cheated crux below. Faithfulness is
handled; cost is not.

- **Faithful depth on observation** comes from lossless deferral: the depth a
  player *probes by observing already-committed state* is derivable to any level
  without confabulation, bounded by the foveal budget on what is *rendered* at
  once. (This is the inert/disjoint case; it does not extend to the cost of a
  world that *acts* off-screen.)
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

The core is **unsolved.** The central crux, stated without the cheat the earlier
draft used, comes first; the previously-listed items remain genuinely open but are
**secondary** to it.

- **Deep LIVING world at bounded cost WITHOUT lossy-timeline generation — THE
  CRUX (OPEN).** A deep *living* world means agents act causally off-screen and
  entangle with the world *before* the player observes them. That off-screen
  agency is causally live by definition — its results feed the committed timeline
  the player later walks into — so it cannot be deferred as disjoint/inert, and
  (per the hard constraint) it cannot be generated from lossy stand-ins and
  reconciled later. That is **full forward-fidelity cost**, and lazy
  materialization **cannot dodge it**: laziness saves on what caused nothing, and
  a living world's off-screen acts cause things. How to obtain a deep living world
  at bounded cost without lossy-timeline generation is **unsolved.** Several
  candidate *directions* exist — **none chosen here; the positive resolution is an
  open decision the lead owns**:
  - *Causal-cone activation / dormant-until-entangled* — keep agents/threads
    dormant (truly disjoint, hence losslessly deferrable) until something already
    committed enters their causal cone, activating full-fidelity simulation only
    then. (Tension: a genuinely *living* world is supposed to act *before*
    entanglement; this risks a world that only comes alive on contact.)
  - *Bounded eager forward-simulation of a live population* — accept a fixed-size
    live/causal set simulated eagerly at full fidelity, and bound cost by bounding
    *what is live*, never its fidelity (the honest cost lever). (Tension: how the
    live set is chosen and bounded across a persistent world is itself open.)
  - *Time-coarse / event-driven forward sim that still commits full-fidelity
    events* — advance off-screen agency on a coarse *time* grid or only at salient
    events, but each committed event is still produced at full fidelity from true
    state (coarsening the *cadence* of simulation, not the *fidelity* of any
    committed step). (Tension: whether a coarse cadence can avoid being a lossy
    projection of the fine causal history is unproven.)

  These are enumerated as candidate directions, **explicitly un-decided.** The
  positive answer is not picked in this doc.

- **Constrained deterministic refinement (OPEN, secondary).** When you
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

- **Stable fact-identity / canonical key namespace (OPEN, secondary).** Purity requires every
  latent fact to have a **canonical identity independent of the access path** —
  e.g. "NPC#7's affective memory of parent#2's cooking" must denote *the same
  thunk* however it is reached (through NPC#7, through parent#2, through a
  conversation about food). Without a stable key, "the same fact" forced via two
  paths could diverge — which is exactly the no-order violation. Designing this
  canonical namespace over an unbounded, lazily-growing fact space is nontrivial
  and unsolved.

- **The commitment boundary (OPEN, secondary).** What *exactly* crystallizes a latent fact —
  direct observation by the player, an NPC *inferring* it, a passing *mention*? —
  defines the edge of the binding set, and therefore how fast the constraint
  environment grows and how much later refinement is fenced. Too eager and you pay
  Horn 2's cost; too lazy and facts that *should* bind stay free and can drift.
  The boundary is undecided.

- **Cost of coarse-everywhere (OPEN, secondary).** Even coarse reasoning over a large world
  has **nonzero** cost; "coarsely and nearly for free" is not *free*. The per-tick
  attention budget (`semantic-layer.md`) must be a real, enforced budget, and how
  it is sized, allocated, and kept affordable across a persistent world is open
  (it ties to the still-open *LOD axis* — what detail varies along —
  `semantic-layer.md`).

- **Multiplayer / replay commit ordering (OPEN, secondary).** Order-independence is **doubly**
  load-bearing under concurrent observers: if two clients can crystallize facts
  in different orders, the no-order invariant must still hold *across clients*. How
  a single, well-defined commitment ordering is established over a distributed,
  self-hosted set of observers — what the canonical commit order even *is* when
  observations are concurrent — is unresolved.

These are unsolved. The architecture is a *direction*, not an implementation, and
— corrected from the earlier draft — it is **not** a resolution of the
depth-vs-causality-vs-cost paradox. What it settles is the *faithfulness* half
(materialize-on-demand is a faithful read, not confabulation) and the *valid scope
of lazy deferral* (disjoint-subgraph + inert detail, never entangled-cause
approximation), plus the hard constraint that forbids lossy-timeline generation.
The *cost* half — a deep living world at bounded cost without lossy-timeline
generation — is the un-cheated open crux, owned and not designed away.

---

## Cross-links

- `docs/decisions/semantic-layer.md` — **the LOD machinery this builds on.** This
  doc adopts its faithful-coarsening / "mipmaps for meaning" / foveated-reasoning
  spine for the *observation / description* of already-committed state (per the
  corrected scope above — LOD is legitimate for observing committed state, not for
  *generating* the causal timeline), and adds the *lossless-deferral* discipline
  (latent vs committed, purity-buys-consistency, commit-on-observation, the
  no-order invariant) for the disjoint/inert case. It does **not** claim to bound
  the cost of off-screen causal agency — that is the open crux.
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
