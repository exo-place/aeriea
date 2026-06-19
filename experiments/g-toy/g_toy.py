#!/usr/bin/env python3
"""g-toy: a minimal, runnable feasibility probe for the constrain-then-generate crux.

Tests the substrate-design crux recorded in
  docs/decisions/simulation-depth-and-materialization.md
  docs/research/crux-prior-art-constraint-generation.md

CRUX (restated): a deterministic generator G(seed, constraints, query) that
answers an unassigned attribute with a value CONSISTENT with every committed
constraint, or correctly reports that no consistent completion exists (unsat) --
"incomplete but never wrong" -- at bounded cost, while the committed constraint
set only ever grows. The sharp sub-problem is "painting into a corner": drawing
greedily can foreclose a later consistent completion.

This probe builds:
  1. A tiny tunable world-fact domain (N people; attributes birth_year, parent,
     trait) with a LOCAL-vs-GLOBAL constraint knob (`global_fraction`).
  2. G as a hand-rolled CSP solver using DYNAMIC BACKTRACKING (Ginsberg 1993):
     on conflict it identifies a culprit assignment from the conflict's
     eliminating explanation and revises THAT, preserving unrelated committed
     work -- it does NOT global-restart. G is deterministic (seeded, fixed draw
     discipline) and never returns an inconsistent value.
  3. An observer loop: a seeded probe order over attributes; each answered query
     commits (binds forever); the committed set grows monotonically.
  4. Metrics: corner-rate (backjumps/query) across a global_fraction sweep, and
     cost-per-query (constraint-checks) as the committed set grows.

Stdlib only. Determinism is asserted in code (see check_determinism).

The CSP is the world model directly (no separate ground-truth instance to match):
G must keep the committed assignments + a consistent completion alive at all
times. A "corner" is a conflict that forces revising an already-committed-style
choice; we measure how often that happens as constraints get more global.
"""

from __future__ import annotations

import random
import statistics
from dataclasses import dataclass, field

NONE = -1  # sentinel for "no parent" in the parent domain


class _BudgetExceeded:
    """Sentinel return for a query that hit the per-query step budget before
    finding a value or proving unsat. This is NOT 'unsat' (no completion exists)
    and NOT a value -- it is a *measured corner that exceeded bounded cost*. The
    probe reports these rather than fabricating an answer: 'incomplete, never
    wrong' extended to 'and never over-budget-silently'."""
    def __repr__(self):
        return "BUDGET"


BUDGET = _BudgetExceeded()


# --------------------------------------------------------------------------
# Domain construction
# --------------------------------------------------------------------------

@dataclass
class Domain:
    """The variable/value structure of one toy world instance.

    Variables are (person, attr) pairs flattened into a list. Each variable has
    a finite candidate value domain (a tuple of ints). Constraints are arity-1
    or arity-2 (local) or arity-n (global), each a predicate over an assignment
    dict, together with the set of variables it touches (its "scope").
    """
    n_people: int
    year_lo: int
    year_hi: int
    traits: int
    variables: list[tuple[int, str]]
    value_domains: dict[tuple[int, str], tuple[int, ...]]
    # each constraint: (scope_frozenset, predicate(assignment)->bool, is_global)
    constraints: list[tuple[frozenset, object, bool]]


