# Judge 2 — Determinism + Content-Gate (faithfulness) attack

Adversarial review of the four text-gen grammar candidates against two hard
requirements: **(A) bit-for-bit cross-platform determinism** and **(B) a content
gate that actually prevents unlicensed false assertion while still permitting
*licensed* falsity**. Every claim below was checked against the **actual prototype
source and runs**, not the design prose. Breaking inputs are concrete.

Prototypes inspected/run:
`/tmp/tsg/tsg.py` (A), `/tmp/cxg_proto/cxg.py` (B),
`/tmp/transform_proto/proto.py` (C), `/tmp/schema_proto.py` (D).

---

## A. DETERMINISM — what I verified

**No float in any selection path.** All four draw via integer splitmix64 + integer
modulo over integer weight tables. I grepped every `/`, `float`, `.0` in the
selection path of all four: none normalize weights with float division before the
draw; `pick()` is `next() % total` then integer cumulative comparison in every
prototype. The "any float in the selection path?" attack finds nothing. This axis
is genuinely strong across the board — the differentiator is **iteration-order
leakage** and **seed-mixing hygiene**, not floats.

**Dict-iteration-order leakage (the real cross-platform hole).** The danger is a
weighted `pick` over a candidate *list* whose order is produced by iterating a
`Dictionary`/`Set`. Godot `Dictionary` and Rust `HashMap` do **not** guarantee the
insertion order CPython 3.7+ gives, so a naive port reorders the candidate list,
re-buckets the cumulative weights, and the *same* draw integer selects a
*different* item → divergence between the prototype's "verified determinism" and
the shipped Godot/Rust runtime.

- **D — WORST.** `generate()` builds `sopts` by iterating `SCHEMAS.items()` with
  **no sort** (`/tmp/schema_proto.py:266`), then `rng.pick("schema", sopts)`. Pick
  keys the draw on the `site_id` string but buckets cumulative weight in *list
  order*. Port `SCHEMAS` to a Godot `Dictionary` and the bucket boundaries move →
  a different schema for the same seed. Concrete break: seed that lands in the
  boundary band between two equal-affinity schemas selects schema #1 in CPython,
  schema #2 under a reordering port. D's own "determinism" is an artifact of
  CPython dict order it never sorts away.
- **B — latent.** `BY_SEM` is built from the `CONSTRUCTICON` *list*, so order is
  stable *in the prototype*. But the design (§1.2) describes the shipped artifact
  as "indexed by `sem`" (dict-of-lists); if a port rebuilds those lists by
  dict-iterating, same hole. Not triggered today; one careless port away.
- **A — safe.** `VOICES` is a dict but every access is by key into an ordered
  *list* (`V["joins"]`, `V["register"]`); `content_keys` is a list. No draw buckets
  over dict-iteration order.
- **C — safe by construction.** `atoms` is built by iterating the `ATOMS` dict
  (`proto.py:301`) BUT `t_select` immediately `sorted(..., key=(-salience, a))`
  imposes a total order, and `t_figure`/`t_elide` both `sort`/`sorted` their
  candidate sets before drawing. Every order-sensitive site is explicitly
  totally-ordered. This is the only candidate that *defensively* kills the hole.

**Seed-mixing hygiene.**
- **A** has a confused, dead expression: `rng = Rng(seed ^ (hash(voice_name) & 0))`
  (`tsg.py:159`) — the builtin salted `hash()` is masked to 0 so it's *harmless*,
  then immediately overwritten by `Rng((seed*1000003 + vidx*97 + 1))`. Integer-only
  and deterministic, but the leftover `hash()` is a smell: it shows the author
  reached for salted `hash()` and only narrowly avoided shipping it. A reviewer
  porting this could "clean up" the dead line and reintroduce `hash()`.
- **C** replaces builtin hash with FNV-1a (`str_seed`, `proto.py:47`); I ran it
  under `PYTHONHASHSEED=0` and `=1` — byte-identical. Correct.
- **D** uses FNV-1a (`fnv1a`) for both state and site ids — correct, salt-free.
- **B** seeds `Rng(seed)` directly with an integer; no string hashing at runtime.
  Correct, but the design's real seed `mix(global, intent, salience, voice)` is
  *not exercised by the prototype* — the prototype just passes literal seeds, so
  the seed-composition path (where a float salience or string id could sneak in) is
  **unverified** for B (and equally for A, whose `select_salient` sorts on an int).

**Verdict on A:** determinism is airtight *in practice* but the codebase is the
least hygienic (dead `hash()` line, voice folded by `list(...).index()` which is
itself a dict-order-ish smell — `vidx = list(VOICES.keys()).index(voice_name)`,
stable only because VOICES is a dict accessed by a fixed name).

---

## B. CONTENT-GATE / FAITHFULNESS — what I verified

The decisive attack (per the brief, surfaced by D): **does the gate operate at the
granularity of what is actually asserted — down to lexical fill — or only at a
coarse move/construction `requires` level, letting a `lit`/lexeme smuggle an
uncommitted fact past it?**

