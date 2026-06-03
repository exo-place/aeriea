# Semantic layer (world-understanding)

Status: **FOUNDATIONAL R&D DIRECTION — open problem, not a frozen spec**
(2026-06-03)

Scope: the architecture *direction* for the layer of genuine real-world
**understanding** that the rest of aeriea's depth systems reason over — what
an apple is (its color, its varieties), what an Old Fashioned is (its recipe,
its ritual, its connotations), what habits, cultures, and traditions are.
This is an R&D direction, not an implementation and not a frozen spec. It
records the reasoning chain converged on this session — what the layer *is*,
why it is known-reachable, where the knowledge comes from, how it is
represented, where the hard part lives, and how that reconciles with the
project's determinism invariant — and marks every genuinely open piece as
open. No mechanisms are invented beyond what was decided; no names are coined.

This is the **deepest, foundational** R&D bet of the project: the NPC brain
reasons over it, the NLG speaks from it, and the affordance verbs / guards /
effects mean something because of it (see *It is the layer under the others*
below, and `npc-mind-and-language.md`, `affordance-substrate.md`). It sits
*beneath* those pillars, not beside them.

---

## What it is

A layer of genuine real-world **understanding** — knowledge as *concepts you
can reason with*, including novel combinations, not a lookup of stored
answers. The bar is: the layer must handle a request it has never seen by
*reasoning from what it knows* (what color is a Granny Smith; what would go in
a drink "like an Old Fashioned but lighter"; what a particular subculture
would consider rude), the way a person does.

The copout this refuses is a **finite fact-dump** — a big table of stored
answers. A fact-dump reduces understanding to *retrieval*: it can return the
lines someone wrote down and nothing else, and it has no answer for the novel
case (which is most cases). Reducing understanding to retrieval is the same
shape of copout the rest of the design rejects — mad-libs for language, canned
emotes for expression, baked animation for soft-body. The semantic layer must
*generalize*, or it is not understanding.

## Existence proof — it is known-reachable

Humans do this constantly, in real time, with no lookup table. That a human
can answer an unbounded space of novel questions about apples and Old
Fashioneds and traditions is the existence proof that genuine
reason-with-concepts understanding is **reachable** — it is a thing minds
demonstrably do. "Unsolved" is therefore not "impossible," and it is never a
license to copout. The frontier stays whole and hard; we do not shrink it
until it is easy (see *No-copouts* below).

## Where the knowledge comes from (how humans learn it)

Tracing the source of human world-understanding is what tells us the data
exists:

- **Grounded embodied experience** — some knowledge is learned by living in a
  body in a world (an apple is heavy in the hand, sweet in the mouth). This is
  real but is the *minority* of what any one person knows.
- **Massively cultural / linguistic transmission** — *most* of what a person
  knows is acquired **secondhand, through language**: read, told, overheard,
  absorbed from the culture. You did not personally verify what an Old
  Fashioned is; you were *told*, in words, by the culture that wrote it down.
- **Statistical exposure → generalization** — repeated exposure to instances
  builds the generalization (you have seen enough apples to know the
  distribution of apple-colors without ever being given a rule).
- **Prediction and correction** — the generalization is refined by being
  wrong and updating.

The load-bearing consequence: **we are not missing the data.** The
cultural-linguistic corpus humanity wrote down *exists* and is *accessible*;
that corpus is precisely the channel through which most human knowledge is
transmitted in the first place. An LLM's competence at exactly this kind of
world-understanding is **proof that the associations are carried in that
data** — independent of the LLM itself being a poor vessel for our purposes
(nondeterministic, opaque, an online black box). The point is not "use an
LLM"; the point is that the LLM's competence *demonstrates the data carries
the knowledge*. **The knowledge was never the bottleneck.**

## The representation: a prevalence-weighted knowledge graph

The decided representation is a **prevalence-WEIGHTED knowledge graph** —
RDF-style subject–predicate–object triples, but with the **weights as the
point**, not an afterthought. A flat, unweighted table says `apple → red`. A
prevalence-weighted graph instead carries the *distribution / typicality* of
the association: red is *typical*, green is *common*, yellow is *less so*.
Facts plus their prevalences are the beginnings of **judgment** — a sense of
what is normal, what is unusual, what is plausible — and judgment is exactly
what lets the layer *bend to a novel request* (compose, generalize, weigh
alternatives) rather than *retrieve a stored line*. The weights are what
distinguishes this from the fact-dump copout: an unweighted graph is still a
lookup table; a weighted one carries the shape of the world's typicality.
Runtime reasoning over the graph is **deterministic** — traverse, compose,
query, and seeded-sample over fixed weights — so there is no runtime black box
anywhere in the hot loop.