def build_domain(
    n_people: int,
    *,
    year_lo: int = 0,
    year_hi: int = 9,
    traits: int = 3,
    global_fraction: float,
    trait_cardinality: int = 1,
    parent_gap: int = 1,
) -> Domain:
    """Build a toy world with a local-vs-global constraint mix.

    LOCAL constraints (scope within one entity or a parent/child pair):
      - parent_year_before_child: if person p's parent is q (q != none), then
        birth_year[q] + parent_gap <= birth_year[p]. Scope = the two people's
        birth_year vars plus p's parent var. This is "local" in the prior-art
        sense: it relates an entity to ONE neighbor, not the whole instance.

    GLOBAL constraints (scope spans the whole instance), gated by global_fraction:
      - acyclic: the parent relation forms no cycle (a person is not their own
        ancestor). Scope = all parent vars.
      - distinct_years: all birth_years distinct -- a total temporal ordering
        (all-different). Scope = all birth_year vars.
      - trait_cardinality: exactly `trait_cardinality` people have trait 0.
        Scope = all trait vars.

    `global_fraction` in [0,1] selects how many of the 3 global constraints are
    active (0 -> none, 1 -> all three). It dials the corner-driver intensity so
    corner-rate can be measured as a function of it.
    """
    variables: list[tuple[int, str]] = []
    value_domains: dict[tuple[int, str], tuple[int, ...]] = {}
    for p in range(n_people):
        for attr, dom in (
            ("birth_year", tuple(range(year_lo, year_hi + 1))),
            ("parent", (NONE,) + tuple(q for q in range(n_people) if q != p)),
            ("trait", tuple(range(traits))),
        ):
            v = (p, attr)
            variables.append(v)
            value_domains[v] = dom

    constraints: list[tuple[frozenset, object, bool]] = []

    # ---- LOCAL: parent's birth year strictly before child's, by parent_gap ----
    for p in range(n_people):
        for q in range(n_people):
            if q == p:
                continue
            py_var, cy_var, par_var = (q, "birth_year"), (p, "birth_year"), (p, "parent")
            scope = frozenset({py_var, cy_var, par_var})

            def make_pred(p=p, q=q, py_var=py_var, cy_var=cy_var, par_var=par_var):
                def pred(a):
                    # only binds when p's parent is actually q
                    if a.get(par_var, None) != q:
                        return True
                    if py_var not in a or cy_var not in a:
                        return True  # not enough info yet -> not violated
                    return a[py_var] + parent_gap <= a[cy_var]
                return pred

            constraints.append((scope, make_pred(), False))

    # ---- GLOBAL constraints, gated by global_fraction ----
    # Deterministic selection: enable the first k of the 3 globals.
    globals_available = ["acyclic", "distinct_years", "trait_cardinality"]
    k = round(global_fraction * len(globals_available))
    active_globals = set(globals_available[:k])

    if "acyclic" in active_globals:
        parent_vars = frozenset((p, "parent") for p in range(n_people))

        def acyclic_pred(a):
            # walk each person's ancestor chain over assigned parents; a repeat
            # (or returning to start) is a cycle. Unassigned parent => chain ends.
            for start in range(n_people):
                seen = set()
                cur = start
                while True:
                    par = a.get((cur, "parent"), None)
                    if par is None or par == NONE:
                        break
                    if par in seen or par == start:
                        return False
                    seen.add(par)
                    cur = par
            return True

        constraints.append((parent_vars, acyclic_pred, True))

    if "distinct_years" in active_globals:
        year_vars = frozenset((p, "birth_year") for p in range(n_people))

        def distinct_pred(a):
            vals = [a[v] for v in year_vars if v in a]
            return len(vals) == len(set(vals))

        constraints.append((year_vars, distinct_pred, True))

    if "trait_cardinality" in active_globals:
        trait_vars = frozenset((p, "trait") for p in range(n_people))

        def cardinality_pred(a, K=trait_cardinality):
            assigned = [a[v] for v in trait_vars if v in a]
            count0 = sum(1 for t in assigned if t == 0)
            unassigned = sum(1 for v in trait_vars if v not in a)
            # never-wrong forward check: violated only if already too many,
            # or impossible to ever reach K even if all remaining pick trait 0.
            if count0 > K:
                return False
            if count0 + unassigned < K:
                return False
            return True

        constraints.append((trait_vars, cardinality_pred, True))

    return Domain(
        n_people=n_people,
        year_lo=year_lo,
        year_hi=year_hi,
        traits=traits,
        variables=variables,
        value_domains=value_domains,
        constraints=constraints,
    )


# --------------------------------------------------------------------------
# G: deterministic CSP solver with dynamic backtracking
# --------------------------------------------------------------------------