### D — confessed leak, reproduced

D admits the hole (§3 level-2) and I **reproduced it live**. With
`COMMIT["weather.raining"] = False`, `register="wry"`, **seed 0**:

> She's manning the counter like she never left it... "Well, **look what the rain
> dragged in**," she says...

The withheld-speech lexeme asserts *rain* but is gated only by the move selector
`affect.glad`. Rain is de-committed and the system still asserts it. D's design is
honest that the fix (per-construction `asserted_props ⊆ commitments`) is unbuilt.
The toy "passed" its own gate test only because the *anchor* path was checked, not
the *lexicon* path — the exact granularity failure the brief names.

### B — SAME leak class, UNCONFESSED (the key cross-candidate finding)

B claims (§3) "every clause traces to a committed proposition... nothing
uncommitted appears" and scores its gate as structural/airtight. **False.** B has D's
hole and does not admit it:

- `C.head_comes_up` (`cxg.py:119`) ships the `lit`
  *"head comes up the moment you cross the threshold."* — asserting a spatial fact
  (player crossing a threshold / a doorway scene) — gated **only** by
  `requires=["event.notice_return"]`. There is no `scene.threshold` commitment in
  B's store at all; the fact is asserted purely by frozen `lit` text the gate never
  inspects.
- `C.gaze_finds` (`cxg.py:108`) asserts eye-contact / a directed gaze ("gaze finds
  you"), again gated only by `notice_return`.

B's gate filters on `requires` keys but **never inspects what the `lit` strings
assert**. Identical granularity failure to D — the gate is at construction level,
not at asserted-proposition level — but B presents it as solved. That unearned
confidence is worse than D's confession. Concrete break: any scene where the player
did *not* enter through a threshold (e.g. was already inside) but `notice_return`
holds → `C.head_comes_up` asserts a false spatial fact, gate green.

### A — partial gate, ungated connective/coda text

A's gate is by-*concept* lexicalization: content slots fill only from committed
concepts (`tsg.py:170` `present = [k ... if k in COMMITMENTS]`), so no *concept*
leaks. But A's **join connectives and the coda are ungated `lit`**:
`", and she lets it stand"` (`tsg.py:225`) is appended unconditionally on a runon —
it asserts a *stance* (acceptance/letting-it-be) that is **not in the commitment
store**. The JOINS connectives (`"though"`, `"for it"` in `cause`) impose
rhetorical relations (concession, causation) that are themselves assertions about
how facts relate, none of which are gated. A's gate is narrower than it claims:
content nouns are gated, the *glue that asserts relations and a closing stance* is
not. Concrete break: any runon output asserts "she lets it stand" (an affect
A never committed).

### C — cleanest gate, but a faithfulness-of-*beat* break

C is the only candidate whose gate I could not break at lexical granularity:

- Every clause is built from an `atom` whose `prop` must be committed
  (`proto.py:301` filters `ATOMS` by `COMMITTED["props"].get(...)`).
- `figure` is prop-tagged: a figure fires only when its `required_prop` is
  committed AND a clause realizing that prop is present (`t_figure`,
  `proto.py:180-182`). I grepped every lexeme for cross-atom assertion (a
  non-rain atom asserting rain etc.) — **none**. The "look what the rain dragged
  in"-class leak that bit B and D does **not** exist in C, because the lexicon is
  keyed `(atom, register)` and the atom must be committed to be in the skeleton.

C's failure is different and the design confesses it: **transform interference**
breaks faithfulness of the *beat* even though every clause is individually true.
`terse-guarded/4242` → "She stays careful." — `elide` dropped the *glad* pole,
so the committed affect (glad-but-guarded) is no longer conveyed: every assertion
true, the *set* now asserts a false beat (she is merely guarded). And `fuse`
overwrites a `figure` (the design's own §5 finding). This is a real faithfulness
defect, but it is a *completeness/coherence* failure (the beat under-asserts), not
an unlicensed-falsehood leak — strictly less dangerous than B/D asserting things
that are flat false.

### Licensed falsity — can each still LIE / withhold / hallucinate?

The gate must still *produce* licensed falsity. None of the four **exercises** this
in its prototype (all flag it as designed-but-unrun), so I judge the *mechanism's
reachability*:

- **A:** commitment can be flagged `pov_belief` / `dialogue_assertion(truth=false)`
  and "the frame travels with the proposition" → renders "she says X". Mechanism is
  coherent but **unimplemented and untested**; the realizer has no code path that
  reads a license flag. Reachable in principle.
- **B:** "explicit license flag flips a `requires` from true-fact to
  believed/asserted-fact." Plausible — a `believes(speaker,P)` key licenses a
  dialogue construction — but **no construction in the constructicon carries a
  belief-frame**, and the speech constructions hardcode truthful glad/guard.
  Reachable only after building belief-framed speech cxns; today, not reachable.
- **C:** "licensed false prop injected into the skeleton with a license tag" — the
  cleanest model: a lie is itself a committed *speech-fact*, so the gate still
  holds and the realizer renders it like any atom. But again **no license tag is
  read anywhere in `proto.py`** — `faithfulness_check` only checks committed-true.
  Mechanism is the most coherent; implementation absent.
- **D:** `believes(Maren,P)` licenses asserting P in *her dialogue*; gate checks the
  frame-appropriate set. Cleanest stated story (POV/lie/altered-sense as a
  frame-scoped commitment set). Unimplemented.

All four are **equal on licensed-falsity: well-modeled, none demonstrated.** None
loses points relative to another here; none earns the "it works" claim.

### Steering to salient committed content (vs true-but-pointless)

- **C** steers hardest: `select` is salience-weighted and the design *keeps the
  glad/guard tension by default* — but the same mechanism mis-fired (elide killed
  the salient pole), so steering is present but unreliable.
- **D** has `WITHHELD_only_minimal` and salience-picked tells — restraint is a
  first-class move; steering present.
- **A** orders by salience and demotes low-salience to asides/omission
  (`contact_none` dropped) — present.
- **B** relies on the upstream salience layer to emit `sem` goals; the prototype
  hardcodes `BEAT_NOTICE`, so steering is **stubbed** — least demonstrated.

---

## Scores

| Candidate | Det /10 | Gate /10 | One concrete break |
|---|---|---|---|
| **C** transform | **8** | **8** | `terse-guarded/4242` → "She stays careful." — `elide` drops the committed *glad* pole; beat under-asserts (true clauses, false beat). No unlicensed-falsehood leak though. |
| **A** TSG/TAG | **7** | **6** | Every runon appends ungated `", and she lets it stand"` — asserts an uncommitted acceptance stance; join connectives assert ungated RST relations. Plus dead `hash()` smell at `tsg.py:159`. |
| **B** CxG | **7** | **4** | `C.head_comes_up` `lit` asserts "you cross the threshold" / `C.gaze_finds` asserts eye-contact, gated only by `notice_return` — D's leak class, **unconfessed**, while B claims the gate is airtight. |
| **D** schema | **5** | **5** | Reproduced live: rain de-committed, `register=wry` seed 0 still emits "look what the **rain** dragged in" (gate is move-level, not lexical). Confessed. PLUS `SCHEMAS.items()` unsorted pick → cross-platform dict-order divergence on port. |

Scoring logic:
- **Det:** C only candidate that *defensively sorts* every order-sensitive site (8).
  A/B airtight in-prototype but carry a dict-order/seed-hygiene smell one port away
  from breaking (7). D actively unsorted at `sopts` → real cross-platform hole (5).
- **Gate:** C breaks only at *beat completeness*, never asserts a flat falsehood,
  and its lexical-provenance is sound by the `(atom→committed-prop)` keying (8). A
  gates content nouns but leaks stance via ungated connective/coda `lit` (6). D
  leaks at lexical level but *confesses* and the model is clean (5). B has the same
  leak as D **and denies it** — the gate is mis-scored as structural in the design,
  which is the most dangerous posture (4).

## Ranking (combined determinism + faithfulness robustness)

1. **C (transform / edit-sequence)** — 16. Only candidate with a lexically-sound
   gate (asserted-prop provenance falls out of atom→commitment keying) AND
   defensive total-ordering against dict-order nondeterminism. Its failures are
   coherence/completeness (elide killing the salient pole, fuse clobbering figure),
   which the design names and which are fixable with a read/write-set + coherence
   pass — strictly less dangerous than asserting falsehoods.
2. **A (TSG/TAG)** — 13. Determinism airtight in practice; gate solid on content
   nouns but leaks relational/stance assertions through ungated `lit` connectives
   and the coda. Honest, fixable by gating join/coda text.
3. **B (CxG)** — 11. Determinism fine; but the gate has D's lexical-leak class
   (`lit` strings asserting uncommitted spatial/perceptual facts) **while the design
   claims the gate is structurally airtight**. The unearned-confidence gap between
   claim and code is the disqualifier here, not the leak itself — the leak is fixable;
   the mis-assessment means it wouldn't get fixed.
4. **D (schema)** — 10. Most honest about its lexical-provenance leak (confessed and
   reproduced), but it is the *only* candidate with a live cross-platform
   determinism hole (`SCHEMAS.items()` unsorted weighted pick) on top of the gate
   leak. Two real holes vs the others' one.

**Cross-cutting finding for synthesis:** the lexical-provenance gate
(`asserted_props(construction) ⊆ commitments`, enforced down to every `lit`/lexeme,
not just move/construction `requires`) is **mandatory for B and D and partially for
A** — only **C** gets it for free from its atom→commitment keying. Whatever
candidate wins, it must adopt C's discipline: gate on *what the surface text
asserts*, not on a separate `requires` annotation that the frozen text can silently
contradict. And every order-sensitive draw must be totally-ordered before the pick
(C's pattern), or the prototype's "determinism: True" is a CPython-dict-order
artifact that will diverge on the Godot/Rust port across flat/PCVR/Quest.