## The hard part = build-time extraction & cleaning (and why it isn't a copout)

The unglamorous 90% is **turning the messy corpus into a clean graph**:
deduplicated, sense-disambiguated triples (apple-the-fruit vs Apple-the-company)
with *trustworthy* prevalence weights. This is the genuine R&D difficulty, and
it is squarely a **BUILD-TIME** task.

This is exactly where the ecosystem principle already grants inference: "the
LLM is an oracle at the leaves, never the control loop … build-time-only
inference … per-query LLM in the hot loop is a defect" (CLAUDE.md, Ecosystem
Design Principles). So:

> An LLM (or any extractor) **mining the corpus into the graph OFFLINE is NOT
> a copout and NOT a determinism violation.** The messy, nondeterministic,
> opaque model is used *at build time* — precisely where it is sanctioned —
> to extract and clean associations and estimate prevalences. The runtime then
> ships a **clean, deterministic, prevalence-weighted graph** and **never
> calls the model in the hot loop**. The hard accuracy is paid for offline;
> the runtime evaluates a deterministic artifact.

This reconciles the tension that stalled the discussion: **the data exists**
(the corpus); **the messy model helps extract it offline** (build-time
inference, permitted); **a deterministic graph ships** (no hot-loop inference,
determinism preserved). It is the *same deterministic-surrogate shape* as the
project's other beyond-SOTA bets — offline-expensive / build-time-learned →
deterministic runtime — applied to knowledge instead of motion or language
(see `npc-mind-and-language.md` → *Peer R&D bets*; `DESIGN.md` → *Secondary /
soft-body physics*). The graph is the surrogate; the corpus + extractor is the
offline accurate source.

## Semantic LOD ("mipmaps for meaning") — a hard requirement

The layer must be **incredibly performant** and **arbitrarily
level-of-detail-able**. Most of the world is reasoned about *coarsely and
nearly for free* (background NPCs, distant objects, peripheral things), and
real compute is spent **only on the focal thing** — the NPC you are talking
to, the object in your hand. This is **foveated reasoning**: a per-tick budget,
allocated by attention / focus. It ties directly to the affordance
interpreter's once-per-tick **resolved frame** (`affordance-substrate.md` §5):
the focus / held / region context that the frame already resolves is the same
signal that says *where to spend the reasoning budget this tick*.

**The correctness spine — faithful coarsening (the mipmap property):**

> The coarse level must be a *faithful coarsening* of the fine level. A glance
> and a deep inspection of the same thing must **never contradict** — the cheap
> answer must be a true summary / prefix of the expensive one, never a
> different answer. Otherwise you get **"popping"**: knowledge visibly
> *changing* as you lean in, which breaks immersion AND determinism. The LOD
> levels must be **coherent, seed-stable projections of one ground truth** —
> the same discipline as the movement / affordance kits' interpreter↔compiler
> bit-equivalence (`movement-substrate.md`, `affordance-substrate.md`): two
> renderings of one definition that must agree.

This is the visual-LOD mipmap analogy taken literally: a mipmap level is a
faithful downsample of the level below it, not a different image; zooming in
reveals *more* detail, never *contradictory* detail. The semantic layer owes
the same guarantee for meaning. It is the knowledge-side counterpart of the
*Hierarchical LOD on sim* note already in `DESIGN.md`'s animation-fidelity bet
(high-res where the camera / mirror looks; downgrade off-screen).

Implementation split (decided in shape): **coarse levels are
precomputed / baked**; **fine levels are traversed on demand** (the focal
thing earns the deep traversal its attention budget allows).

> **OPEN — the LOD axis.** *What* the level-of-detail varies along is left
> open: traversal depth, breadth of relations considered,
> prevalence-cutoff (only above-threshold associations at coarse levels),
> abstraction level, or some combination. The *requirement* (faithful
> coarsening, no popping, seed-stable) is decided; the *axis* is not.

