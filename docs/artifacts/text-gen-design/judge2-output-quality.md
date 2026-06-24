# Judge 2 — Actual Output Quality (adversarial)

Lens: the ONLY thing that matters is whether the prose these mechanisms actually
PRODUCE clears a frontier RP-craft bar — concrete telling detail, subtext,
restraint, real cadence variety, distinct voice. Paper architecture is irrelevant.
I re-ran all four prototypes myself; every pasted sample reproduces verbatim
(`/tmp/tsg/tsg.py`, `/tmp/cxg_proto/cxg.py`, `/tmp/transform_proto/proto.py`,
`/tmp/schema_proto.py`). No candidate inflated its run output. The fight is between
what the MECHANISM did vs what the agent hand-wrote and what the agent pre-loaded as
a surface string.

The central trap I am holding every candidate to: **a sample reads well only insofar
as the GOOD WORDS were produced by the mechanism, not pre-authored and shuffled.** A
realizer that emits a beautiful clause because that exact clause was typed into a
lexicon table by a good writer is retrieval wearing a grammar's clothes. The prose
quality you SEE is then evidence about the agent's writing, not the mechanism's.

---

## Candidate A — TSG/TAG

### Line-by-line on the ACTUAL RUN (§4.1)

- `[101] "You're back after all this time, but she keeps her distance."` — competent,
  flat, fine. Reads like a serviceable RP line. No subtext beyond the bare `but`.
- `[103] "You've returned, but she keeps her distance."` — **dead.** "You've returned"
  is a stage direction, not prose. This is the contrast-template at its most exposed:
  proposition `but` proposition.
- `[104] "It's raining. You came back, and she keeps her distance, and she's glad, and
  she lets it stand."` — **the worst line in the entire candidate set across all four
  docs.** This is the enemy cadence verbatim: "clause, and clause, and clause, and
  clause." It is a true sentence assembled by a machine that cannot fuse. The candidate
  admits this. It is mad-libs-of-clauses: each proposition gets exactly one `, and`
  clause, 1:1, in salience order.
- `[102] "After a silence that had set like cement, you found your way back here, and
  she keeps the table between you on purpose, and something unknots behind her
  sternum."` — **genuinely the best mechanism-produced line in the doc.** "set like
  cement" and "something unknots behind her sternum" are real images and the long
  breath has cadence. BUT: those images are pre-written lexicon strings
  (`guarded → lyrical → ["holds herself like a door only cracked", "keeps the table
  between you on purpose"]`), and the spine is still `X, and Y, and Z` — the same
  concatenation as 104, just with prettier furniture and one fewer joint showing.
- `[105]` — strongest run line; "the rain keeps up its low argument on the roof" is a
  real authored image. Again: that image is a lexicon string, not a derived one. The
  `though`-concession is the only structural move lifting it above 102.

### Run vs hand

A is honest: it labels 102/105 as run and the genuinely literary samples (§4.3,
the "six months, and her hands stay exactly where they are. The rain says the rest.")
as `[HAND]`. **A's best prose is hand-derived.** The hand lines demonstrate the form's
*reach* but are the agent writing, not the toy generating. The toy's own ceiling is
102/105 — pretty lexicon strings on an `and`-spine — and its floor is 104, the
deadest line anywhere.

### Sharpest attack

> "It's raining. You came back, and she keeps her distance, and she's glad, and she
> lets it stand."

This is a machine listing four facts with `and`. The mechanism produced the exact
failure the whole thesis names as the enemy.

### Score: **4/10**

