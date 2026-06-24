# Judge — Process-Soundness / Meta-Learning Audit (adversarial)

Lens: **did this candidate learn from the creator's death, or is it the same
moonshot in new clothes?** The rubric is the SESSION-RECORD's five meta-learnings.
I attack; I do not praise. Where a candidate earns a point it is because it
survived the attack, not because it argued well.

The five attack axes:
1. **Big-rebuild trap** — must a large all-or-nothing artifact exist before
   *anything* is playable? The creator died here.
2. **Quality-in-generator vs. leaning-on-detection** — is taste in the author, or
   secretly outsourced to a checker / lint / judge / "closure certified by a
   judge"? Detection is the documented copout.
3. **Verifiability without babysitting** — can the user judge aliveness by *playing
   a slice*, or must they inspect internals / point at every defect?
4. **Confabulation surface** — concrete checkable claims vs. confident unverifiable
   assertions ("Opus compiles a bible into tens of thousands of good passages").
5. **Honest about ceiling** — owns what it can't do vs. repeats the rejected
   coverage-at-quality optimism.

---

## Candidate A — Subtract the generator (authored beat-graph)

**Big-rebuild trap (LOW-MODERATE).** The runtime is genuinely tiny (a graph walk),
so there is no large *engine* to build blind. But the *unit of value* it names is a
"vertical slice = 150–400 beats / 600–1500 passages, weeks of authoring for ONE
character" before the slice is alive enough to judge. That is a real all-or-nothing
content gate: you cannot play a convincing Maren at beat #20. A does not articulate
an explicit "ship at any point" growth frontier the way E does — it gestures at
finiteness but its smallest *judgeable* increment is large. Moderate trap: the
engine is safe, the first playable artifact is heavy.

**Quality in generator vs. detection (MOSTLY CLEAN, one leak).** A's whole thesis is
the right one: there is no runtime generator, so there is no net being asked to add
taste it lacks — quality is *preserved* by never touching the prose. That dissolves
meta-learning #3 honestly. BUT stage 3 ("coverage compilation + lint, with Opus as
critic at the leaves") and the "repetition-risk freshness lint" are detection. A is
careful — Opus only *flags* for human review, never writes the shipped line — so the
leak is small and the human stays the taste gate. This is the *acceptable* use of a
checker (catch starvation/dead-beats, a mechanical property), not the copout (judge
adds taste). A survives this axis; the lint is mechanical, not taste-laden.

**Verifiability without babysitting (GOOD).** The user plays the walk; every line is
human-signed prose. No internals to inspect. Confabulation is structurally
impossible at runtime (the engine can only emit pre-approved text) — A states this
and it's true. Strong.

**Confabulation surface (LOW, with one soft spot).** Claims are concrete: the schema
is real, the worked trace is mechanically checkable, the buildability numbers are
owned as estimates ("a real, completable number, not a fig leaf"). The soft spot is
the unproven assertion that "guards over regions" make authoring scale with
*dramatic situations* (bounded) rather than *state points* (unbounded) — that the
combinatorial tail collapses to a few hundred beats per character. That is the load-
bearing bet and it is asserted, not demonstrated. But A *names* it as a bet and owns
the failure-at-systemic-edges weakness, so it is honest confabulation-awareness, not
confident hand-waving.

