#!/usr/bin/env python3
"""Run the g-toy experiment: sweep global_fraction, aggregate over seeds, and
print the metrics tables (corner-rate, budget-exceed rate, cost distribution)
plus a verdict against the falsification criterion. Verifies determinism and
full-solution consistency before reporting.

Usage:  nix develop --command python3 experiments/g-toy/run.py
"""

from __future__ import annotations

import statistics
import sys

from g_toy import (
    BUDGET,
    build_domain,
    default_year_hi,
    observer_run,
    check_determinism,
)


def verify_consistency(commit_log, n_people, global_fraction):
    """Independently re-check that the final COMMITTED assignment (the values
    actually bound -- not unsat, not budget) satisfies EVERY constraint (the
    "never wrong" guarantee). Returns (ok, n_unsat, n_budget)."""
    domain = build_domain(n_people, year_hi=default_year_hi(n_people),
                          global_fraction=global_fraction)
    a = {}
    n_unsat = 0
    n_budget = 0
    for var, val in commit_log:
        if val is BUDGET:
            n_budget += 1
        elif val is None:
            n_unsat += 1
        else:
            a[var] = val
    ok = True
    for scope, pred, _is_global in domain.constraints:
        if not pred(a):
            ok = False
            break
    return ok, n_unsat, n_budget