The mechanism's median is stiff and its worst is the canonical wooden cadence. Its
best run lines lean entirely on pre-authored lexicon images. The diagnosis ("need
fusion trees") is correct and honest, but those trees don't exist in the artifact, so
the actual output today is below bar.

---

## Candidate B — Construction Grammar

### Line-by-line on the ACTUAL RUN (§4)

- `[1] "You came back," she says, not quite looking at you. She registers you after
  all this time. Rain ticks against the window.` — first sentence is good (the "not
  quite looking at you" tag is real subtext). Then it **falls apart at the seam**:
  "She registers you after all this time" is a clunky, redundant restatement of the
  line that just spoke, and "Rain ticks against the window" is a bolted-on coda. Three
  sentences that don't cohere — the idiom-tile seam the candidate confesses.
- `[2] The rain is coming down soft and steady, blurring the street to grey. And then
  there you are again, the months since collapsing to nothing. "I didn't think you
  would," she says, not quite looking at you.` — **strong.** "the months since
  collapsing to nothing" is a real image; "I didn't think you would" is genuine
  understatement; the tag lands. This reads like authored RP. Best run line in B.
- `[4]` — "Maren's gaze finds you after all this time" — the caused-motion construction
  works, but "after all this time" reused verbatim from line 1 exposes the finite tag
  pool.
- `[5] Rain ticks against the window. Her head comes up the moment you cross the
  threshold. "So. You're back."` — **good, crisp, distinct voice.** "So. You're back."
  is exactly the clipped flat register it claims. The double-take clause has real
  cadence.
- `[6] ... "You came back," she says, and the wariness in it doesn't quite cover the
  rest.` — the `S.glad_undercut` construction genuinely fuses glad+guard in one line.
  This is real subtext-as-a-unit.

### Run vs hand

**B's strongest lines are ALL run, not hand-derived** — B contains no `[HAND]` showcase
at all. That is the most honest provenance of the four: what you see is what the
mechanism did. The catch (and it's a big one): the subtext lives inside whole
pre-authored construction strings (`S.glad_undercut`, the "not quite looking at you"
tag). The *mechanism* chose which construction; the *craft* was baked into the
construction by a writer. Still — B at least proves the composition produces coherent,
voiced, varied beats from those units, and the seams (line 1) are visible and named.

### Sharpest attack

> "She registers you after all this time. Rain ticks against the window."

Two grammatical, on-topic, true sentences that have nothing to do with each other.
This is assembled tiles — the join carries no relation, so adjacency reads as a list
of facts, not prose.

### Score: **6/10**

The median run line is competent-to-good and the voice distinction is real (terse_wry
vs plain_flat vs lyric_warm are audibly different). The idiom-tile seam (no cohesion
constructions) is the live defect and it shows in half the lines. Subtext is real but
pre-baked into construction strings.

---

## Candidate C — Transformational / edit-sequence

### Line-by-line on the ACTUAL RUN (§4)

- `[terse-guarded/11] "She's glad, and won't quite let it show."` — **good.** Genuine
  restraint, one fused tension image, real cadence. The paradigm working.
- `[warm-lyrical/77] "Something in her eases, and won't quite let it show — you walked
  back in, even if after so long away."` — decent, the em-dash gives cadence, but "even
  if after so long away" is grammatically awkward (dangling). Borderline.
- `[terse-guarded/4242] "She stays careful."` — **BROKEN.** `elide` dropped the glad
  pole; the entire committed affect (glad-but-guarded) collapsed to a flat guard
  statement. Not stiff — *wrong*. The beat's whole point is gone. C flags this itself.
- `[warm-lyrical/31337] "The gladness gets ahead of her, now that she keeps the door
  only half open, you walked back in, after all these silent months."` — **comma-spliced
  run-on.** Four clauses chained by commas; a grammatical error, reads as a list. This
  is C's version of A's seed=104 failure.
- `[wry-deflecting/9001] "Not that she'd say she missed you, she keeps one eyebrow up,
  look who's back."` — same comma-list stiffness; reads as three fragments shoved
  together.

C's own §5 admits: **three of six run lines clear a bar; three read mechanical or are
broken.** I confirmed this by re-running — and it's actually worse on a second look,
because "won't quite let it show" appears in lines 11, 77, AND 9001's neighbors: the
fused tension-image is **the same string every time it fires.** The "fusion" is one
canned phrase, not a productive operation.

### Run vs hand

C is the most honest about failure: its best showcase line is explicitly `[HAND]`
("What gets her, after this long, is that you came back at all — and the rain keeps on
against the glass, saying it for her") — agent prose, not mechanism. The mechanism's
own run median is broken-or-stiff by C's own count, and the repeated "won't quite let
it show" exposes that the marquee fusion is a single hardcoded string.

### Sharpest attack

> "The gladness gets ahead of her, now that she keeps the door only half open, you
> walked back in, after all these silent months."

A four-clause comma splice. The transform pipeline produced an ungrammatical run-on —
the linearizer is mad-libs at the seam, exactly as C confesses.

### Score: **3/10**

Half the run output is mechanical or broken, the signature fusion is one repeated
canned phrase, and one line is a grammatical run-on. The transform-interference and
dumb-linearizer failures are real and present in the output today. Lowest actual
quality of the four.

---

## Candidate D — Analogical Schema Induction

### Line-by-line on the ACTUAL RUN (§4)

- `[101] Rain on the glass. Behind the bar, she looks up. "You're back." A statement,
  not a question.` — **good.** "A statement, not a question" is a real characterizing
  beat. Clean terse cadence.
- `[202] ... Her hands plant themselves on the counter like they're guarding the till.
  "Well, look what the rain dragged in," she says, which is as close to glad as she gets
  out loud.` — **strong.** The body-tell ("guarding the till") and the wry undercut
  ("as close to glad as she gets out loud") are genuine craft. Distinct wry voice.
- `[404] Rain unspools down the pane, steady as an old argument. "You came back," she
  says, the way you'd touch something you weren't sure was real. A muscle works once at
  the hinge of her jaw and goes still.` — **the best single sample across all four
  candidates.** "steady as an old argument," the gladness rendered as the GAP between
  flat words and simile, the guarded body-tell fused to one image. This reads at
  frontier RP craft.
- `[505] Behind her the downpour blurs the lamps to smears of gold. "There you are,"
  she says, and the smallness of it carries more than the words. ...` — **strong.**
  "the smallness of it carries more than the words" is explicit, earned subtext.
- `[606] She's at the counter. Shoulders up. "Huh," she says. "You."` — **excellent
  terse register.** Completely different cadence from 404; the button lands last.
- `[707]/[808]` — "and leaves it there" — good plain register, and 808 vs 707 shows the
  rain-anchor slot swapping ("Water runs down the glass" vs "It's still raining
  outside") — visible lexical variety on a fixed structure.

The forced-register block is the cleanest voice-isolation of any candidate: same
content, four audibly distinct voices, and lyrical/terse also differ structurally.

### Run vs hand — THE CRITICAL CATCH

D's run output is the best-reading of the four **by a clear margin**. But I checked the
mechanism: `distinct outputs over 4000 seeds = 375`. D admits this. The lexicon is
~140 hand-authored surface strings — "steady as an old argument," "the way you'd touch
something you weren't sure was real," "as close to glad as she gets out loud" are all
**pre-written strings typed into the prototype's tables by the agent.** The mechanism
selects a schema skeleton and picks a string from a small pool per role. So D's
gorgeous output is **mostly the agent's writing, surfaced through a chooser** — closer
to high-class retrieval than generation. The `[HAND]` label is only on the depth-
*reading* of 404, but the run lines themselves are built from hand-authored
constituents. D's quality is real on screen and weak as evidence about the MECHANISM:
it proves the schema-skeleton+role-selection assembles coherent beats, but the prose
beauty is the writer's, and the full-support/openness claim is explicitly stubbed
(375 finite outputs, by D's own count).

### Sharpest attack

> [seed 202, gate test] "A slow breath, but "Huh," she says. "You.""

The concessive joiner produced a broken mid-sentence quote capitalization — and more
tellingly, even D's beautiful lines are pre-authored strings: strip the lexicon to
what a *net* would have to induce and the demonstrated quality evaporates, because
375-distinct-over-4000 is a glorified pool, not a generative language.

### Score: **6/10** (output reads ~8; mechanism-attributable quality ~4 — I score the
coupling)

The on-screen prose is the best of the four, but the mechanism on trial is the
schema-skeleton chooser over a finite hand-authored pool. The quality you see is
overwhelmingly the agent's pre-written strings, not induced generation. Honest, but
the evidence cuts against the mechanism even as it flatters the page.

---

## Ranking — by ACTUAL OUTPUT QUALITY (on the page)

| rank | candidate | score | killer quote |
|------|-----------|-------|--------------|
| 1 | **D — Schema** | 6 (page ~8 / mech ~4) | "A slow breath, but "Huh," she says." (broken join); beauty is pre-authored strings |
| 2 | **B — CxG** | 6 | "She registers you after all this time. Rain ticks against the window." (tiles don't cohere) |
| 3 | **A — TSG/TAG** | 4 | "You came back, and she keeps her distance, and she's glad, and she lets it stand." (enemy cadence) |
| 4 | **C — Transform** | 3 | "The gladness gets ahead of her, now that she keeps the door only half open, you walked back in, after all these silent months." (comma-splice run-on) |

D and B tie at 6 on the raw number but for opposite reasons: **D reads best but its
quality is least attributable to its mechanism** (finite pre-authored pool); **B reads
slightly rougher but its quality is most attributable to its mechanism** (all run, no
hand-showcase, and the composition itself produces the coherence and voice). If I
weight by "is this evidence the MECHANISM is good," B edges ahead of D. On raw page
quality, D wins.

---

## Which MECHANISM is most likely to produce frontier prose

**Construction Grammar (B).** Not because its page output is prettiest — D's is — but
because B is the only candidate where (a) the strongest samples are mechanism-produced
run output with no hand-derived showcase propping it up, (b) the subtext is carried by
a real grammatical unit (`glad_undercut` fuses both stances in one productive
construction, not one canned string repeated), and (c) its single failure mode —
idiom-tile seams — has a named, in-formalism fix (cohesion/RST constructions as
first-class members) that does not require solving an unproven research bet. B's
ceiling is gated by constructicon density, which is build effort, not a paradigm
hole.

D's mechanism is the runner-up on craft but its demonstrated beauty is the agent's
pre-written strings over a 375-output finite pool; its frontier claim rests entirely
on the OPEN-sub-grammar seam it admits it stubs — which is precisely the seam every
candidate inherits as unproven. A's mechanism produces the enemy cadence in its own
run output. C's mechanism produces broken and run-on lines in half its run output and
its marquee "fusion" is one repeated hardcoded phrase.

The brutal summary: **every candidate's prettiest words are pre-authored** (lexicon
strings in A/B/D, hand-derived showcases in A/C). The question is which mechanism does
the most *generative* work around those words. B fuses stance compositionally and
varies structure at the root with all-run evidence; that is the strongest claim on the
mechanism actually reaching frontier craft once the lexicon is induced at scale.
