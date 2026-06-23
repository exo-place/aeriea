#!/usr/bin/env bash
# Canonical test runner for aeriea.
#
# Runs every test suite under xvfb at a generous frame-count budget (each suite
# exits itself via get_tree().quit(); the budget is a safety ceiling only).
# For each suite it:
#   - captures stdout
#   - parses the "RESULTS: N passed, M failed" completion line
#   - treats a MISSING results line as TRUNCATED (the anti-truncation guard — a
#     suite that never printed its completion line did not finish, so it must NOT
#     count as passing)
# Prints a per-suite summary, then an aggregate total.
# Exits 0 iff every suite completed and all tests passed.
# Exits nonzero if any suite has failures, is missing, or was truncated.
#
# Usage:
#   nix run .#test                               # canonical
#   nix develop --command bash tests/run.sh     # inside the dev shell
#   bash tests/run.sh                            # if godot4 + xvfb-run are in PATH
#
# To add a new test suite: add its .tscn name to SUITES below.

set -euo pipefail

# Resolve project root. If AERIEA_ROOT is set (set by the nix run .#test wrapper),
# use that; otherwise resolve relative to this script's directory.
if [ -n "${AERIEA_ROOT:-}" ]; then
  cd "$AERIEA_ROOT"
else
  cd "$(dirname "$0")/.."   # run from project root (Godot --path . requires it)
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Frame-count safety ceiling. Each suite calls get_tree().quit() itself; this
# ceiling only fires if a suite hangs or crashes without quitting.
# ~60000 frames at 60 fps = ~1000 s — comfortably above any real suite.
BUDGET=60000

# All test scene basenames (without the .tscn extension).
SUITES=(
  movement_behavior_test
  golden_trace_test
  interaction_behavior_test
  interaction_golden_trace_test
  text_slice_test
  maren_history_test
  face_expression_test
  gaze_test
  sim_clock_test
  memory_test
  relationship_mood_test
  body_asset_test
  body_gate_test
  body_modifier_registry_test
  body_detail_library_test
  body_region_sliders_test
  body_caps_test
  body_proxy_test
  body_locomotion_test
  body_motion_matching_test
  body_clip_layer_test
  body_arm_ik_test
  body_micro_life_test
  interpreter_slice1_test
  legend_projection_test
  creator_history_test
  creator_glow_test
  creator_phase3a_test
  creator_phase3b_test
  creator_phase5a_test
  creator_persistence_test
  morph_drag_test
  picker_test
  gpu_id_picker_test
  launcher_test
)

# ---------------------------------------------------------------------------
# Per-suite runner
# ---------------------------------------------------------------------------

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_TRUNCATED=0
ALL_OK=true

declare -A SUITE_PASS
declare -A SUITE_FAIL
declare -A SUITE_STATUS

for suite in "${SUITES[@]}"; do
  scene="res://tests/${suite}.tscn"
  echo ""
  echo "--- ${suite} ---"

  # Run the suite; capture stdout+stderr together. The exit code from Godot
  # matches quit(0)/quit(1), but we rely on the RESULTS line, not the exit code,
  # so that truncation (e.g. timeout before quit()) is detected regardless.
  output="$(xvfb-run -a godot4 --path . "${scene}" --quit-after "${BUDGET}" 2>&1)" || true
  echo "$output"

  # Parse the canonical "=== RESULTS: N passed, M failed ===" line.
  results_line="$(echo "$output" | grep -E '=== RESULTS: [0-9]+ passed, [0-9]+ failed ===' | tail -1 || true)"

  if [ -z "$results_line" ]; then
    # No completion marker: the suite never printed its RESULTS line — truncated
    # or crashed. This is the anti-truncation guard: DO NOT treat this as passing.
    echo "  !! TRUNCATED / NO-COMPLETION: ${suite} (no RESULTS line found)"
    SUITE_STATUS[$suite]="TRUNCATED"
    SUITE_PASS[$suite]=0
    SUITE_FAIL[$suite]=0
    TOTAL_TRUNCATED=$(( TOTAL_TRUNCATED + 1 ))
    ALL_OK=false
  else
    # Extract pass and fail counts.
    passed="$(echo "$results_line" | grep -oP '\d+ passed' | grep -oP '\d+' || echo 0)"
    failed="$(echo "$results_line" | grep -oP '\d+ failed' | grep -oP '\d+' || echo 0)"
    SUITE_PASS[$suite]=$passed
    SUITE_FAIL[$suite]=$failed
    TOTAL_PASS=$(( TOTAL_PASS + passed ))
    TOTAL_FAIL=$(( TOTAL_FAIL + failed ))
    if [ "$failed" -eq 0 ]; then
      SUITE_STATUS[$suite]="OK"
    else
      SUITE_STATUS[$suite]="FAIL"
      ALL_OK=false
    fi
  fi
done

# ---------------------------------------------------------------------------
# Aggregate report
# ---------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo " aeriea test suite aggregate"
echo "======================================================================"
printf "  %-45s  %8s  %8s  %s\n" "SUITE" "PASSED" "FAILED" "STATUS"
echo "  -----------------------------------------------------------------------"
for suite in "${SUITES[@]}"; do
  status="${SUITE_STATUS[$suite]}"
  passed="${SUITE_PASS[$suite]:-0}"
  failed="${SUITE_FAIL[$suite]:-0}"
  if [ "$status" = "TRUNCATED" ]; then
    printf "  %-45s  %8s  %8s  %s\n" "$suite" "?" "?" "TRUNCATED/NO-COMPLETION"
  elif [ "$status" = "FAIL" ]; then
    printf "  %-45s  %8d  %8d  FAIL\n" "$suite" "$passed" "$failed"
  else
    printf "  %-45s  %8d  %8d  ok\n" "$suite" "$passed" "$failed"
  fi
done
echo "  -----------------------------------------------------------------------"
printf "  %-45s  %8d  %8d  %s\n" "TOTAL" "$TOTAL_PASS" "$TOTAL_FAIL" "($TOTAL_TRUNCATED truncated)"
echo "======================================================================"

if $ALL_OK; then
  echo " ALL SUITES PASSED"
  echo "======================================================================"
  exit 0
else
  echo " FAILURE: one or more suites FAILED or were TRUNCATED"
  echo "======================================================================"
  exit 1
fi
