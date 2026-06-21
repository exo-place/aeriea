#!/usr/bin/env python3
"""The three stress-tests from substrate-core-design.md §6 -- the empirical
de-poisoning. Each can PASS, FAIL, or PARTIAL; a genuine failure is the valuable
finding (poison the paper design missed).

  #1  Cone-constrained draw/elapse: bounded-cost and corner-free?
  #2  Faithful coarsening as a theorem for draw (no-popping)?
  #3  Stable key across access paths + commitment boundary livability.

Stress #1 reuses g-toy's CSP / dynamic-backtracking / corner-rate machinery
(experiments/g-toy/g_toy.py) directly: the cone-constrained draw IS a CSP over a
growing committed set, and g-toy's corner-rate-vs-locality sweep is exactly the
measurement #1 asks for. We adapt it: the 'global_fraction' knob maps to the
cone's local-vs-global constraint mix, and we additionally measure cost-per-draw
as the COMMITTED CONE grows (the §2 repair's specific bill).

Stdlib only. Deterministic; seeds are explicit.
"""

from __future__ import annotations

import os
import statistics
import sys
from fractions import Fraction

# make g-toy importable (sibling experiment, reused not rebuilt)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "g-toy"))

from core import (  # noqa: E402
    AST, Fact, Intent, World, coord, grant, root_cap, replay, world_digest,
)
from trace import build_world, G7, ROCK, PLAYER, G7_key, YEAR  # noqa: E402

# g-toy machinery -- reused verbatim for stress #1's corner-rate sweep.
from g_toy import (  # noqa: E402
    observer_run, check_determinism, default_year_hi,
)


# ===========================================================================
# Stress #1 -- cone-constrained draw/elapse: bounded-cost and corner-free?
# ===========================================================================
def stress1_cone_cost(seeds=range(1, 9)):
    """Two measurements:

    (A) cost-per-draw as the COMMITTED CONE grows. We carve the glyph, then
        commit an increasing number of adjacent flaw/exposure facts (growing the
        cone), and at each size measure the work `draw` does (cone facts touched
        + constraint evaluations). The §2 repair's central claim is that this
        stays BOUNDED when the cone is kept local. We report the curve.

    (B) corner-rate vs local-vs-global constraint mix, via g-toy's sweep (the
        cone-constrained draw is CSP-under-determinism over a growing set;
        g-toy's global_fraction knob is exactly the local/global cone mix).
    """
    # ---------- (A) cost-per-draw vs cone size ----------
    curve = []  # (cone_size, cone_facts_touched, ok)
    for cone_size in (0, 1, 2, 4, 8, 16, 32, 64):
        w, cap_view = build_world(b"s1", with_adjacent_flaw=True, exposure=3)
        root = root_cap()
        cap_w = grant(root, {"flaw", "adjacent", "exposure", "noise"},
                      {"read", "write", "draw"}, ("all",), "w")
        # grow the cone with `cone_size` extra adjacent facts (LOCAL: each is an
        # adjacent edge from g7 to a distinct flaw node -> all in g7's cone).
        for i in range(cone_size):
            w.commit(Intent("add_flaw", (("i", i),), "survey",
                            adds=(Fact("flaw", (f"f{i}", ROCK, "hairline"),),
                                  Fact("adjacent", (G7, f"f{i}")),)),
                     by=cap_w, at=coord(t=Fraction(0)))
        # measure a single draw: count cone facts touched (the cost driver).
        t1 = coord(t=3 * YEAR)
        cone = w.cone(G7_key(), t1, cap_view, radius=1)
        ans = w.draw(G7_key() + (Fraction(3),), t1, "microfracture", cap_view, radius=1)
        ok = ans.kind == "Sat"
        curve.append((cone_size, len(cone), ok))

    # ---------- (B) corner-rate sweep (g-toy reused) ----------
    sweep = []
    N = 8
    for gf in (0.0, 0.25, 0.5, 0.75, 1.0):
        bj, budget_hits, consistent = [], 0, True
        for seed in seeds:
            commit_log, trace_, stats = observer_run(seed, N, gf, max_steps=1500)
            bj.append(stats.backjumps)
            budget_hits += stats.budget_exceeded
        sweep.append({
            "global_fraction": gf,
            "mean_backjumps": statistics.mean(bj),
            "max_backjumps": max(bj),
            "seeds_budget": sum(1 for s in seeds
                                if observer_run(s, N, gf, max_steps=1500)[2].budget_exceeded > 0),
        })
    return curve, sweep


