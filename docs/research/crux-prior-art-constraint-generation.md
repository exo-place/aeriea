# Prior art for the constrain-then-generate crux (lazy, consistent, on-demand generation)

Status: **RESEARCH / PRIOR-ART MAP — cited; verdict: known-hard-with-workarounds** (2026-06-19)

Scope: this answers whether prior art has solved *deterministic, bounded-cost,
on-demand generation that stays consistent with an unboundedly-growing fact set
without painting into a corner* — the open crux in
`docs/decisions/simulation-depth-and-materialization.md`. It was produced by an
adversarially-verified deep-research pass: 6 angles decomposed, 24 sources
fetched, 101 claims extracted, 25 verified by independent sub-agents (23
confirmed, 2 killed), 8 claims synthesized. Every finding below cites the
primary source the evidence was drawn from. The doc feeds the design decision in
`docs/decisions/simulation-depth-and-materialization.md`; cross-links are at the
bottom.

---

## Verdict

**KNOWN-HARD-WITH-WORKAROUNDS** — not solved, not freshly open.

The deciding theoretical fact: detecting whether a consistent completion exists
is NP-hard in general (stated directly by WFC's own author). Corner-risk scales
with GLOBAL (non-local) constraints: local-adjacency problems like WFC's native
image task almost never corner (an ASP surrogate hit zero conflicts even with
heuristics disabled); adding a single global constraint produced hundreds of
conflicts and made WFC's global-restart recovery time out where local
backtracking solved it instantly.

The "incomplete but never wrong" half is achieved cleanly by ASP/SAT-based PCG
(Smith & Mateas; Tanagra; Refraction): correct-by-design systems detect
unsatisfiability and report yes/no rather than emitting an approximation. The
cost is whole-artifact global solves — not lazy per-query — with
exponential-worst-case runtime, viable only at constant-bounded scale.

The most promising starting point for G is a solver-based (SAT/ASP) formulation
combined with completeness-preserving recovery: Ginsberg's dynamic backtracking
(polynomial-space, complete) avoids discarding committed work, which is the
closest match to "recover from a corner without throwing it all away."

The genuinely unsolved residue is the unbounded-incremental regime itself:
iterated belief revision proves the committed-history state needed to stay
consistent under future additions grows exponentially and cannot in general be
folded into a single current state — the direct formal analog of the crux, and
the wall no surveyed system clears at scale.

---

## Findings by neighborhood

### WFC — closest direct precedent

**WFC is formally constraint solving with the weakest corner-handling of all
surveyed approaches.** On contradiction it either halts without output or
globally restarts from scratch (non-backtracking greedy search). Propagation is
arc-consistency (AC-3-equivalent) with minimum-remaining-values / lowest
Shannon-entropy selection. Backtracking variants (DeBroglie etc.) are
third-party additions, not native.

> "WFC implements a non-backtracking, greedy search method... Gumin's algorithm
> does not implement local backtracking and instead globally restarts in the
> rare case a conflict is reached. If there is a contradiction, throw an error
> and quit." — Karth & Smith, FDG 2017

> "the algorithm has run into a contradiction and can not continue" — mxgmn
> README

Confidence: **high**. Sources:
[Karth & Smith (FDG 2017)](https://adamsmith.as/papers/wfc_is_constraint_solving_in_the_wild.pdf),
[mxgmn WaveFunctionCollapse README](https://github.com/mxgmn/WaveFunctionCollapse)

---

**Corner-risk scales with GLOBAL (non-local) constraints, not local ones.**
WFC's near-corner-free success on its native image task comes from constraint
propagation over purely local adjacency. Adding one global constraint breaks the
recovery strategy.

> "the strength of WFC comes from constraint propagation... rather than the
> entropy heuristic." The ASP/Clingo surrogate hit ZERO conflicts on real 48×48
> scenarios even with heuristics disabled. But adding a single global 'every
> pattern must be used' constraint "leads to hundreds of conflicts for the
> Skyline scenarios. When Clingo is instructed to globally restart after each
> conflict (mimicking WFC), it cannot find a solution within the one-minute
> timeout window. However, if backtracking is allowed... the constraint can be
> quickly resolved by adjusting local choices." — Karth & Smith (FDG 2017)

The paper anticipates "the demand for global constraints like this to grow."

Confidence: **high**. Source:
[Karth & Smith (FDG 2017)](https://adamsmith.as/papers/wfc_is_constraint_solving_in_the_wild.pdf)

---

**Deciding whether a valid completion exists is NP-hard — the formal floor
under the crux.**

> "The problem of determining whether a certain bitmap allows other nontrivial
> bitmaps satisfying condition (C1) is NP-hard, so it's impossible to create a
> fast solution that always finishes." — Maxim Gumin (algorithm author), mxgmn
> README

Note: implementations terminate (halt on contradiction); what is NP-hard is
efficiently deciding existence / finding a valid completion.

Confidence: **high**. Source:
[mxgmn WaveFunctionCollapse README](https://github.com/mxgmn/WaveFunctionCollapse)

---

### ASP / Solver-based PCG — recommended architectural fork

**Moving from native WFC to a general-purpose constraint solver (SAT/ASP) is the
recommended fork.** A solver-based reformulation can express both local AND
global (non-local) constraints, handle the corner via complete
conflict-driven backtracking (CDNL/DPLL descendant), and reject whole
subspaces of inconsistent worlds before any full artifact is generated.

> "methods which do not use a general-purpose constraint solver, such as
> Gumin's implementation of the WaveFunctionCollapse (WFC) algorithm... have
> limited constraint propagation ability and cannot express non-local
> constraints," whereas solver-based WFC "effectively controls the statistics...
> while still enforcing global constraints." — Katz, Bateni & Smith (arXiv:2409.00837, FDG 2024)

> "build[s] the map wall by wall... reject the large subspace of potential
> mazes... after only a few exploratory commitments... backtrack and try
> alternatives... evaluate an incompletely defined artifact in a local manner."
> — Smith & Mateas (TCIAIG 2011)

> "conflict-driven nogood learning (CDNL), a state-of-the-art, complete,
> backtracking, heuristic search algorithm... inspired by the Davis-Putnam
> algorithm" that "enumerate[s] all (and only) those puzzles with the required
> properties" or proves none exist. — Smith et al. 2012

Confidence: **high**. Sources:
[Katz, Bateni & Smith (arXiv:2409.00837)](https://arxiv.org/abs/2409.00837),
[Smith & Mateas TCIAIG 2011](https://adamsmith.as/papers/tciaig-asp4pcg.pdf),
[Smith et al. 2012](https://grail.cs.washington.edu/wp-content/uploads/2015/08/smith2012acs.pdf)

---

**Existing solver-based PCG systems cleanly achieve "incomplete but never
wrong."** Tanagra and Refraction are correct-by-design: they either fill in a
guaranteed-valid completion or explicitly report no valid artifact exists. A
reference solution is co-generated as an existence proof.

> "correct by design (in that they always produce content conforming to input
> requirements upon termination when it is logically possible to do so)" and
> "correctly report whether a puzzle is solvable... (yes/no)." — Smith et al. 2012

> Tanagra: "The computer then fills in the rest of the level with geometry that
> guarantees playability, or informs the designer that there is no level that
> meets their requirements"; on conflict it turns the canvas red. — Smith,
> Whitehead, Mateas (Tanagra)

> "generate a reference solution along with the level design. If a map contains
> a valid reference solution, we have a proof (by existence) that it is
> solvable." — PCG book ch. 8

The constrain-then-generate / mixed-initiative pattern (commit/forbid facts,
solver completes consistent remainder) is realized by dynamically reassembling
an AnsProlog program from committed facts plus rules — "closely matching
G(seed, constraints, query)."

Confidence: **high** (with one caveat: the claim that integrity constraints
constitute a "native semantic guarantee of ASP" was refuted 1-2 by independent
verifiers; the correct characterization is correct-by-design via complete
conflict-driven search, not by integrity-constraint construction alone).

Sources:
[Smith et al. 2012](https://grail.cs.washington.edu/wp-content/uploads/2015/08/smith2012acs.pdf),
[Tanagra / Butler & Smith](https://www.semanticscholar.org/paper/A-mixed-initiative-tool-for-designing-level-in-Butler-Smith/05c720785233f1368915908a75e7b54f7a5a7dfe),
[PCG book ch. 8](https://www.pcgbook.com/chapter08.pdf),
[Smith & Mateas TCIAIG 2011](https://adamsmith.as/papers/tciaig-asp4pcg.pdf)

---

**The feasibility wall: grounding plus exponential worst-case, constant-bounded
scale only.** ASP/SAT PCG solves WHOLE artifacts globally per solve — not lazily
per query — and re-pays grounding cost when requirements change.
Universally-quantified constraints ("every possible play satisfies X") push
complexity to Sigma-2-P, far above NP.

> "our current encodings are cubic in player-controlled piece count... the fact
> that Refraction is played on a constant-bounded scale (with no more than a
> handful of player-controlled pieces) means this growth is a theoretical
> curiosity... That the solver's worst case running time is bounded only by an
> exponential in the size of the grounded problem is similarly uninteresting for
> realistic problems." — Smith et al. 2012

> The 'unavoidable concept' meta-programming extension lets programs "express
> any problem in the complexity class Sigma-2-P (conventionally assumed to be
> much larger than the class NP)," requiring a special disjunctive answer-set
> solver. — PCG book ch. 8

ASP is structurally ground-then-solve, which precludes lazy per-query
materialization.

Confidence: **high**. Sources:
[Smith et al. 2012](https://grail.cs.washington.edu/wp-content/uploads/2015/08/smith2012acs.pdf),
[PCG book ch. 8](https://www.pcgbook.com/chapter08.pdf)

---

### TMS / Belief revision — open wall in the incremental regime

**Ginsberg's dynamic backtracking is the most directly relevant technique for
recovery without discarding committed work.** It moves backtrack points deeper
to avoid erasing meaningful progress, uses only polynomial space, and retains
completeness (finds a solution if one exists, or proves none). The caveat:
it is a search technique over a FIXED CSP, not natively an online
constraint-ADDITION algorithm, and completeness bounds memory, not time
(worst-case runtime stays exponential).

> "existing backtracking methods can sometimes erase meaningful progress...
> backtrack points can be moved deeper in the search space, thereby avoiding
> this difficulty"; it is "a variant of dependency-directed backtracking that
> uses only polynomial space while still providing useful control information
> and retaining the completeness guarantees." — Ginsberg, 'Dynamic Backtracking'
> (JAIR 1, 1993)

Unlike full dependency-directed backtracking (exponential space recording all
nogoods), it keeps a single valid explanation. Applicability to incremental
constraint accumulation is the claimant's inference, not the paper's explicit
claim.

Confidence: **high**. Source:
[Ginsberg 1993 (arXiv:cs/9308101)](https://arxiv.org/pdf/cs/9308101)

---

**The unbounded-incremental regime is the genuinely open residue.** Iterated
belief revision proves the committed-history state needed to stay consistent
under future fact-additions grows exponentially and cannot in general be folded
into a single current knowledge base.

> "the operators... need some extra information that depend on the history of
> the previous revisions. The size of this information becomes quickly
> exponential, thus we need a criterion to decide when the history becomes
> irrelevant, that is, when the changes can be 'committed'." — Liberatore,
> 'The Complexity of Iterated Belief Revision' (ICDT 1997)

> "if we store a f = \*[p1,...,pm] and forget the formulas p1,...,pm, then we
> have not enough information to evaluate \*[p1,...,pm,pm+1]. At any time, the
> revision process must take into account the history of the past revisions, or
> a suitable data structure representing it." — Liberatore (ICDT 1997)

Corroborated by Darwiche & Pearl (1997): AGM belief sets are insufficient for
iteration; one must carry epistemic states. Liberatore's 2024 work
(arXiv:2402.15445) shows only specific redundant revisions can be dropped
(detecting redundancy is coNP-complete), refining, not refuting, the 1997
result.

Confidence: **medium** — rests on a single primary source plus a structural
bridge to G (the claimant's inference), and one split verifier vote (2-1 on one
sub-claim, 3-0 on another).

Source:
[Liberatore (ICDT 1997)](https://dl.acm.org/doi/abs/10.5555/645502.656098)

---

### Refuted claims (killed by independent verifiers, do not rely on)

1. **DeBroglie adds full backtracking to WFC and "solves arbitrarily complicated
   constraint sets rather than terminating on the first contradiction."** — vote
   1-2. Source: [https://github.com/lichnak/DeBroglie](https://github.com/lichnak/DeBroglie)

2. **Integrity constraints guarantee global consistency by construction — the
   "incomplete but never wrong" property is a native semantic guarantee of
   ASP.** — vote 1-2. Source:
   [Smith & Mateas TCIAIG 2011](https://adamsmith.as/papers/tciaig-asp4pcg.pdf)

---

### Open questions (neighborhoods that produced no surviving verified claims)

These angles were investigated but produced no claims that survived adversarial
verification. The absence of evidence is not evidence of absence; they are
reported as open.

- **Eager forward-sim cost wall** (Dwarf Fortress, Caves of Qud history-gen,
  Talk of the Town, Versu, Bad News): no verified claims survived. The
  lazy-vs-eager premise remains **untested by this evidence**. DF and Qud
  demonstrably ship at non-trivial scale; whether eager forward-sim is infeasible
  for deep persistent worlds is unresolved by this report.

- **Procedural mystery / detective generation** (globally consistent facts
  revealed incrementally): no surviving claims on whether any system maintains
  global solution consistency under incremental reveal or avoids dead ends via
  constraint techniques.

- **Formalized tabletop "lazy canon" / observer-collapse improv**: no surviving
  claims on whether these maintain formal global consistency.

- **Seeded determinism + lazy materialization + correct-by-design global
  consistency under unbounded facts** — this specific three-way combination
  appears to be genuinely unstudied in the surveyed literature. No source
  addresses the seeded-determinism or replay requirements of G.

---

## What this means for G (design implications)

These implications are drawn only where the report's evidence directly supports
them. Anything beyond the evidence is marked explicitly.

1. **Keep constraints LOCAL where possible.** Corner-risk is empirically driven
   by global (non-local) constraints. Pure local-adjacency problems almost never
   corner; one global constraint broke WFC's global-restart recovery. The
   architecture should minimize globally-scoped constraints on G's output.

2. **"Incomplete but never wrong" is achievable.** Solver-based, correct-by-design
   generation (SAT/ASP) cleanly achieves this half of the crux: detect
   unsatisfiability, report yes/no, never approximate. This is not theoretical;
   Tanagra and Refraction realize it in shipped systems.

3. **Candidate technique stack: SAT/ASP + Ginsberg dynamic backtracking.** The
   report's recommended starting point is a solver-based formulation combined
   with dynamic backtracking for recovery (polynomial-space, complete, doesn't
   discard committed facts). Dynamic backtracking's applicability to
   constraint-ADDITION (vs. a fixed CSP) is an *inference beyond the sources*
   and requires further investigation.

4. **The open wall is the unbounded-incremental regime.** No surveyed system
   jointly achieves bounded per-query cost AND unbounded incremental fact
   accumulation. The belief-revision result shows this is formally hard: history
   state grows exponentially and cannot be collapsed in general. Any practical G
   will need a deliberate policy for when history can be committed (bounded
   representation) — this is the unresolved design question.

5. **The lazy-vs-eager premise is untested by this report.** Whether eager
   forward-sim is infeasible at the relevant scale is not confirmed or refuted
   here. *Inference beyond the sources*: the `existence` prior-art study
   (`docs/research/existence-prior-art.md`) gives partial evidence on this via
   a single-entity forward-sim case.

---

## Sources

All URLs cited in confirmed findings above, deduplicated:

- <https://adamsmith.as/papers/wfc_is_constraint_solving_in_the_wild.pdf> — Karth & Smith, "WFC is Constraint Solving in the Wild" (FDG 2017); primary
- <https://github.com/mxgmn/WaveFunctionCollapse> — mxgmn WFC README (algorithm author Maxim Gumin); primary
- <https://arxiv.org/abs/2409.00837> — Katz, Bateni & Smith, solver-based WFC (FDG 2024); primary
- <https://adamsmith.as/papers/tciaig-asp4pcg.pdf> — Smith & Mateas, "ASP for PCG" (IEEE TCIAIG 2011); primary
- <https://grail.cs.washington.edu/wp-content/uploads/2015/08/smith2012acs.pdf> — Smith et al. 2012 (Refraction / correct-by-design PCG); primary
- <https://www.semanticscholar.org/paper/A-mixed-initiative-tool-for-designing-level-in-Butler-Smith/05c720785233f1368915908a75e7b54f7a5a7dfe> — Butler & Smith, Tanagra mixed-initiative tool; primary
- <https://www.pcgbook.com/chapter08.pdf> — PCG book ch. 8 (ASP, grounding, Sigma-2-P); primary
- <https://arxiv.org/pdf/cs/9308101> — Ginsberg, "Dynamic Backtracking" (JAIR 1, 1993); primary
- <https://dl.acm.org/doi/abs/10.5555/645502.656098> — Liberatore, "The Complexity of Iterated Belief Revision" (ICDT 1997); primary

Additional sources fetched during the research pass (contributed to claim extraction but not to the confirmed surviving findings above):

- <https://www.boristhebrave.com/2020/04/13/wave-function-collapse-explained/> — Boris the Brave, WFC explained; blog
- <https://en.wikipedia.org/wiki/Model_synthesis> — Model synthesis; secondary
- <https://www.boristhebrave.com/2021/08/30/arc-consistency-explained/> — Boris the Brave, arc consistency; blog
- <https://github.com/lichnak/DeBroglie> — DeBroglie library (refuted claim source)
- <https://arxiv.org/abs/2406.00554> — (ASP/PCG angle); primary
- <https://www.cs.tau.ac.il/research/alexander.nadel.moved-to-redirection.2014-05-25/sat12_SAT_under_assumptions.pdf> — SAT under assumptions; primary
- <https://ojs.aaai.org/index.php/AIIDE/article/download/12896/12744/16413> — procedural mystery generation (AIIDE); primary
- <https://ceur-ws.org/Vol-2282/EXAG_113.pdf> — procedural mystery / detective gen (EXAG); primary
- <https://arxiv.org/pdf/2004.01768> — procedural mystery gen; primary
- <https://escholarship.org/uc/item/1340j5h2> — eager forward-sim (IEN); primary
- <https://mkremins.github.io/publications/IENHistory_ICIDS2021.pdf> — IEN history generation (ICIDS 2021); primary
- <https://inky.org/rpg/no-myth.html> — No-Myth RPG improv; blog
- <https://wordmillgames.itch.io/mythic-game-master-emulator-second-edition> — Mythic GME; primary
- <https://minds.wisconsin.edu/bitstream/handle/1793/93144/Bruner_uwm_0263D_13509.pdf?sequence=1&isAllowed=y> — Bruner dissertation (lazy-canon worldbuilding); primary

---

## Cross-links

- `docs/decisions/simulation-depth-and-materialization.md` — the crux this informs: deterministic, bounded-cost, on-demand generation under a growing global consistency constraint set
- `docs/research/existence-prior-art.md` — the local prior-art study of `existence` as partial evidence on eager forward-sim for a single entity
- `docs/decisions/prose-generation.md` — the realizer↔`G` interface this evidence also bears on