## Grounding (downstream, open)

The prevalence-weighted graph is the **cultural-linguistic half** of
knowledge — what the culture wrote down about apples. The **other half is
grounding**: binding the `apple` concept to the *actual rendered / physical
apple in THIS world* — its specific color, its weight in the hand, its
edibility, its affordances. A semantic layer that does not bind to the
embodied / affordance / physics substrates is **knowledge floating free of the
world**: it can reason about apples-in-general but cannot connect that to the
apple on the table the player is reaching for.

> **OPEN — the binding problem.** How a graph concept binds to a concrete
> world instance (and its rendered properties, its physics state, its
> affordance verbs / guards / effects) is recorded as an open downstream
> problem. The semantic layer *must* bind to the embodied / affordance /
> physics substrates; the *mechanism* of that binding is unresolved.

## It is the layer under the others

The semantic layer is **foundational — it sits beneath the other pillars**,
and they depend on it:

- **The NPC brain reasons over it.** Beliefs, knowledge, theory-of-mind, and
  the propositional content of communicative intent are *about* world concepts;
  the brain needs a substrate of concepts-to-reason-with
  (`npc-mind-and-language.md` → *Characters need a real brain*; the brain's
  "semantic memory — facts the NPC knows / believes about the world").
- **The NLG speaks from it.** An utterance's propositional content references
  world concepts; the language realizer turns *meaning about the world* into
  words, and that meaning is drawn from this layer (`npc-mind-and-language.md`
  → the brain → communicative intent → realization spine).
- **The affordance verbs / guards / effects mean something because of it.** A
  verb like "mix a drink" or a guard like "this is a full jug" has *semantic
  content* — what a drink is, what full means — that ultimately grounds in
  world-understanding (`affordance-substrate.md`).

Recorded as dependencies, not as a built integration.

## No-copouts (governing constraint)

The `DESIGN.md` no-copouts posture and the 100%-immersion north star govern
this layer at every point:

- **No finite fact-dump** — understanding must generalize to the novel case,
  not retrieve stored lines.
- **No hot-loop LLM** — online / per-query inference is forbidden; the model
  is a build-time oracle only.
- **No templates** — the same refusal the NLG pillar makes
  (`npc-mind-and-language.md`); meaning is not a label mapping 1:1 to a canned
  answer.

And — per the existence proof — it **remains an unsolved frontier we keep
whole and hard** rather than shrinking until it is easy. Reachable is not the
same as solved; the difficulty is owned, not designed away.

## Open threads (explicitly unresolved — not invented here)

- **Extraction / cleaning / prevalence-estimation method** — how the corpus is
  mined into deduplicated, sense-disambiguated triples, and how trustworthy
  prevalence weights are actually estimated, is the central open R&D problem.
- **The LOD axis & the coherence mechanism** — what level-of-detail varies
  along (depth / breadth / prevalence-cutoff / abstraction), and the concrete
  mechanism that *guarantees* faithful coarsening (no popping, seed-stable), is
  open.
- **The grounding binding** — binding graph concepts to concrete embodied /
  rendered / physics instances (the *Grounding* section's binding problem).
- **Composition with the brain / NLG / affordance substrates** — exactly how
  the layer is queried by, and composes with, `npc-mind-and-language.md` and
  `affordance-substrate.md`, is open.
- **Corpus selection / curation** — which corpora, and how curated, to mine.
- **Representation beyond vanilla RDF** — whether plain triples suffice, or
  whether prevalence / defeasible / contextual knowledge (knowledge that is
  true by default, true only in a context, or holds with a weight) needs a
  richer representation than vanilla RDF triples-plus-weights.

---

Cross-links: `npc-mind-and-language.md` (the brain that reasons over this
layer; the peer-R&D-bet framing and the deterministic-surrogate shape this
reuses), `affordance-substrate.md` (the verbs / guards / effects whose meaning
grounds here; the once-per-tick resolved frame the foveated budget ties to),
`movement-substrate.md` (the interpreter↔compiler bit-equivalence the LOD
coherence parallels), and `DESIGN.md` → *Platform for depth*, *World agency*,
*Secondary / soft-body physics* (the sibling deterministic-surrogate bet), and
the research-program framing near the *Architecture commitments*.