def stress1_verdict(curve, sweep):
    # (A) bounded-cost: cone facts touched should grow LINEARLY (radius-1
    # neighborhood), not super-linearly, and every draw must remain Sat (never
    # corner an answer that should exist for a purely-local cone).
    sizes = [c[0] for c in curve]
    touched = [c[1] for c in curve]
    all_sat = all(c[2] for c in curve)
    # linear-ish: touched should be ~ proportional to cone_size (+ const). Check
    # the ratio touched/size stays bounded (no blow-up).
    ratios = [touched[i] / max(1, sizes[i]) for i in range(len(curve)) if sizes[i] > 0]
    bounded = max(ratios) / min(ratios) < 4.0 if ratios else True
    # (B) corner-free under LOCAL, corners ride GLOBAL (locality lever).
    local = sweep[0]
    full = sweep[-1]
    local_corner_free = local["seeds_budget"] == 0 and local["max_backjumps"] < 50
    locality_lever = full["max_backjumps"] > 5 * max(1, local["max_backjumps"]) \
        or full["seeds_budget"] > local["seeds_budget"]
    passed = all_sat and bounded and local_corner_free
    return {
        "all_draws_sat": all_sat,
        "cost_bounded_local": bounded,
        "local_corner_free": local_corner_free,
        "locality_lever_present": locality_lever,
        "verdict": "PASS" if passed else "FAIL",
    }


# ===========================================================================
# Stress #2 -- faithful coarsening as a theorem for draw (no-popping)?
# ===========================================================================
def stress2_no_popping(seeds=(b"a", b"b", b"c", b"d", b"e")):
    """Force a COARSE glance at the glyph; then COMMIT something ADJACENT (in the
    cone); then lean in for FINE detail; assert the fine detail does NOT
    contradict the earlier coarse glance.

    This is the §6.2 tension head-on: cone-dependence (#2 repair) vs no-popping.
    If the cone changed between glance and lean-in, the draw can legitimately
    differ -- and if it does, that IS the central finding (the continuum's
    no-popping promise breaks at the moment it matters).

    We test TWO variants per seed:
      (i)  COMMIT-IN-BETWEEN that grows the cone (an adjacent flaw): does the
           fine draw still contain the coarse glance as a prefix?
      (ii) NO commit in between (pure budget increase): faithful coarsening
           should be structural here (prefix property). This is the control.
    """
    results = []
    for seed in seeds:
        # ---------- control: no cone change, just deepen budget ----------
        w, cap = build_world(seed, with_adjacent_flaw=True, exposure=3)
        t1 = coord(t=3 * YEAR)
        coarse = w.materialize(G7_key(), t1, budget=0, under=cap).answer.facts
        fine = w.materialize(G7_key(), t1, budget=4, under=cap).answer.facts
        # drop the memo cache and re-derive to prove purity didn't hide a pop
        w._memo.clear()
        fine2 = w.materialize(G7_key(), t1, budget=4, under=cap).answer.facts
        control_prefix = fine[:len(coarse)] == coarse and fine == fine2

        # ---------- variant: COMMIT ADJACENT between glance and lean-in -------
        w2, cap2 = build_world(seed, with_adjacent_flaw=True, exposure=3)
        # glance: a coarse look that DRAWS microdetail at a shallow radius.
        glance = w2.materialize(G7_key(), t1, budget=2, under=cap2).answer.facts
        glance_detail = _detail_of(glance)
        # commit something ADJACENT in the cone (a NEW flaw) -> cone grows.
        capw = grant(root_cap(), {"flaw", "adjacent"},
                     {"read", "write", "draw"}, ("all",), "w")
        w2.commit(Intent("new_flaw", (("k", "post-glance"),), "survey",
                         adds=(Fact("flaw", ("flaw2", ROCK, "fresh"),),
                               Fact("adjacent", (G7, "flaw2")),)),
                  by=capw, at=coord(t=Fraction(0)))
        # lean in: fine detail under the GROWN cone.
        lean = w2.materialize(G7_key(), t1, budget=4, under=cap2).answer.facts
        lean_detail = _detail_of(lean)
        # did the microdetail the glance reported survive into the lean-in?
        popped = (glance_detail is not None and lean_detail is not None
                  and not _detail_consistent(glance_detail, lean_detail))
        results.append({
            "seed": seed,
            "control_prefix_holds": control_prefix,
            "glance_detail": glance_detail,
            "lean_detail": lean_detail,
            "popped_after_adjacent_commit": popped,
        })
    return results