@dataclass
class Stats:
    constraint_checks: int = 0
    backjumps: int = 0  # dynamic-backtracking culprit revisions
    queries: int = 0
    budget_exceeded: int = 0  # queries that hit the per-query step ceiling


@dataclass
class GState:
    """The mutable solver state that persists across queries (the constraint set
    grows monotonically: `committed` variables are answered observations that
    bind forever; `assignment` also holds solver-internal tentative bindings for
    not-yet-queried variables, which G is free to revise to stay consistent)."""
    domain: Domain
    assignment: dict[tuple[int, str], int] = field(default_factory=dict)
    committed: set[tuple[int, str]] = field(default_factory=set)
    # eliminations[var] = list of (value, culprit_frozenset_of_vars)
    # the dynamic-backtracking "eliminating explanations": value ruled out for
    # var because of the assignments to the culprit vars.
    eliminations: dict[tuple[int, str], list] = field(default_factory=dict)
    # var -> set of constraints whose scope includes var (precomputed index)
    constraints_of: dict = field(default_factory=dict)

    def __post_init__(self):
        self.constraints_of = {v: [] for v in self.domain.variables}
        for c in self.domain.constraints:
            scope = c[0]
            for v in scope:
                self.constraints_of[v].append(c)


def _violations(state: GState, var, value, stats: Stats):
    """Check constraints touching `var` under the hypothesis assignment[var]=value.

    Returns the set of OTHER currently-assigned variables that participate in a
    violated constraint (the conflict's culprit candidates), or None if no
    constraint is violated. This is the eliminating-explanation source for
    dynamic backtracking.
    """
    a = state.assignment
    a[var] = value
    culprits: set = set()
    violated = False
    try:
        for scope, pred, _is_global in state.constraints_of[var]:
            stats.constraint_checks += 1
            if not pred(a):
                violated = True
                # culprits = the assigned vars in this constraint's scope, minus var
                for u in scope:
                    if u != var and u in a:
                        culprits.add(u)
    finally:
        del a[var]
    return culprits if violated else None


def _candidate_values(state: GState, var, rng: random.Random):
    """Deterministic value order for `var`: the domain shuffled by a seeded RNG
    keyed to the variable, so the draw discipline is fixed and order-stable but
    not trivially monotone. Values currently eliminated (by live culprits) are
    filtered at use-time, not here."""
    vals = list(state.domain.value_domains[var])
    # key the shuffle to the variable so it is stable regardless of when var is
    # first touched (purity / order-independence of the draw discipline).
    local = random.Random(f"{rng_seed_of(rng)}:{var[0]}:{var[1]}")
    local.shuffle(vals)
    return vals


def rng_seed_of(rng: random.Random):
    # capture a stable scalar identity for the run's master rng
    return rng._gtoy_seed  # set in solve()


def _live_eliminations(state: GState, var):
    """Values currently ruled out for var: an elimination is live only while ALL
    its culprit vars still hold the assignment that produced it. Dynamic
    backtracking drops eliminations whose culprit has since changed."""
    out = {}
    for value, culprit in state.eliminations.get(var, []):
        # culprit is frozenset of (var, value) pairs that justified the removal
        if all(state.assignment.get(cv) == cval for cv, cval in culprit):
            out[value] = culprit
    return out