**Honest about ceiling (STRONG).** §6 is the most honest section across all five:
"authoring is the entire cost and it is large," "no algorithmic escape; density is
bought not generated," "weakest exactly at novel systemic states." It explicitly
refuses the moonshot wish ("if the project wants depth without large authoring, this
candidate refuses that wish honestly rather than faking it"). This is the inverse of
the rejected optimism.

**Biggest process trap:** the smallest *judgeable* increment is large (weeks /
hundreds of beats before Maren reads alive) — a content-side big-rebuild risk that A
under-addresses relative to E.

**SCORE: 8/10. SURVIVES.**

---

## Candidate B — Invert the dependency (deterministic retrieval / RAG-without-G)

**Big-rebuild trap (MODERATE).** Runtime is array math, fine. But B adds a load-
bearing component nothing else has: a **frozen embedding model + integer-cosine NN
geometry** that must work before retrieval is good. You cannot meaningfully playtest
retrieval quality until you have (a) a corpus AND (b) an embedding geometry that
actually puts dramatically-appropriate situations near each other. That is two
research-ish artifacts gating the first good play, not one. The corpus scale (300–
800 beats/NPC) is the same content gate as A.

**Quality in generator vs. detection (LEANS ON A FRAGILE MECHANISM).** Quality of
the *prose* lives in the author — good. But B outsources *which authored line fires*
to embedding-similarity, and §6 admits it plainly: "if the embedding geometry is
bad, retrieval picks tonally-wrong beats... the ranking quality still rides on the
embedding." So B has a single point of *taste-like* failure that is NOT in the
author and NOT verifiable by a checker — it's in a frozen model's geometry. This is
subtler than the detection copout but rhymes with it: it asks a *net* (the embedding
model) to make a judgment (situational appropriateness) that the producing process
can't otherwise guarantee. The hard precondition filter narrows the blast radius
(NN only ranks within an already-valid set), which is a real mitigation — but the
ranking is still a learned-geometry bet. Weaker than A/C/D/E, all of which select by
*authored discrete keys/contracts* rather than a continuous learned metric.

**Verifiability without babysitting (MODERATE).** The user plays and reads prose,
good. But when a tonally-wrong beat fires, the *cause* is opaque — it's in the
embedding geometry, not a readable guard. Debugging a bad selection means inspecting
vectors, which is exactly the "inspect internals" failure the user rejected. A bad
line in A/D is a content edit; a bad *selection* in B may be a geometry problem with
no clean human fix short of re-tagging or re-embedding.

**Confabulation surface (MODERATE-HIGH).** The riskiest claim: "situation-embedding
similarity tracks 'this beat fits here.'" B *names* this as a hidden assumption (to
its credit) but cannot demonstrate it — and it is exactly the kind of plausible-
sounding-but-unverified claim meta-learning #4 warns against. "Frozen embeddings are
deterministic" is verifiable and correctly argued. "The geometry is good enough that
NN ranking feels alive" is not, and it's load-bearing.

**Honest about ceiling (GOOD).** §5–7 own the cold-query tail, the embedding single-
point-of-failure, and the authoring cost plainly. The "degrades to authored-general
rather than manufactured-flat" framing is honest. B is not optimistic-dishonest; its
problem is that it introduced an *extra* unverifiable bet (the geometry) the simpler
candidates don't need.

**Biggest process trap:** the embedding geometry is an unverifiable, net-resident
judgment of situational fit — taste-like selection outsourced to a learned model,
opaque to debug, and the one claim it can't check is load-bearing.

**SCORE: 5/10. SURVIVES (weakened).** It survives because prose quality is still
authored and determinism holds — but it reintroduces a net-makes-the-judgment shape
the meta-learnings specifically warn against, and a confabulation-prone core claim.

---

## Candidate C — The Bible Compiler (Opus compiles a bible into tens of thousands of passages)

**Big-rebuild trap (HIGH — this is the creator's grave).** C's artifact is "tens of
thousands of Opus-authored passages" (§2.3: 10k–60k frozen strings per NPC; §7: 2k–
8k signatures × 3–6 variants) produced by an offline best-of-N → curate → refine
Opus pipeline. This is a *large autonomous build* whose output is not human-read
line-by-line before it ships — §7 explicitly says "Opus writes these at build time
in batched best-of-N; this is hours-to-days of offline GPU/$, not a person hand-
typing each — the human writes the bible, the compiler expands it." **That is the
creator failure verbatim:** a big autonomous generation that passes its automated
gates (here: provenance checks, the curation pass) and that no human has read at the
line level, shipped as a finished artifact. The creator passed 25k asserts and 15
adversarial rounds and shipped slop precisely because no human looked at the
*output*. C industrializes that exact pattern and calls it a compiler.

