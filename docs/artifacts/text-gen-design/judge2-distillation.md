# Judge 2 — Distillation Buildability: The Fig-Leaf Audit

Lens: every candidate concedes the runtime is trivial (a deterministic interpreter
over integer weights + a seeded PRNG — days of work). The RISK lives entirely in the
**build-time distillation**: the frontier-net step that turns authored prose into the
shipped grammar/weights artifact. This judge attacks ONLY that step. For each: can a
frontier LLM actually produce the claimed artifact reliably and at quality? Is the
artifact finite/shippable or does coverage demand unbounded extraction? Does it
secretly reintroduce human-labor-at-scale (the unread-60k-passages slop trap)? Can
you TELL at build time whether it's good without shipping and playing?

The shared tell across all four: each runtime prototype is real and run; **no
candidate built or ran a single step of its distillation pipeline.** Every
distillation section is prose about what the net "is asked to" do. So this is, for all
four, an unvalidated claim. The question is which claim is *least* hand-wave — which
has a checkable, bounded, self-grounding extraction, and which is pure faith.

---

## Candidate A — TSG/TAG induction

**The extraction task:** a frontier LLM parses each authored literary sentence into a
TAG derivation (elementary trees used + substitution fillers + adjunction sites),
which are clustered into a finite elementary-tree inventory with conditioned integer
weights.

**Attack 1 — can the net reliably do it?** TAG derivation is a *formally precise*
output: for a given grammar, a sentence's derivation tree is well-defined. But the
grammar does not exist yet — it is being induced simultaneously. So the net is asked
to do joint grammar-induction + parsing in one pass, against no fixed tree inventory,
on literary prose whose long-range dependencies, ellipsis, and free-indirect discourse
are exactly the cases statistical TAG parsers fail on. The doc admits "a statistical
TAG parser alone is brittre on literary prose; the LLM gives robust bracketing." But
LLMs are *not* known to produce consistent, schema-valid TAG derivations — there is no
evidence cited, and the failure mode (plausible-looking but inconsistent bracketing
across sentences) is invisible without a held-out re-parse check, which the doc gestures
at ("corpus stats validate") but does not specify. The derivation has no unique ground
truth until the inventory is frozen, so early passes will thrash.

**Attack 2 — finite/shippable?** The skeleton-tree inventory IS plausibly finite
(XTAG-sized, hundreds–low-thousands; this is the one genuinely defensible finiteness
claim, since real hand-built TAG grammars are that size). BUT §5.4 concedes the
quality-bearing trees are the **fusion / subtext-bearing trees**, and there is NO
bound on those — "whether the build net can reliably induce such trees at quality is
the open bet." That is the unbounded hole: the cheap part (skeletons) is finite, the
part that determines whether output clears the bar is unbounded and unproven.