def assign_with_dbt(state: GState, target, rng: random.Random, stats: Stats,
                    max_steps: int = 20000):
    """Find a consistent value for `target` (and for any internal variables that
    must be (re)assigned to keep consistency), using DYNAMIC BACKTRACKING.

    Returns the value chosen for `target`; None if no consistent completion
    exists (correct unsat); or the BUDGET sentinel if the per-query step budget
    (`max_steps`) was hit first -- a measured corner that exceeded bounded cost,
    reported, never fabricated. Committed variables are NEVER revised; only
    tentative (non-committed) internal assignments can be moved -- that is the
    "keep unrelated committed work" property at the granularity this toy
    commits.

    Algorithm (Ginsberg-style):
      - maintain partial assignment + per-variable eliminating explanations.
      - to extend to a variable, pick the first value not currently eliminated
        and not in conflict; record the conflict's culprits as an elimination
        explanation if all values fail.
      - on a fully-eliminated variable, BACKJUMP: pool the culprits of all its
        eliminations; the most recent (in current decision order) NON-COMMITTED
        culprit is revised -- its current value is eliminated (explained by the
        rest of the pooled culprits) and search resumes from there, keeping every
        unrelated assignment intact. If the only culprits are committed vars (or
        there are none), the problem is genuinely unsat.
    """
    # the working frontier: target plus any currently-unassigned variables.
    # We solve by extending an order; committed vars are fixed context.
    #
    # WARM INCREMENTAL STATE (the point of the lever): tentative (non-committed)
    # assignments from earlier queries are KEPT, so a query that touches only
    # local constraints repairs a tiny neighborhood instead of re-solving the
    # world. The decision_stack tracks only the vars THIS call (re)assigns, so
    # "most recent culprit" is well-defined for them. A culprit may, however, be
    # a prior-query tentative var not on this stack; that case is handled at the
    # backjump site (treated as older than anything on the current stack).
    a = state.assignment
    free_order = [target] + [v for v in state.domain.variables
                             if v not in a and v != target]
    # decision stack of variables we have tentatively assigned in THIS call,
    # in order, so "most recent culprit" is well-defined.
    decision_stack: list = []
    idx = 0
    steps = 0

    def eliminate(var, value, culprit_pairs):
        state.eliminations.setdefault(var, []).append((value, frozenset(culprit_pairs)))

    while idx < len(free_order):
        steps += 1
        if steps > max_steps:
            return BUDGET  # bounded-cost ceiling hit: report, do not fabricate
        var = free_order[idx]
        live_elim = _live_eliminations(state, var)
        chosen = None
        for value in _candidate_values(state, var, rng):
            if value in live_elim:
                continue
            culprits = _violations(state, var, value, stats)
            if culprits is None:
                chosen = value
                break
            # record a fresh elimination explained by the conflicting assigned vars
            eliminate(var, value, [(c, a[c]) for c in culprits])
        if chosen is not None:
            a[var] = chosen  # bind
            decision_stack.append(var)
            idx += 1
            continue

        # ---- dead end at `var`: BACKJUMP (dynamic backtracking) ----
        stats.backjumps += 1
        # pool culprits from all live eliminations of var
        pooled: set = set()
        for value, culprit in _live_eliminations(state, var).items():
            pooled |= set(culprit)
        # the culprit vars (drop the values), excluding committed (immovable).
        # A movable culprit is either decided in THIS call (on decision_stack) or
        # a prior-query tentative var (an "orphan", not on this stack). Orphans
        # are treated as older than anything decided this call (position -1), so
        # the most-recent culprit is chosen consistently across both kinds.
        order_pos = {v: i for i, v in enumerate(decision_stack)}
        movable = [cv for cv, _cval in pooled if cv not in state.committed]
        if not movable:
            # every cause is committed (or none) -> no consistent completion.
            return None
        # choose the most recent movable culprit; orphans (pos -1) rank oldest.
        culprit_var = max(movable, key=lambda v: order_pos.get(v, -1))
        # eliminate culprit_var's current value, explained by the rest of pooled
        rest = [(cv, cval) for cv, cval in pooled if cv != culprit_var]
        eliminate(culprit_var, a[culprit_var], rest)
        # unassign culprit_var and everything decided after it; rewind frontier.
        if culprit_var in order_pos:
            # on this call's stack: rewind it and all later decisions.
            cut = order_pos[culprit_var]
            for v in decision_stack[cut:]:
                del a[v]
            decision_stack = decision_stack[:cut]
        else:
            # orphan prior-tentative culprit: unassign only it; nothing on this
            # call's stack was decided after it, so the stack is untouched.
            del a[culprit_var]
        # rebuild free_order from current decision stack: decided prefix, then
        # the remaining (unassigned) vars with target kept first if still free.
        remaining = [v for v in state.domain.variables if v not in a]
        # keep target reachable: ensure it is in remaining (it is, unless decided)
        free_order = decision_stack + remaining
        idx = len(decision_stack)
        # NOTE: eliminations of variables unrelated to culprit_var are retained
        # (they remain live only while their own culprits hold) -- unrelated work
        # is preserved; this is the dynamic-backtracking advantage over restart.

    return a[target]