**Quality in generator vs. detection (FAILS THE CORE LESSON).** This is the
decisive attack. C's quality story is: Opus drafts K passages, **a second Opus pass
curates (best-of-N against the bar)**, a third Opus pass refines (§2.2.2). The taste
gate is *Opus judging Opus*. That is meta-learning #2 and #3 in one: detection-as-
copout (an LLM-judge curating) AND asking a net to add taste the generator lacks
(the curator is the same family of model as the producer). The session record's
single hardest-won finding — "a net cannot add judgment the generator lacks";
"quality must live in generation-with-taste"; the user's stated distrust of LLMs on
taste-laden output — is *contradicted by C's central mechanism*. C asserts "Opus's
own curated output is the floor," but the creator proved Opus's own curated output
is exactly what ships broken. The human writes the *bible* (the conditioning
context), not the passages — so no human exercises taste over the 30,000 shipped
lines. The provenance check is faithfulness (true/false), not taste; it cannot save
this.

**Verifiability without babysitting (FAILS AT SHIP-TIME).** The user can play the
result — but to *trust* it before shipping, someone must verify 30k machine-curated
passages are good. That is unverifiable-by-playing (you can't play your way through
30k passages) and unbabysittable. C's answer (miss-driven authoring loop) is the
*user-as-defect-gate* steady state meta-learning #5 explicitly rejects: the user
plays, finds the bad passages, and the bible grows toward coverage — i.e. the user
points at every defect. That is the rejected unsustainable loop.

**Confabulation surface (HIGH — the title is the confabulation).** "Opus compiles a
bible into tens of thousands of passages and they're all good" is *the exact
unverifiable confident assertion* the prompt flags. C dresses it as a "compiler" to
borrow determinism's respectability — but the determinism is only that the *build*
is reproducible (same bible bytes → same blob), NOT that the 30k passages are good.
C conflates "compilation is deterministic" with "compilation produces quality." The
former is checkable; the latter is the moonshot, asserted.

**Honest about ceiling (MIXED).** §6–7 do own the breadth/incidental-NPC problem and
the bucketing tension honestly. But the *central* dishonesty is structural: C never
admits that "Opus curates Opus to the quality bar" is the precise thing that already
failed. It owns coverage-breadth as the risk while smuggling the real risk (machine-
curated taste at 30k scale) past the reader as a solved "compile step."

**Biggest process trap:** the taste gate is Opus-curating-Opus over tens of
thousands of human-unread passages — the creator's autonomous-generation-passing-its-
own-gates death, industrialized and relabeled "compiler."

**SCORE: 2/10. DOES NOT SURVIVE.** C is the candidate the meta-learnings exist to
prevent.

---

## Candidate D — Coarse-grain combinatorics + adjacency closure certified by a judge

**Big-rebuild trap (HIGH on the build side).** The runtime is a graph walk (fine),
but D's *key build artifact* is the **adjacency closure**: an O(beats²) certification
that "every type-legal adjacency is also judge-legal," iterated until the invariant
holds (§2.3, §7). For 2,000 beats that is ~4M ordered pairs, "a large build-time
judge bill and a real annotation-refinement effort... where the project-months go."
This is an all-or-nothing build: the coherence guarantee only holds *after* the
closure converges. You cannot ship a 50-beat slice with the safety invariant until
you've run the closure over it, and the invariant is the thing D leans on to make
runtime safe. The closure is a big-rebuild gate by construction.

**Quality in generator vs. detection (FAILS — the copout is named in the design).**
The prompt called this out by name, and it is correct. D's coherence rests on a
**build-time coherence judge (Opus, at the leaves)** that scores rendered
adjacencies for continuity/contradiction/affect-jump/repetition (§2.3, §5.2). D
*defines its safety invariant as "type-legal ⟹ judge-legal," certified by an Opus
judge.* That is detection elevated to load-bearing architecture. The session record
is explicit: even the composed-whole critic rendering the real running app missed
the overlapping bars; a judge catches only the failure classes its rubric names. D
bets the farm that an Opus adjacency-judge reliably catches *every* class of jarring
transition — which is exactly the bet that already failed. D is *more* exposed than
C here in one sense: C's judge curates within a passage (local); D's judge certifies
*cross-beat coherence* (an open-ended, taste-laden property) and the whole runtime
safety story depends on it being complete. Annotating existing prose (the `opens`/
`needs` lift, §2.2) IS a more reliable LLM task than generating — D earns a partial
point for moving labeling off the generator — but the *certification* judge is pure
copout.

