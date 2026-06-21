#!/usr/bin/env python3
"""Runnable harness for the substrate-consumer probe.

Runs the §5 driving trace, the determinism/replay check, and the three §6
stress-tests; prints REAL measured numbers and a per-test PASS/FAIL/PARTIAL
verdict; and emits the canonical
    === RESULTS: N passed, M failed ===
completion line (the anti-truncation marker, matching the repo's test
convention). Exit code is nonzero iff any check failed.

Usage:  nix develop --command python3 experiments/substrate-consumer/run.py
"""

from __future__ import annotations

import sys

from trace import run_trace
from core import replay, world_digest
from stress import (
    stress1_cone_cost, stress1_verdict,
    stress2_no_popping, stress2_verdict,
    stress3_key_and_boundary, stress3_verdict,
    determinism_check,
)


def main() -> int:
    passed = 0
    failed = 0

    def record(ok: bool):
        nonlocal passed, failed
        if ok:
            passed += 1
        else:
            failed += 1

    print("=" * 72)
    print(" aeriea substrate-consumer probe -- the poison-detector")
    print("=" * 72)

    # ---- §5 driving trace -------------------------------------------------
    print("\n--- §5 DRIVING TRACE (carve -> walk away -> elapse 3y -> inspect) ---")
    rec = run_trace(b"aeriea-seed-0", verbose=False)
    w = rec["world"]
    glance = rec["glance"].answer.facts
    deep = rec["deep"].answer.facts
    print(f"  log rows after carve (incl. flaw setup): {rec['log_after_carve']}")
    print(f"  3 unobserved years cost (rows added):    0  (nothing ticks)")
    print(f"  coarse glance (budget=0): {len(glance)} fact(s)")
    for f in glance:
        print(f"      {f.rel}: {f.cols}")
    print(f"  deep inspect  (budget=4): {len(deep)} fact(s)")
    for f in deep:
        print(f"      {f.rel}: {f.cols}")
    glance_is_prefix = deep[:len(glance)] == glance
    print(f"  coarse glance is an ORDERED PREFIX of deep inspect: {glance_is_prefix}")
    # the elapse must have weathered depth from 4 via exact rational arithmetic
    depth_rows = [f for f in deep if f.rel == "glyph_depth"]
    elapse_fired = bool(depth_rows) and depth_rows[0].cols[1] != 4
    print(f"  elapse weathered depth (4 -> {depth_rows[0].cols[1] if depth_rows else '?'}"
          f", exact rational, one coordinate jump): {elapse_fired}")
    trace_ok = glance_is_prefix and elapse_fired and rec["log_after_carve"] == 2
    print(f"  TRACE: {'PASS' if trace_ok else 'FAIL'}")
    record(trace_ok)

    # ---- determinism / replay --------------------------------------------
    print("\n--- DETERMINISM / REPLAY (state = f(seed, log)) ---")
    det = determinism_check()
    print(f"  same seed+log -> bit-identical world digest: {det['same_seed_identical']}")
    print(f"  replay(log, seed) reproduces world bit-for-bit: {det['replay_bit_identical']}")
    print(f"  different seed -> different drawn content:     {det['seed_matters']}")
    det_ok = det["same_seed_identical"] and det["replay_bit_identical"] and det["seed_matters"]
    print(f"  DETERMINISM: {'PASS' if det_ok else 'FAIL'}")
    record(det_ok)

    # ---- stress #1 --------------------------------------------------------
    print("\n--- STRESS #1: cone-constrained draw bounded-cost & corner-free? ---")
    curve, sweep = stress1_cone_cost()
    print("  (A) cost-per-draw vs committed cone size:")
    print(f"      {'cone_size':>9} | {'facts_touched':>13} | {'draw Sat?':>9}")
    for cs, touched, ok in curve:
        print(f"      {cs:>9} | {touched:>13} | {str(ok):>9}")
    print("  (B) corner-rate vs local/global cone mix (g-toy sweep, N=8, 8 seeds):")
    print(f"      {'global_frac':>11} | {'mean_bj':>8} | {'max_bj':>7} | {'seeds_budget':>12}")
    for r in sweep:
        print(f"      {r['global_fraction']:>11.2f} | {r['mean_backjumps']:>8.1f} | "
              f"{r['max_backjumps']:>7} | {r['seeds_budget']:>12}")
    v1 = stress1_verdict(curve, sweep)
    print(f"  all local draws Sat (no false corner):      {v1['all_draws_sat']}")
    print(f"  cost bounded as local cone grows:           {v1['cost_bounded_local']}")
    print(f"  local-only regime corner-free:              {v1['local_corner_free']}")
    print(f"  locality lever present (globals corner):    {v1['locality_lever_present']}")
    print(f"  STRESS #1: {v1['verdict']}")
    record(v1["verdict"] == "PASS")

    # ---- stress #2 --------------------------------------------------------
    print("\n--- STRESS #2: faithful coarsening / no-popping for draw? ---")
    res2 = stress2_no_popping()
    for r in res2:
        print(f"      seed={r['seed']!r}: control_prefix={r['control_prefix_holds']} "
              f"glance={r['glance_detail']} lean={r['lean_detail']} "
              f"popped={r['popped_after_adjacent_commit']}")
    v2 = stress2_verdict(res2)
    print(f"  control prefix property holds (no cone change): "
          f"{v2['control_prefix_holds_all_seeds']}")
    print(f"  seeds where adjacent commit POPPED the draw: "
          f"{v2['n_popped_after_adjacent_commit']} / {v2['n_seeds']}")
    print(f"  STRESS #2: {v2['verdict']}")
    record(v2["verdict"] == "PASS")

    # ---- stress #3 --------------------------------------------------------
    print("\n--- STRESS #3: stable key across paths + commitment boundary ---")
    r3 = stress3_key_and_boundary()
    print(f"  key reached 3 ways (direct / via-rock / via-adjacency): {r3['keys']}")
    print(f"  key stable across access paths:              {r3['key_stable_across_paths']}")
    print(f"  generated sub-thing key: {r3['subthing_key']}")
    print(f"  sub-thing stable (same seed+cone, 2 draws):  {r3['subthing_stable']}")
    print(f"  log growth from deep inspection (draws only): {r3['log_growth_from_inspection']}")
    print(f"  rows bound by data-expressed policy:          {r3['rows_committed_by_policy']}")
    print(f"  transient glance log growth:                  {r3['transient_glance_growth']}")
    print(f"  commitment boundary livable:                  {r3['boundary_livable']}")
    v3 = stress3_verdict(r3)
    print(f"  STRESS #3: {v3['verdict']}")
    record(v3["verdict"] == "PASS")

    # ---- canonical completion line ---------------------------------------
    print()
    print("=" * 72)
    print(f"=== RESULTS: {passed} passed, {failed} failed ===")
    print("=" * 72)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
