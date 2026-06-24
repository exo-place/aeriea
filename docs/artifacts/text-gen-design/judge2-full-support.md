# Judge 2 — Full Support, INCLUDING Deliberate Ungrammaticality

Adversarial lens: the support boundary is **"anything a competent author might put
on the page,"** NOT grammaticality. Fragments, run-ons, comma-splices, dialect,
elision, descriptivist/modern grammar, and above all **dialogue** (people do not
speak in clean sentences) must be reachable with NONZERO probability AND with a
**distribution shaped by character/register** — not as uncontrollable noise, and
never blocked by a grammaticality wall. Any paradigm whose support is finite, or
whose support boundary IS grammaticality, fails. Attack, don't praise.

---

## The sharpened test each candidate must pass

Three concrete probes, applied to all four:

- **P1 — Reach.** Construct a sentence the paradigm likely cannot derive *at all*.
- **P2 — Deliberate non-standard, CONTROLLED.** A comma-splice in a slangy
  character's mouth; a sentence fragment as deliberate punch; dialect/eye-dialect;
  a breathless run-on — produced with nonzero probability AND distributionally
  bound to a voice (terse character rarely run-ons; a manic one often does).
- **P3 — Wall vs. dial.** Is grammaticality a hard support boundary (bad) or just
  a region of probability mass that voice can move off (good)?

The decisive question under this lens: **where does each paradigm's support
boundary actually sit, and is "ungrammatical" outside it or inside it?**

---

## Candidate A — TSG/TAG (strict generative grammar)

**This is the candidate whose support is DEFINED BY grammaticality — the exact
wrong boundary, and the design says so in its own words.**

§1.1: *"any **sensible grammatical** sentence has nonzero probability, satisfying
the hard-constraint."* §1.1 again: *"adjunction recursion is unbounded (**any
finite sentence structure** is reachable)."* The support claim is explicitly
quantified over **grammatical** structures. A TAG's generated language is, by
construction, exactly the set of strings derivable from its elementary trees by
substitution + adjunction. A comma-splice, a verbless fragment, a dropped-copula
dialect line, a deliberate run-on with no licensing coordinator — these are **not
elementary-tree-derivable structures** in any standard TAG. They are precisely
the strings a generative grammar exists to EXCLUDE. The paradigm's formalism is a
machine for ruling them out. Under this lens that is a disqualifying property, not
a feature.

The design tries to recover non-standard cadence and even names some of it:
seed=104 produces a `, and … , and …` run-on, and §4.3 hand-derives a
fragment-evaluation auxiliary ("Flat.") and a "six months, and her hands stay
exactly where they are" line. So A is *aware* fragments and run-ons matter. But
look at HOW it reaches them:

- The run-on is a **paratactic auxiliary tree** (`runon` join = `, and`). That is
  a *grammatical* coordination structure — it is a well-formed compound sentence,
  not a comma-splice. A comma-splice is two independent clauses joined by a bare
  comma with NO coordinator: *"She looked up, she didn't say anything."* To
  produce THAT, A needs an auxiliary tree that adjoins clause-to-clause with a
  bare-comma foot and no conjunction — i.e. an elementary tree that **encodes an
  ungrammaticality**. You can add it. But every such form is a bespoke
  ungrammatical elementary tree you must hand-license into the inventory, against
  the grain of the formalism. Dialect ("She don't say nothin'") is another
  bespoke tree (negative concord + dropped copula). Eye-dialect ("g'wan, gerrof")
  is lexical-phonological mangling the lexicon can technically hold but the
  morphology/agreement pass (§6, the `cap()`/linearization pass) will fight.

- The fragment ("Flat.") is reachable only because A admits AUXILIARY trees that
  can stand alone — but a TAG fragment is still a *tree*; a true authorial
  fragment is often a deliberate non-constituent ("All of it. Gone."). A
  non-constituent fragment is the hardest thing for a constituency grammar to
  emit, because it is by definition not a well-formed tree.

So A's answer to P2 is: **bolt each non-standard form on as a special elementary
tree, one per phenomenon, fighting the formalism every time.** This is the worst
posture under this lens — it treats non-standardness as enumerated exceptions
inside a grammaticality machine, not as a region of a distribution.

**P3 verdict: HARD WALL.** A's support boundary literally is grammaticality. Every
deviation is an explicitly added exception, and the morphology/linearization pass
(§6) actively normalizes toward grammatical agreement — the one component whose
job is to *undo* the dialect/elision the lens demands.