**Attack 3 — human labor at scale?** The conditioning pass ("which sentence is
terse vs lyrical") is an LLM labeling pass — automatable. But validating that the
induced trees are correct (not just self-consistent) requires reading derivations,
and curating fusion trees so they aren't garbage is exactly the human-curation
ceiling. Less acute than B, but present.

**Attack 4 — build-time validation?** Partial. Held-out re-parse coverage gives a
*syntactic* check (does the grammar reparse unseen sentences). It does NOT tell you
the output reads well — A's own §4.1 toy produced the wooden seed=104 "clause, and
clause, and clause" with a fully valid grammar. Valid ≠ good. No build-time signal
distinguishes them.

**Hardest attack:** the finite, validatable part (skeleton trees) is not the
quality-bearing part; the quality-bearing part (fusion/subtext trees) is conceded
unbounded and unproven, and joint induction+parse on literary prose has no cited
precedent for reliability.

**Score: 5/10.**

---

## Candidate B — Constructicon mining

**The extraction task:** the net reads authored passages and abstracts recurring
form-meaning-register patterns into typed constructions (id, sem, form with lit/slot
elements, register tags, `requires` truth-conditions, integer weight), spanning
multiple grains, deduplicated, human-signed.

**Attack 1 — can the net reliably do it?** Abstracting a clean construction (which
spans are fixed `lit`, which are typed slots, what each slot's `sem` is, what
`requires` holds) is a *judgment-laden* labeling task with no unique answer — two
competent annotators (or two net passes) will disagree on grain boundaries and slot
typing constantly. That is not fatal in isolation, but it directly produces Attack 2's
problem.

**Attack 2 — finite/shippable?** This is B's worst exposure. The doc itself says the
inventory is "thousands–tens-of-thousands of constructions across grains" — an order
of magnitude larger than A's, and the upper bound is undefended. Worse: §6 names
**coverage** as an explicit weakness — "a committed `sem` with no licensed
construction produces a gap (`<SEM?>`)." Full support is claimed over the *language*,
but coverage of every committed *meaning* requires the constructicon to span the
entire world-model's proposition-type space. As the world model grows, the
constructicon must grow to match, with no closure condition. And §5#1 names
**cohesion constructions** (RST joins that fuse adjacent material) as "the single most
important anti-stiffness investment" AND "the hardest grain to mine." So the most
important sub-inventory is the hardest to extract and has no finiteness argument.

**Attack 3 — human labor at scale?** **B is the worst offender, and it admits it in
writing.** Step 4 of the pipeline: "Human-signs-every-construction (per `ref-corpus.md`
discipline)." Tens of thousands of constructions, each human-reviewed. This is *exactly*
the authoring ceiling / unread-passages trap relocated from passages to constructions:
you have replaced "read 60k passages" with "read and sign 30k mined constructions." The
near-duplicate dedup is also human-judgment-heavy. The slop trap is not avoided; it is
renamed.