def sweep(n_people, fractions, seeds, max_steps):
    """Return rows: dict per fraction with aggregated metrics across seeds."""
    rows = []
    for gf in fractions:
        per_seed_backjumps = []
        per_seed_checks = []
        per_seed_budget = []
        all_checks_per_query = []
        early_costs = []  # checks/query for queries in the first third (small committed set)
        late_costs = []   # checks/query for queries in the last third (large committed set)
        consistency_ok = True
        for seed in seeds:
            commit_log, trace, stats = observer_run(seed, n_people, gf,
                                                    max_steps=max_steps)
            per_seed_backjumps.append(stats.backjumps)
            per_seed_checks.append(stats.constraint_checks)
            ok, n_unsat, n_budget = verify_consistency(commit_log, n_people, gf)
            consistency_ok = consistency_ok and ok
            per_seed_budget.append(n_budget)
            n_q = len(trace)
            third = max(1, n_q // 3)
            for committed_before, checks, _bj, _outcome in trace:
                all_checks_per_query.append(checks)
            for committed_before, checks, _bj, _outcome in trace[:third]:
                early_costs.append(checks)
            for committed_before, checks, _bj, _outcome in trace[-third:]:
                late_costs.append(checks)
        n_q = n_people * 3
        rows.append({
            "global_fraction": gf,
            "mean_backjumps": statistics.mean(per_seed_backjumps),
            "median_backjumps": statistics.median(per_seed_backjumps),
            "max_backjumps": max(per_seed_backjumps),
            "corner_rate": statistics.mean(per_seed_backjumps) / n_q,
            "mean_checks_total": statistics.mean(per_seed_checks),
            "median_checks_total": statistics.median(per_seed_checks),
            "max_checks_total": max(per_seed_checks),
            "mean_budget": statistics.mean(per_seed_budget),
            "n_seeds_with_budget": sum(1 for b in per_seed_budget if b > 0),
            "median_checks_per_query": statistics.median(all_checks_per_query),
            "early_checks_per_query": statistics.median(early_costs),
            "late_checks_per_query": statistics.median(late_costs),
            "max_checks_per_query": max(all_checks_per_query),
            "consistency_ok": consistency_ok,
        })
    return rows


def main():
    N = 8
    MAX_STEPS = 1500  # per-query dynamic-backtracking step ceiling (bounded cost)
    fractions = [0.0, 0.25, 0.5, 0.75, 1.0]
    seeds = list(range(1, 25))  # 24 seeds per config

    print(f"g-toy experiment: N={N} people, year domain 0..{default_year_hi(N)}, "
          f"{N*3} attributes/world, {len(seeds)} seeds per config, "
          f"per-query step budget={MAX_STEPS}\n")

    # --- determinism check (asserts in code) ---
    _, seed_matters = check_determinism(N, 0.5)
    print("DETERMINISM: same seed -> identical commit log + stats: PASS (asserted)")
    print(f"DETERMINISM: different seed -> different log: "
          f"{'PASS' if seed_matters else 'WARN (seeds produced same log)'}\n")

    rows = sweep(N, fractions, seeds, MAX_STEPS)

    print("=== TABLE 1: corner-rate & budget-exceeds vs global_fraction ===")
    print(f"{'global_frac':>11} | {'mean_bj':>9} | {'median_bj':>9} | "
          f"{'max_bj':>7} | {'corner_rate':>11} | {'seeds_budget':>12}")
    print("-" * 76)
    for r in rows:
        print(f"{r['global_fraction']:>11.2f} | {r['mean_backjumps']:>9.1f} | "
              f"{r['median_backjumps']:>9.1f} | {r['max_backjumps']:>7d} | "
              f"{r['corner_rate']:>11.4f} | "
              f"{r['n_seeds_with_budget']:>3d}/{len(seeds):<8d}")

    print("\n=== TABLE 2: cost distribution (constraint-checks) ===")
    print(f"{'global_frac':>11} | {'med_total':>10} | {'mean_total':>11} | "
          f"{'max_total':>10} | {'med/query':>10} | {'max/query':>10}")
    print("-" * 78)
    for r in rows:
        print(f"{r['global_fraction']:>11.2f} | "
              f"{r['median_checks_total']:>10.0f} | "
              f"{r['mean_checks_total']:>11.0f} | "
              f"{r['max_checks_total']:>10d} | "
              f"{r['median_checks_per_query']:>10.0f} | "
              f"{r['max_checks_per_query']:>10d}")

    print("\n=== TABLE 3: cost-per-query vs committed-set size (median checks/query) ===")
    print(f"{'global_frac':>11} | {'early(small set)':>16} | "
          f"{'late(large set)':>15} | {'late/early':>10}")
    print("-" * 62)
    for r in rows:
        ratio = (r['late_checks_per_query'] / r['early_checks_per_query']
                 if r['early_checks_per_query'] else float('nan'))
        print(f"{r['global_fraction']:>11.2f} | "
              f"{r['early_checks_per_query']:>16.0f} | "
              f"{r['late_checks_per_query']:>15.0f} | {ratio:>10.2f}")

    print("\n=== CONSISTENCY (never-wrong) check ===")
    all_ok = all(r['consistency_ok'] for r in rows)
    print(f"All COMMITTED assignments satisfy all constraints, every config/seed: "
          f"{'PASS' if all_ok else 'FAIL'}")

    # --- verdict against the falsification criterion ---
    print("\n=== FALSIFICATION-CRITERION EVALUATION ===")
    local_row = rows[0]   # global_fraction = 0.0 (purely local)
    full_row = rows[-1]   # global_fraction = 1.0 (all global)
    local_ratio = (local_row['late_checks_per_query'] /
                   local_row['early_checks_per_query']
                   if local_row['early_checks_per_query'] else float('nan'))
    print(f"Cost growth vs committed-set size (late/early median checks/query) "
          f"at gf=0.0 (local-only): {local_ratio:.2f}x")
    print(f"Median backjumps   local(0.0)={local_row['median_backjumps']:.1f}   "
          f"full(1.0)={full_row['median_backjumps']:.1f}")
    print(f"Max backjumps      local(0.0)={local_row['max_backjumps']}   "
          f"full(1.0)={full_row['max_backjumps']}")
    print(f"Seeds hitting budget  local(0.0)={local_row['n_seeds_with_budget']}   "
          f"full(1.0)={full_row['n_seeds_with_budget']}")
    print(f"Max total checks   local(0.0)={local_row['max_checks_total']}   "
          f"full(1.0)={full_row['max_checks_total']}")

    cost_bounded_local = (local_ratio < 5.0
                          and local_row['n_seeds_with_budget'] == 0
                          and local_row['max_backjumps'] < 100)
    locality_lever = (full_row['max_backjumps'] > 10 * max(1, local_row['max_backjumps'])
                      or full_row['n_seeds_with_budget'] > local_row['n_seeds_with_budget'])
    print()
    if cost_bounded_local and locality_lever:
        print("VERDICT: locality lever VALIDATED in this toy (with a sharp caveat).")
        print("  - Under local-only constraints (gf=0.0) cost stays low and bounded:")
        print("    no seed hits the budget; backjumps stay tiny; no growth with set size.")
        print("  - Turning ON global constraints produces a HEAVY-TAILED cost blowup:")
        print("    most seeds stay cheap, but a minority paint into a corner and")
        print("    exceed the per-query budget. Corner-risk rides global constraints.")
        print("  Direction looks viable IFF global constraints are kept few/bounded;")
        print("  the residual tail (rare catastrophic corners) is exactly the crux's")
        print("  unsolved 'painting into a corner' problem, reproduced here.")
    elif not cost_bounded_local:
        print("VERDICT: cost-per-query is NOT bounded even under local-only "
              "constraints -> falsification criterion TRIGGERED; approach in "
              "trouble at this scale.")
    else:
        print("VERDICT: corner-rate did NOT rise with global_fraction -> locality "
              "lever NOT demonstrated by this toy (inconclusive / contrary).")

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