**P1 — concrete unreachable sentence:**
> *"she's like, whatever, he can rot for all i care—not that i, not that it,
> ugh."*
This is a slangy quotative ("she's like"), a comma-splice ("whatever, he can
rot"), a self-interrupting aborted clause ("not that i, not that it"), and a
non-lexical filler ("ugh") as a clause. There is no TAG derivation for an aborted
clause — an unfinished constituent is not a tree. A cannot reach this without a
combinatorial pile of one-off "broken constituent" auxiliary trees, which is
admitting the formalism doesn't cover it.

**Score: 3/10.** Support boundary = grammaticality, stated in the design. Reaches
the *mild* deviations (compound run-on, standalone fragment) as grammatical
structures wearing deviation costumes; cannot reach genuine non-constituent
breakage, comma-splices, aborted clauses, or dialect without per-phenomenon
hand-licensed ungrammatical trees that fight the formalism. The strongest
craft-paradigm of the four (best cadence story) and the WEAKEST on this specific
requirement.

---

## Candidate B — Construction Grammar (CxG)

**Best-positioned of the four — because in real CxG, an "ungrammatical" form is
just another construction, and the design already ships dialogue-bearing
constructions with register affinity.**

The key structural fact: a construction is a *form-meaning-register pairing*, and
**there is no grammaticality predicate anywhere in the realizer.** `realize(sem)`
picks among `BY_SEM[sem]` by license + voice affinity; nothing checks
well-formedness. That means a comma-splice construction, a dropped-g dialect
construction, a fragment construction, a quotative-`like` construction are
**first-class citizens with weights**, indistinguishable in kind from "standard"
ones. CxG as a linguistic theory was BUILT to handle exactly the idiomatic,
non-compositional, "ungrammatical-by-CFG-standards" material that generative
grammar exiles — *"the bigger they come the harder they fall,"* *"him be a
doctor?!"*. That heritage is the whole point and it lands precisely on this lens.

Concretely the design already does the right thing: §4 runs `S.glad_undercut` =
`"<glad core>," <guarded tag>` and emits *"So. You're back."* (plain_flat, run 5)
— a **deliberate fragment** ("So.") as a licensed construction with a register
tag. *"You. Back. Hm."* (in candidate D, but the same shape is native to B) is
just a fragment-stack construction. Dialogue is not a special problem for B
because **dialogue lines ARE constructions** (`G.youre_back`, the dialogue tags
`T.tag_dry`/`T.tag_soft`) — the design realizes speech as constructions tagged by
voice, which is exactly the "people don't speak in clean sentences" requirement.

**P2, point by point:**
- *Comma-splice in a slangy mouth:* add `C.comma_splice_run` (`sem=SPLICE_RUN`,
  `form = <clause> "," <clause>`, `reg={breathless, slangy, teen}`,
  `requires=[...]`). A teen/manic voice's affinity vector weights it up; a terse
  voice weights it to near-zero. **Controlled by the same affinity mechanism as
  everything else** — no new machinery. This is the decisive win: non-standardness
  rides the *identical* distributional lever as register, so it is contextual by
  construction.
- *Fragment as punch:* already demonstrated ("So.").
- *Dialect:* `C.dropped_g`, `C.negative_concord`, `C.gonna` are lexical/phrasal
  constructions with `reg={southern, casual, ...}`. A character's voice vector
  *is* a dialect selector. Eye-dialect is a lexical construction's `lit` text.
- *Breathless run-on:* a discourse construction whose joiner is bare-comma
  parataxis, weighted into manic voices.

**P3 verdict: DIAL, cleanly.** Grammaticality is not represented at all; it is an
*emergent property* of which constructions a voice tends to pick, never a
boundary. Standard vs. non-standard is purely a difference in which `reg` tags
carry mass. This is the textbook-correct shape for the requirement.

**The honest attack on B — its weak points under THIS lens:**
1. **Soft-weight register bleed (§5.2) cuts BOTH ways.** Because affinity is soft,
   a terse_guarded voice CAN draw the comma-splice construction (low prob, not
   zero) — which the lens *wants* (nonzero everywhere) but which also means
   non-standard forms can leak into voices that shouldn't have them. The design
   accepts this as the price of full support; under this lens that's the correct
   trade, but it means "controlled" is statistical, not guaranteed — a manic
   construction in a buttoned-up character's mouth is a low-probability draw, not
   an impossibility. Acceptable, but real.
2. **Coverage, not formalism, is the true ceiling.** B's support over the language
   is "what the constructicon can compose." A non-standard form that NO
   construction encodes is unreachable — §6 names the `<SEM?>` gap. So B's
   reach for ungrammaticality is bounded by **constructicon density of
   non-standard constructions**, which the build-time mining must actually
   produce. The formalism welcomes them; the *inventory* must contain them. This
   is a build-cost ceiling, not a formal wall — strictly better than A's formal
   wall, but it is not "free."

**P1 — concrete (conditionally) unreachable sentence:**
> *"i— i can't even, the rain just— god, you came BACK and i, whatever."*
B reaches this **iff** the constructicon contains a self-interruption / aborted-
clause construction (`form = <clause-onset> "—" <restart>`) and an emphatic-caps
lexical realization. Both are expressible as constructions — but if the mining
pass never abstracted an "aborted self-interrupting clause" construction from the
corpus, the form has no `sem` to realize and is unreachable. So B's gap is
**inventory coverage of the wilder dialogue moves**, not formalism. Far more
recoverable than A: you add a construction, you don't fight the theory.

**Score: 8/10.** The only paradigm with no grammaticality predicate at all;
non-standard forms are first-class and ride the SAME register-affinity dial as
voice, so they are inherently distributional/controllable. Docked because (a) its
true support boundary is constructicon coverage — non-standard forms must actually
be mined, and the hardest dialogue moves (aborted clauses, mid-word breaks) are
exactly the ones a frequency-driven mining pass may under-collect; (b) soft
weights make "controlled" statistical rather than guaranteed. Best fit by a clear
margin.

---

## Candidate C — Transformational / edit-sequence

**Second-best, and arguably the most *natural* generator of deliberate breakage —
because its run-ons and splices are emergent products of transforms, not licensed
forms — but that same property makes them under-CONTROLLED, which is the other
half of the requirement.**

C's mechanism is a pipeline of structural transforms (`subordinate`, `front`,
`fuse`, `elide`, `cleft`, `figure`, `punct`...) over an open lexicon. Critically,
**C already produces non-standard output as a NATURAL consequence of its
transforms** — and the design's own §5 confesses it:

- *"warm-lyrical/31337 ... comma-spliced run-on. Four clauses chained by commas
  reads as a list."* — C **literally emitted a comma-splice** in its run. Under a
  grammaticality lens that's a bug; under THIS lens it is proof the paradigm can
  reach comma-splices natively, because `punct[comma]` over a multi-clause plan
  with no fusion IS a comma-splice generator.
- `elide` drops clauses → fragments fall out for free ("She stays careful.",
  "She's glad, and won't quite let it show.").
- A breathless run-on is just `select[budget=high]` + `punct[comma]` + low
  `fuse` weight — exactly what 31337 did.

So C's answer to P2 is the most *organic* of the four: deliberate fragments and
run-ons and splices are **what the transforms produce when you turn the punct/
elide/fuse dials**, not bolted-on forms. The `punct` transform (em-dash / stop /
comma rhythm) is a literal cadence-and-deviation dial. This is structurally
attractive for the requirement.

**But the lens demands non-standardness be CONTROLLED — distributional, bound to
voice — and here C is weaker than B in a specific way:** C's §5 shows the
comma-splice fired as a **defect of dumb linearization**, not as a voice-bound
choice. The design's own mitigation is *"linearization must itself be
transform-distilled (a 4-clause plan should force fusion or a stop split, never a
comma list)"* — i.e. the proposed fix is to **make the run-on LESS likely**,
treating it as something to suppress, not a voice-controlled dial. That reveals
the tension: C produces deviation easily but currently produces it as **noise it
cannot aim**. To satisfy the lens, C must do what B gets for free — make
"comma-splice frequency" a per-voice transform weight (a slangy/manic voice has
high `punct[comma]`-on-many-clauses weight; a precise voice forces fusion). That
IS expressible (it's just another entry in the per-voice transform-firing table,
§1.3), and it's a *better* fit than A's bespoke trees — but the design as written
frames its deviation as a bug to fix rather than a knob to turn. That is the gap.

**Dialect under C is the genuinely awkward case.** C's transforms are
*structural* (subordinate/front/fuse/cleft) and *lexical binding* is a separate
`bind_lexemes` step. Dialect ("she don't say nothin'") is a
morphological/lexical-grammar phenomenon — negative concord, dropped copula —
that isn't a clause-level structural transform. C would have to handle dialect
entirely in the lexicon-binding layer (register-keyed surface realizations),
which works for *lexical* dialect ("ain't", "gonna") but not for *syntactic*
dialect (concord, copula-drop, habitual "be"). Those need a transform
(`dialectalize`?) that the inventory doesn't list. So C reaches lexical
non-standardness easily, syntactic dialect awkwardly.

**P3 verdict: DIAL, but a mis-aimed one.** No grammaticality predicate (good);
deviation is emergent from transforms (good); but the design currently treats its
deviations as interference/linearization defects to suppress rather than
voice-weighted choices to control. The dial exists in principle (per-voice
transform weights) but the design points it the wrong way.