def query(state: GState, target, rng: random.Random, stats: Stats,
          max_steps: int = 20000):
    """Answer one query: G(seed, constraints, query) for `target`.

    Returns the committed value; None for correct unsat; or the BUDGET sentinel
    if the per-query step budget was hit. On a value the target becomes COMMITTED
    (binds forever; joins the constraint set). On unsat or BUDGET nothing commits
    (a budget-exceeded query left the world unchanged on the committed record --
    only non-committed scratch may have moved)."""
    stats.queries += 1
    if target in state.committed:
        return state.assignment[target]
    val = assign_with_dbt(state, target, rng, stats, max_steps=max_steps)
    if val is None:
        return None
    if val is BUDGET:
        stats.budget_exceeded += 1
        return BUDGET
    state.committed.add(target)
    return val


# --------------------------------------------------------------------------
# Observer loop
# --------------------------------------------------------------------------

def default_year_hi(n_people: int) -> int:
    """Year domain scaled to give the `distinct_years` all-different constraint
    comfortable slack (~3x people). This deliberately keeps the domain OFF the
    pigeonhole edge so the sweep measures constraint LOCALITY, not near-
    infeasibility from a tight value domain (an early version used a fixed tight
    range and the resulting blowup was a tightness artifact, not the lever)."""
    return 3 * n_people - 1


def observer_run(seed: int, n_people: int, global_fraction: float,
                 *, year_hi: int | None = None, max_steps: int = 20000):
    """Run a full seeded observer loop over one world; return per-query trace.

    A seeded probe order over all attributes; each answered query commits (when
    it returns a value). The committed set grows monotonically. Returns
    (commit_log, trace, stats) where trace is a list of
    (committed_count_before, checks_this_query, backjumps_this_query, outcome)
    and outcome is "ok" | "unsat" | "budget".
    """
    if year_hi is None:
        year_hi = default_year_hi(n_people)
    domain = build_domain(n_people, year_hi=year_hi,
                          global_fraction=global_fraction)
    state = GState(domain=domain)
    stats = Stats()

    master = random.Random(seed)
    master._gtoy_seed = seed  # for keyed value-order shuffles

    probe_order = list(domain.variables)
    master.shuffle(probe_order)

    commit_log = []
    trace = []
    for target in probe_order:
        committed_before = len(state.committed)
        checks_before = stats.constraint_checks
        bj_before = stats.backjumps
        val = query(state, target, master, stats, max_steps=max_steps)
        commit_log.append((target, val))
        outcome = "budget" if val is BUDGET else ("unsat" if val is None else "ok")
        trace.append((
            committed_before,
            stats.constraint_checks - checks_before,
            stats.backjumps - bj_before,
            outcome,
        ))
    return commit_log, trace, stats


# --------------------------------------------------------------------------
# Determinism check
# --------------------------------------------------------------------------

def check_determinism(n_people: int, global_fraction: float, seed: int = 12345):
    """Same seed => identical commit log. Asserts in code."""
    log1, _, s1 = observer_run(seed, n_people, global_fraction)
    log2, _, s2 = observer_run(seed, n_people, global_fraction)
    assert log1 == log2, "DETERMINISM VIOLATED: commit logs differ for same seed"
    assert (s1.constraint_checks, s1.backjumps) == (s2.constraint_checks, s2.backjumps), \
        "DETERMINISM VIOLATED: stats differ for same seed"
    # different seed should (almost always) differ -> sanity that seed matters
    log3, _, _ = observer_run(seed + 1, n_people, global_fraction)
    return log1, (log1 != log3)