def _detail_of(facts):
    for f in facts:
        if f.rel == "glyph_microdetail":
            return dict(f.cols[2])
    return None


def _detail_consistent(coarse_d, fine_d):
    """No-popping for draw: the coarse glance's already-revealed microdetail must
    not be CONTRADICTED by the fine look. We treat the glance as load-bearing:
    every key it revealed must hold the same value in the fine look. (Adding NEW
    keys is fine -- that is deepening, not popping; CHANGING a revealed value is
    a pop.)"""
    for k, v in coarse_d.items():
        if k in fine_d and fine_d[k] != v:
            return False
    return True


def stress2_verdict(results):
    control_ok = all(r["control_prefix_holds"] for r in results)
    pops = [r for r in results if r["popped_after_adjacent_commit"]]
    if control_ok and not pops:
        verdict = "PASS"
    elif control_ok and pops:
        verdict = "FAIL"   # the central finding: cone-growth pops the draw
    else:
        verdict = "FAIL"   # even the control prefix property broke
    return {
        "control_prefix_holds_all_seeds": control_ok,
        "n_seeds": len(results),
        "n_popped_after_adjacent_commit": len(pops),
        "verdict": verdict,
    }


# ===========================================================================
# Stress #3 -- stable key across access paths + commitment boundary.
# ===========================================================================
def stress3_key_and_boundary():
    """(a) Reach the glyph >=2 different ways and assert key-equality; probe a
       GENERATED sub-thing that has no obvious canonical descriptor.
    (b) Run a deep inspection and measure event-log growth.
    (c) Test a DATA-EXPRESSED commitment policy that binds load-bearing detail
       without binding transient glances; is the boundary livable?
    """
    w, cap = build_world(b"s3", with_adjacent_flaw=True, exposure=3)
    t1 = coord(t=3 * YEAR)

    # ---------- (a) stable key across access paths ----------
    # path 1: direct scan by key.
    p1 = w.query(AST("scan", ("glyph", G7, t1)), cap, budget=1)
    key1 = p1.facts[0].cols[0] if p1.facts else None
    # path 2: reach via the rock -> region query (scan all glyphs, filter by rock).
    all_glyphs = w.facts_as_of(t1, cap, "glyph")
    via_rock = [f for f in all_glyphs if f.cols[1] == ROCK]
    key2 = via_rock[0].cols[0] if via_rock else None
    # path 3: reach via the adjacency edge (flaw1 -> its adjacent glyph).
    adj = [f for f in w.facts_as_of(t1, cap, "adjacent") if f.cols[1] == "flaw1"]
    key3 = adj[0].cols[0] if adj else None
    key_stable = key1 == key2 == key3 == G7

    # probe a GENERATED sub-thing with no obvious canonical descriptor: the
    # microdetail drawn at t1. Its key must be stable across two draws (same
    # seed+cone) AND across two access paths (direct vs via materialize).
    d_direct = w.draw(G7_key() + (Fraction(3),), t1, "microfracture", cap, radius=1)
    d_again = w.draw(G7_key() + (Fraction(3),), t1, "microfracture", cap, radius=1)
    subthing_stable = (d_direct.facts == d_again.facts)
    # the sub-thing's canonical key = (rel, owner-key, coord) -- derived, stable.
    subthing_key = (d_direct.facts[0].rel,) + d_direct.facts[0].cols[:2] \
        if d_direct.facts else None

    # ---------- (b) deep inspection -> event-log growth ----------
    log_before = len(w.log)
    # a deep inspection that DRAWS but does not commit (commit-on-observation is
    # a separate, explicit step). materialize returns droppable memos, not log.
    _ = w.materialize(G7_key(), t1, budget=6, under=cap)
    log_after_inspect = len(w.log)
    growth_from_inspection = log_after_inspect - log_before  # should be 0

    # ---------- (c) data-expressed commitment policy ----------
    # the policy is a Value (data), swappable: a list of relations that are
    # LOAD-BEARING (bind on observation) vs TRANSIENT (never bind). We apply it
    # to the deep inspection's drawn facts and commit only the load-bearing ones.
    policy = {
        "bind": frozenset({"glyph_depth", "glyph_microdetail"}),  # load-bearing
        "transient": frozenset({"scan_marker"}),                  # never bind
    }
    deep = w.materialize(G7_key(), t1, budget=6, under=cap).answer.facts
    capw = grant(root_cap(),
                 {"glyph_depth", "glyph_microdetail"},
                 {"read", "write", "draw"}, ("all",), "commit")
    committed = 0
    for f in deep:
        if f.rel in policy["bind"]:
            w.commit(Intent("observe", (("rel", f.rel),), "inspection",
                            adds=(f,)), by=capw, at=t1)
            committed += 1
    log_after_policy = len(w.log)
    # a transient glance afterwards must add ZERO rows.
    log_before_glance = len(w.log)
    _ = w.materialize(G7_key(), t1, budget=0, under=cap)  # transient glance
    glance_growth = len(w.log) - log_before_glance

    # boundary livable iff: inspection alone added 0 rows; the policy bound only
    # load-bearing rows (a bounded, small number); transient glances add 0.
    boundary_livable = (growth_from_inspection == 0
                        and committed == len(policy["bind"])  # one per bound rel
                        and glance_growth == 0)

    return {
        "key_stable_across_paths": key_stable,
        "keys": (key1, key2, key3),
        "subthing_stable": subthing_stable,
        "subthing_key": subthing_key,
        "log_growth_from_inspection": growth_from_inspection,
        "rows_committed_by_policy": committed,
        "log_len_after_policy": log_after_policy,
        "transient_glance_growth": glance_growth,
        "boundary_livable": boundary_livable,
    }