**P1 — concrete unreachable / awkward sentence:**
> *"she be standin' there, don't say nothin', just—yeah."*
Habitual "be" + dropped copula + negative concord + dropped-g + an aborted "just—"
trailing into a discourse-particle "yeah." The syntactic-dialect parts (habitual
be, negative concord) have no transform in C's inventory and aren't lexical swaps,
so C can't derive them without a new dialect transform. The aborted "just—" is
reachable via `punct[dash]` + `elide`, and "yeah" via lexicon — so C gets the
*breakage* but misses the *dialect grammar*.

**Score: 7/10.** Most organic native producer of fragments/run-ons/splices of any
candidate (it emitted a comma-splice in its own run), with `punct` as a real
cadence-deviation dial. Docked because (a) the design frames its deviations as
defects to suppress, not voice-bound dials to aim — control is the unmet half; (b)
syntactic dialect has no home in a structural-transform inventory and isn't a
lexical swap. Reach is broad, control is currently mis-pointed.

---

## Candidate D — Analogical Schema Induction

**Fails this lens hardest on the FINITENESS axis — by its own admission — and its
unit (the "rhetorical move") is orthogonal to grammaticality, so deliberate
breakage is neither native nor cleanly controllable.**

D's own §5 confession is fatal under this lens: *"The toy's `distinct outputs over
4000 seeds = 375` is **finite — honestly.** ... I am **not** claiming the toy has
full support; it demonstrably does not."* The full-support claim is then deferred
to a seam D does not own: *"support is full **iff** the sub-grammars are truly
open ... that openness is inherited from the semantic-graph grammar seam, which
prose-generation.md itself marks OPEN."* So D's support, for the parts D actually
specifies, is **finite**, and full support is borrowed from an unbuilt
sub-grammar. Under a lens that disqualifies finite support, D is asking for credit
on an IOU.

**Is the finiteness a toy artifact or fundamental?** Partly fundamental to D's
unit choice. D's generative unit is the *deep rhetorical schema* —
"anchor→withheld→tell." That is a **structure of MEANING-MOVES, not a structure of
SYNTAX.** A comma-splice, a dropped-g, a habitual "be", an aborted clause are
**syntactic/morphological** phenomena that live entirely *inside* a single move's
`realizer` sub-grammar. So D punts all of P2 down to the sub-grammar — D's schema
layer has literally nothing to say about grammaticality or its deviation; it is
the wrong altitude for this requirement. Whatever paradigm fills D's `realizer`
sub-grammar is what actually answers this lens — and if that sub-grammar is a TAG
(candidate A), D inherits A's grammaticality wall; if it's CxG (B), D inherits B's
strength. **D's score on THIS lens is a pass-through to whatever realizes its
roles, plus a finite schema skeleton on top.** That is a non-answer dressed as an
architecture.

**P2 under D, concretely:**
- *Fragment:* D *does* reach these, but only because a whole schema is dedicated to
  it — `WITHHELD_only_minimal` → *"You're back." A statement, not a question.* and
  `STAGING_then_TELL_then_WITHHELD` → *"Huh," she says. "You."* So fragments exist
  as **schema-level moves** (a restraint move realizes as a fragment). That's a
  coarse, schema-granular control: you get fragments when the *rhetorical move* is
  restraint, NOT when a slangy character would casually drop one mid-flow. The
  control axis is rhetorical-function, not character-register — wrong axis for
  "this character speaks in fragments because that's their voice."
- *Comma-splice / breathless run-on / dialect:* **no schema produces these**; they
  must come from the role `realizer` sub-grammar, which the toy stubs and which D
  explicitly does not specify. So D, as specified, **cannot** produce a
  voice-controlled comma-splice or dialect line at all — it's entirely deferred.
- The design's RST `joiner` (concessive/causal/breaks) is the closest D has to a
  cadence dial, and §6 admits the concessive joiner produces *"the one bad line
  (mid-sentence quote capitalization)"* — its fusion is buggy even on the
  grammatical case, let alone deliberate deviation.

**P3 verdict: NEITHER wall nor dial — ABSENT.** D's layer doesn't model
grammaticality, so it can't have a wall; but it also can't have a dial, because
deviation lives below it in an unspecified sub-grammar. The one control it offers
(schema choice → fragment-via-restraint) binds deviation to rhetorical function,
not to character voice, which is the wrong binding for this requirement.