**Attack 4 — build-time validation?** Weak. There's a coverage check (does every
committed sem have ≥1 licensed construction — catches gaps, a real but shallow signal)
and the agreement-bug class is only caught by playtesting (the doc says so: "missing
ones produce real grammatical defects that only playtesting catches"). No build-time
signal for whether the constructicon is non-redundant, whether cohesion constructions
read woven vs tiled (§5#1's "bolted on" failure is judged by eye, post-hoc), or whether
register affinities are clean. You cannot tell it's good without playing.

**Hardest attack:** the artifact is the largest and least-bounded of the four, its
most quality-critical grain (cohesion constructions) is conceded the hardest to mine,
and the pipeline explicitly requires human-signing every one of tens-of-thousands of
constructions — reintroducing the authoring ceiling wholesale.

**Score: 3/10.**

---

## Candidate C — Transform inversion

**The extraction task:** for each authored sentence, the net (a) aligns it to a
propositional skeleton, (b) infers the SEQUENCE of named transforms from a fixed
~20–40 inventory that derives the sentence from the skeleton, (c) **re-runs the
inferred sequence through the actual deterministic runtime engine and discards any
sequence that doesn't reproduce the sentence.** Aggregated validated pairs → a
conditional distribution P(transform | context).

**Attack 1 — can the net reliably do it, and is the answer unique/stable?** This is
the deepest attack and C half-walks-into it itself (§6b). Transform inversion of a
literary sentence is **not a function** — multiple distinct transform sequences can
produce the same surface, and many literary sentences do not decompose into ANY
sequence over a fixed 20–40 inventory ("subtle prose may not decompose into the fixed
inventory — the residual is where wood or infidelity hides"). So the inversion target
is non-unique where it exists and undefined where it doesn't. Non-uniqueness is
survivable (you're learning a distribution, not a function — multiple valid derivations
just contribute to the distribution). The undefined-residual is the real wound: every
sentence that won't invert is silently dropped, and those dropped sentences are
disproportionately the *best, most fused, least mechanical* prose — precisely the taste
you most wanted to capture. So the inversion has a **survivorship bias toward
mechanically-decomposable prose**, which biases the learned distribution toward the
stiff. This is not noted in C and is a serious latent defect: the distillation that
self-validates may be self-validating its way toward woodenness.

**Attack 2 — finite/shippable?** The transform inventory is genuinely small and finite
(~20–40, defensible). The voice/weight tables are a few KB. This is the **smallest and
most clearly bounded shipped artifact of the four** — a real strength. The open question
is inventory *completeness* (§6c: "does ~30 transforms span real prose? unproven"),
which ties back to Attack 1's residual.

**Attack 3 — human labor at scale?** **C is the lowest of the four here, and uniquely
so.** The re-execution validator (Attack 4) is a *machine* filter: the net proposes
sequences, the runtime engine re-runs them, mismatches are auto-discarded. No human
reads the rejects. This genuinely automates the gate that B hand-signs. Human labor is
confined to corpus curation (shared by all four) and inventory design (one-time, ~30
transforms). This is the part C earns honestly.

**Attack 4 — is the self-validation real or circular?** **Real, with one caveat — and
this is C's decisive advantage.** "Re-run the inferred sequence through the actual
runtime engine and check the surface matches the source" is a genuine, non-circular,
*executable* check: it is the only build-time validation among the four that catches
the net confabulating. If the net hallucinates a derivation, the engine produces a
different string and the pair is discarded. That directly enforces the "claim must
re-execute" discipline. The caveat: it validates *faithful reproduction of the
training sentence*, not *quality of novel generation* — passing the inversion check
means the grammar can re-derive the corpus, NOT that fresh draws read well (§5's RUN
shows half the fresh output mechanical/broken even with a validated mechanism). So the
self-validation is real but narrower than it sounds: it validates the *distillation's
honesty*, not the *generator's quality*. Still — honesty-of-distillation is exactly
the fig-leaf this audit hunts, and C is the only one with a machine check for it.

**Hardest attack:** the inversion silently drops every sentence that won't decompose
into the fixed inventory, and those are disproportionately the best prose — so the
self-validating distillation has a survivorship bias *toward* the mechanical, and its
re-execution check, while genuinely non-circular, validates faithful re-derivation of
the corpus rather than quality of novel output.

**Score: 7/10.**

---

## Candidate D — Schema abstraction

**The extraction task:** the net abstracts each passage UPWARD into a deep
rhetorical-move schema (ordered roles + RST joiner + register affinity), discarding the
words, plus open recursive sub-grammars per role.

**Attack 1 — can the net reliably do it without the schemas being shallow or
hallucinated?** This is D's named death-risk and it states it plainly (§5): "the
candidate's death is if the build-time net, under pressure, induces *shallow* schemas
(effectively `The scent of {X}…`). Then it collapses to mad-libs wearing role-labels."
Abstraction *depth* is a soft, unfalsifiable-at-a-glance property — a net under
optimization pressure will happily emit role-labeled templates that LOOK deep and are
not. Worse than B's grain-disagreement: "the move this sentence makes" has no ground
truth at all, so net-hallucinated schemas (plausible rhetorical-move names attached to
arbitrary structure) cannot be caught by inspection. D depends on the net doing the
single most judgment-laden, least-checkable abstraction of the four.

**Attack 2 — finite/shippable?** The schema inventory is claimed finite (few
hundred–few thousand). BUT §5 contains the most damaging admission across all four
docs: **the toy's full-support claim is FALSE as built** — "distinct outputs over 4000
seeds = 375 ... finite — honestly." D's support depends entirely on the role
sub-grammars being *open and recursive*, and the doc concedes those are STUBBED:
"support is full *iff* the sub-grammars are truly open ... that openness is inherited
from the semantic-graph grammar seam, which `prose-generation.md` itself marks OPEN."
So D's finiteness/support story is not just unproven — it is **explicitly deferred to a
different unbuilt seam.** The shippable, finite part (schemas) is real; the part that
makes it not-mad-libs (open sub-grammars) is admitted absent. D is, by its own
accounting, mad-libs-at-375-outputs until a separate OPEN seam is discharged.

**Attack 3 — human labor at scale?** High and partly hidden. §3 surfaces the
**lexicon-provenance tagging** requirement: every construction must carry its
asserted-proposition set or the gate leaks (the "look what the rain dragged in" asserts
rain bug). That tagging, across an open lexicon, is real per-entry labor. Plus
schema-depth curation (rejecting shallow schemas) is a human-judgment gate. Comparable
to A, better than B, far worse than C.

**Attack 4 — build-time validation?** D proposes the most concrete build-time eval of
the structural candidates: "reject a schema if its realized outputs across different
bound content are too n-gram-similar (it's a template)." This is a real, automatable
anti-shallowness check — credit for specifying it. But it only catches the *crudest*
shallowness (lexical template); a schema can be n-gram-diverse and still rhetorically
shallow/hallucinated. And the doc falls back to "the gap-to-Opus A/B is the holistic
arbiter" — i.e. ship it and have a judge (or a human) read it. That is the
ship-and-play validation this audit exists to flag. The n-gram check is a genuine but
shallow net; the real arbiter is post-hoc human/LLM judgment.

**Hardest attack:** D depends on the net performing the least-checkable abstraction
(rhetorical-move depth, which has no ground truth and is trivially faked under
pressure), AND its non-mad-libs / full-support claim is, by its own §5, FALSE as built
and deferred to a separate OPEN sub-grammar seam — so the distillation as specified
ships a finite template-set unless an unbuilt seam is discharged.

**Score: 4/10.**

---

## Scoreboard

| Candidate | Score | Hardest distillation attack (one line) |
|---|---|---|
| **C — transform inversion** | **7** | Inversion silently drops every sentence that won't decompose into the fixed inventory — disproportionately the *best* prose — so the self-validating distillation is biased toward the mechanical; its re-execution check is real but validates corpus re-derivation, not novel-output quality. |
| **A — TSG/TAG induction** | **5** | The finite, re-parse-validatable part (skeleton trees) is not the quality-bearing part; the quality-bearing fusion/subtext trees are conceded unbounded and unproven, and joint grammar-induction+parse on literary prose has no cited reliability precedent. |
| **D — schema abstraction** | **4** | Depends on the least-checkable abstraction (rhetorical-move depth, no ground truth, trivially faked); its non-mad-libs/full-support claim is FALSE as built and deferred to a separate OPEN sub-grammar seam. |
| **B — constructicon mining** | **3** | Largest, least-bounded artifact; its most quality-critical grain (cohesion constructions) is the hardest to mine; pipeline explicitly requires **human-signing every one of tens-of-thousands** of constructions — the authoring ceiling renamed, not removed. |

## Ranking (distillation buildability, best→worst): **C > A > D > B**

## Most credible distillation: **C (transform inversion).**
It is the only candidate with (a) a genuinely small, bounded shipped artifact (~30
transforms + KB-scale weight tables), (b) a **machine** validation filter — re-execute
the inferred sequence through the real engine, auto-discard mismatches — that needs no
human to read rejects and directly catches the net confabulating, and (c) the lowest
human-labor-at-scale of the four. Its self-validation is *narrower* than it sounds
(validates honest corpus re-derivation, not novel-output quality) and it carries a real
survivorship-bias-toward-mechanical defect — but it is the only one whose distillation
honesty is checkable by a program rather than by a human reading net output.

## Most hand-wave distillation: **B (constructicon mining).**
It moves the unread-passages slop trap wholesale onto unread *constructions* — its own
pipeline says "human-signs-every-construction" across tens-of-thousands of entries —
while leaving the artifact size unbounded, the coverage requirement open-ended, and its
most important sub-inventory (cohesion constructions) conceded the hardest to extract.
The frontier-net step here is a fig leaf over an industrial human-curation effort.

**Cross-cutting caveat (applies to all four, including the winner):** none of the four
built or ran a single distillation step — every distillation section is a claim about
what the net "is asked to" do, validated by nobody. C ranks first because its claim is
*checkable by construction*; the others rank by how much unbounded extraction and human
curation they hide. The ranking is of *credibility of the distillation claim*, not of a
demonstrated distillation — there is no demonstrated distillation anywhere in the set.