def stress3_verdict(r):
    passed = (r["key_stable_across_paths"] and r["subthing_stable"]
              and r["boundary_livable"])
    return {
        "key_stable": r["key_stable_across_paths"],
        "subthing_stable": r["subthing_stable"],
        "boundary_livable": r["boundary_livable"],
        "verdict": "PASS" if passed else "FAIL",
    }


# ===========================================================================
# Determinism / replay check (the hard invariant).
# ===========================================================================
def determinism_check():
    """state = f(seed, log): same seed+log => bit-identical. Asserted here."""
    from trace import run_trace
    rec_a = run_trace(b"det-seed")
    rec_b = run_trace(b"det-seed")
    wa, wb = rec_a["world"], rec_b["world"]
    same_seed_identical = world_digest(wa) == world_digest(wb)
    # replay reconstructs bit-for-bit.
    wr = replay(wa.log, wa.seed)
    replay_identical = world_digest(wa) == world_digest(wr)
    # different seed -> (almost surely) different drawn content.
    rec_c = run_trace(b"different-seed")
    seed_matters = (rec_a["deep"].answer != rec_c["deep"].answer)
    return {
        "same_seed_identical": same_seed_identical,
        "replay_bit_identical": replay_identical,
        "seed_matters": seed_matters,
    }