**Verifiability without babysitting (MODERATE).** Authored beats are human prose, so
playing reads real writing — good. But the *coherence* claim is verified by the
judge offline, not by the user playing. When a jarring adjacency ships anyway (the
judge missed a class), it's the creator pattern again: passed the gate, shipped
broken, user finds it. D's recourse ("tighten the annotation or author a transition
beat") is reactive bolt-on — the bandaid treadmill meta-learning #2 names.

**Confabulation surface (MODERATE-HIGH).** The load-bearing unverifiable claim:
"iterate until *every* type-legal rendered adjacency also passes the judge" — i.e.
the judge is a reliable, complete oracle for coherence. That is asserted, and it is
precisely the over-trust-in-a-critic the saga punctured. The mechanics (type system,
slot resolution) are concrete and checkable; the *coherence guarantee* rests on
judge completeness, which cannot be verified.

**Honest about ceiling (GOOD on content, BLIND on the judge).** §6–7 own the
coverage tail, the granularity tension, the closure cost honestly — D is admirably
clear about labor and the O(beats²) bill. But it is *blind to its own central
risk*: it treats the coherence judge as trustworthy infrastructure and never
reckons with the saga's finding that judges miss novel badness. It owns the cost of
the judge, not the *unreliability* of the judge.

**Biggest process trap:** runtime coherence safety is *defined* as a property
certified by a build-time Opus judge ("type-legal ⟹ judge-legal") — the exact
detection-as-copout, over a taste-laden cross-beat property, that the saga proved a
judge cannot reliably guarantee.

**SCORE: 4/10. SURVIVES (barely).** The authored-beat core is sound and the prose is
human; it survives because quality of *prose* is authorial. But it bolts its central
coherence guarantee onto a judge — the documented copout — and front-loads a big
all-or-nothing closure build.

---

## Candidate E — Scope-to-What-Ships (skeptic-realist)

**Big-rebuild trap (LOWEST — designed against it explicitly).** §6 and §8 are built
around *making the big-rebuild impossible by construction*. The unit of growth is
ONE fragment; each is authored → committed → golden-traced → playtested. "You can
ship at any point." "There is no state where the system is half-rebuilt and broken."
Increment 1 is a *refactor + deepen* of code that already exists and runs
(`npc_realizer.gd`, `text_sandbox.gd`, `maren_history.gd`), not a rebuild. This is
the direct structural answer to the creator's death. No candidate is close.

**Quality in generator vs. detection (CLEANEST — taste is a human author, by
design).** §3.3 is explicit and correct: the LLM is a *draft-against-spec amplifier*;
"a human author accepting every line into a committed, finite, diffable corpus";
"the rejected doc tried to replace [the taste gate] with an LLM-judge (the creator
saga proved detection/judge ≠ taste)." E *names the exact meta-learning and designs
to it.* The voice-lint and coverage-gap report are advisory/mechanical (finite grid
enumeration, drift-flagging) with the human adjudicating — the acceptable use, not
the copout. Crucially E ships nothing Opus produced that a human didn't read and
accept. This is the one candidate that puts taste *unambiguously* in human
authoring with the LLM as typing-speed multiplier.

**Verifiability without babysitting (BEST — and it explicitly reframes the gate).**
Every increment is playtested on the running slice; the user gives a green verdict
per increment on what they played. §7 makes the load-bearing observation no other
candidate makes: it moves the human "from *defect-gate* (reactive, unbounded) to
*author* (proactive, productive)" — directly addressing meta-learning #5's "user as
gate is unsustainable." The human's effort produces content instead of catching
slop. That is the correct read of the saga.

**Confabulation surface (LOWEST).** E's claims are the most checkable: most of the
artifact already exists and runs (`wc -l`-able, diffable, golden-traceable). It
makes *no* unverifiable coverage-at-quality claim — it explicitly fences that off as
out-of-scope research (§2). The worked example is labeled "authoring *target*
quality, written here by hand to the bar an author + amplifier would commit" — it
does NOT claim a machine produced these lines, which is the honest framing C/D blur.