**P1 — concrete unreachable sentence:** essentially *any* deliberate-deviation
dialogue line that isn't a restraint-fragment, e.g.
> *"omg ok so like, he just—he LEFT, no note, nothin', and i'm just standin' there
> like an idiot, whatever."*
Slangy discourse markers ("omg ok so like"), comma-splices, an aborted self-
interruption ("he just—he LEFT"), negative concord/dropped-g ("nothin'"),
trailing "whatever." D's schema layer has no move for this and its sub-grammar is
unbuilt, so it is unreachable in any specified part of D. (And the finite toy
caps at 375 outputs regardless.)

**Score: 4/10.** Finite by self-admission for everything D actually specifies;
full support is an IOU on an unbuilt open sub-grammar. Its unit (rhetorical move)
is at the wrong altitude for grammaticality-deviation, which lives one layer down
in a stubbed component — so D neither produces deliberate ungrammaticality natively
nor controls it, except the single coarse case of restraint→fragment (bound to the
wrong axis). Above A only because A actively walls deviation out via a
grammaticality formalism, whereas D merely fails to address it; but D's finiteness
is the more literal violation of the stated requirement.

---

## Ranking (by full-support INCLUDING controllable deliberate ungrammaticality)

| Rank | Candidate | Score | One-line |
|------|-----------|-------|----------|
| 1 | **B — Construction Grammar** | **8** | No grammaticality predicate exists; non-standard forms are first-class constructions riding the SAME register-affinity dial as voice — inherently distributional. Ceiling is constructicon coverage, not formalism. |
| 2 | **C — Transformational** | **7** | Most organic native producer of fragments/splices/run-ons (emitted a comma-splice in its own run); `punct` is a real deviation dial — but the design frames deviation as a defect to suppress, not a voice-bound knob to aim, and syntactic dialect has no transform. |
| 3 | **D — Schema Induction** | **4** | Finite by self-admission; full support is an IOU on an unbuilt sub-grammar. Deviation lives one layer below its unit, stubbed — neither native nor controllable except restraint→fragment, bound to the wrong (rhetorical, not character) axis. |
| 4 | **A — TSG/TAG** | **3** | Support boundary IS grammaticality, stated in the design. Reaches mild deviations only as grammatical structures in costume; genuine splices/aborted-clauses/dialect require per-phenomenon hand-licensed ungrammatical trees that fight the formalism, and its linearization pass actively normalizes deviation away. |

### Concrete unreachable sentence per candidate

- **A:** *"she's like, whatever, he can rot for all i care—not that i, not that
  it, ugh."* (quotative + comma-splice + aborted clause + filler-as-clause — no
  TAG derivation for a non-constituent aborted clause).
- **B:** *"i— i can't even, the rain just— god, you came BACK and i, whatever."*
  (reachable IFF an aborted-self-interruption construction was mined; gap is
  inventory coverage, not formalism — recoverable by adding a construction).
- **C:** *"she be standin' there, don't say nothin', just—yeah."* (gets the
  breakage via punct+elide; misses habitual-be / negative-concord syntactic
  dialect, which is no structural transform and no lexical swap).
- **D:** *"omg ok so like, he just—he LEFT, no note, nothin', and i'm just
  standin' there like an idiot, whatever."* (no schema move for it; sub-grammar
  unbuilt; toy caps at 375 outputs regardless).

### Pick

**B (Construction Grammar) most naturally satisfies the requirement.** It is the
only paradigm with **no grammaticality predicate at all**: "ungrammatical" is not
a category its realizer can even represent, so it cannot be a support wall. A
comma-splice, a dialect line, a fragment, an aborted clause are ordinary
constructions, and they ride the *exact same* `voice_affinity` dial as register —
which is precisely the "distributional/contextual, shaped by character/register,
never a hard wall" property the requirement demands. Its only real boundary is
whether the build-time mining actually collects the wild dialogue constructions —
a coverage cost, not a formal impossibility, and one fixed by adding a construction
rather than fighting the theory.

**A (TAG) most fights its own formalism** on this requirement, and it is the only
candidate whose design *names grammaticality as its support boundary* — the
literal wrong answer. Every deliberate deviation is an exception hand-licensed into
a machine purpose-built to exclude exactly those strings, and A's own
morphology/linearization pass is the component that normalizes deviation back out.

**Cross-cut finding:** D and A fail from opposite directions. A draws a hard
grammaticality wall and must punch deviation-shaped holes in it; D draws no
boundary at the wrong altitude and defers the whole question to an unbuilt layer
(inheriting whichever paradigm fills it). C reaches deviation organically but
aims it poorly. Only B treats standard and non-standard as the same kind of thing
differing only in distribution — which is what the requirement, read literally,
asks for.