**Honest about ceiling (STRONGEST).** §7 owns it without flinching: "it gives up the
generative dream," "authoring-labor-bound," "repetition visible at the edges,"
"depth is upstream-bounded." §8 names the residual risk plainly: "if a deep authored
slice still doesn't feel alive enough, the limit is authoring craft + state
richness, not the architecture." That is the anti-moonshot — it pre-commits to the
honest failure mode and refuses to promise past it.

**The one fair attack on E:** it is the *least ambitious* — it explicitly gives up
generative coverage and bets everything on authoring throughput. If the project's
real goal *requires* prose for genuinely novel systemic states (a body/transform
combo no author anticipated), E by construction can't deliver it (degrades to good-
and-brief). That is a real ceiling — but E *owns* it openly, which is the entire
point of the exercise, rather than papering it with a generator or a judge. Honesty
about a low ceiling beats confabulation about a high one.

**Biggest process trap:** voluntarily-low ceiling — it forecloses generative
coverage entirely and is throughput-bound; if authoring craft alone can't reach
"alive," E offers no escape but "author more." (But it *says so*, which is correct.)

**SCORE: 9/10. SURVIVES — best respects the meta-learnings.**

---

## Compact scorecard

| Candidate | Score | Survives? | Single biggest process trap |
|---|---|---|---|
| **E — Scope-to-ships** | 9/10 | YES | Voluntarily-low ceiling; throughput-bound, no generative escape (but owns it) |
| **A — Subtract/beat-graph** | 8/10 | YES | Smallest *judgeable* increment is large (hundreds of beats before Maren reads alive) |
| **B — Invert/retrieval** | 5/10 | yes (weak) | Situational fit outsourced to opaque embedding geometry — a net makes the taste-like judgment, unverifiable + undebuggable |
| **D — Coarse + adjacency closure** | 4/10 | yes (barely) | Runtime coherence *defined* as "judge-legal," certified by an Opus judge — detection-as-copout over a taste-laden property |
| **C — Bible Compiler** | 2/10 | **NO** | Opus-curates-Opus over tens of thousands of human-unread passages — the creator's autonomous-gen-passing-its-own-gates death, industrialized |

## Ranking by process-soundness (against the specific meta-learnings)

**E > A > B > D > C.**

- **E and A are the two that learned the lesson.** Both put taste in human authoring
  with the LLM as a build-time ingredient the human gates; both make confabulation
  structurally hard (no runtime generator; every line human-signed); both are honest
  about a real ceiling. E edges A only because E is *built around incremental,
  per-slice playtested verifiability* — the precise antidote to the big-rebuild
  death — while A's smallest convincing slice is a heavy content lift. A's runtime
  and subtraction-thesis are arguably more elegant; E's *process* is safer.
- **B sits in the middle:** prose quality is authored (good), but it reintroduces a
  net (the embedding model) making a taste-like judgment (situational fit) that is
  unverifiable and undebuggable — a softer version of the copout, plus a load-bearing
  confabulation-prone claim ("the geometry is good enough").
- **D and C both fail the central lesson**, differently. D bolts its *coherence
  safety invariant* onto a build-time Opus judge — detection elevated to
  architecture — and front-loads an all-or-nothing O(beats²) closure. C is worse: it
  makes Opus-curating-Opus the taste gate over tens of thousands of human-unread
  passages, which is the creator's death dressed as a compiler. C is the candidate
  the meta-learnings were written to stop.

## Which candidate best respects the meta-learnings

**Candidate E.** It is the only one that (1) names each meta-learning and designs
*to* it, (2) makes the big-rebuild structurally impossible (ship at any point, one-
fragment growth unit, refactor-not-rebuild of running code), (3) puts taste
unambiguously in a human author with the LLM as a typing-speed multiplier the human
gates line-by-line, (4) fences the unverifiable moonshot OUT of scope rather than
smuggling it past the reader, and (5) reframes the human's role from unsustainable
defect-gate to productive author — the one design that answers meta-learning #5
instead of re-triggering it.

A is a strong, honest second and the better choice if the project will *fund deep
authoring up front* and wants the maximally-trivial runtime — but it carries a
heavier first-playable content gate. B, D, and C each reintroduce, in escalating
degree, the precise failure the saga exists to prevent: trusting a net to supply a
judgment (selection, coherence, or curation) that the producing process cannot
guarantee and a human has not gated.
