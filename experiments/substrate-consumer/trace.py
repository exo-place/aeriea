#!/usr/bin/env python3
"""The driving trace: the §5 hard case, implemented for real.

  A player carves a glyph into a rock (commit), walks away, returns 3 in-game
  years later (elapse -- ONE coordinate jump, no per-tick), and inspects it
  closely (materialize/draw weathering detail, cone-constrained by the rock's
  adjacent committed flaws), with ZERO facade.

This builds the world the three stress-tests reuse. It exercises every core
primitive end-to-end and is the determinism/replay subject.
"""

from __future__ import annotations

from fractions import Fraction

from core import (
    AST, Cap, Fact, Intent, World,
    coord, grant, root_cap, replay, world_digest,
)

YEAR = Fraction(1)            # 1 in-game year = coordinate unit t
G7 = "g7"
ROCK = "rock42"
PLAYER = "P"


def build_world(seed: bytes = b"aeriea-seed-0",
                with_adjacent_flaw: bool = True,
                exposure: int = 3) -> tuple[World, Cap]:
    """Carve the glyph and set up the committed cone. Returns (world, view_cap).

    The cone the later draw is constrained by:
      - the carve fact (glyph)            -- the base, immutable
      - material / exposure facts          -- bound lichen ceiling
      - an ADJACENT rock-flaw fact         -- the crack propagates FROM it
      - an 'adjacent' spatial edge          -- makes the flaw a neighbor of g7
    """
    w = World(seed)
    root = root_cap()
    # capability for the carving tool: write/read/draw on the glyph relations,
    # attenuated to the owner. (grant() narrows; nothing forges authority.)
    cap_g = grant(root,
                  {"glyph", "glyph_depth", "glyph_microdetail",
                   "adjacent", "flaw", "exposure", "material",
                   "weathering_history_exists"},
                  {"read", "write", "draw"},
                  ("all",), "tool")

    t0 = coord(t=Fraction(0))

    # (a) the carve -- ONE commit. Effect + existence-of-cause (entails).
    w.commit(
        Intent(
            verb="carve",
            payload=(("shape", "spiral"), ("depth_mm", Fraction(4))),
            evidence="tool_contact",
            adds=(
                Fact("glyph", (G7, ROCK, PLAYER, "spiral")),
                # depth KNOWN only at the carve instant [t0, t0]; any later
                # coordinate must be derived by elapse (no facade, nothing stored
                # for the unobserved future).
                Fact("glyph_depth", (G7, Fraction(4), Fraction(0), Fraction(0))),
                Fact("material", (G7, "sandstone")),
                Fact("exposure", (G7, Fraction(exposure))),
            ),
            entails=(
                # existence-of-cause, NOT a guessed future: a consistent
                # weathering history exists.
                Fact("weathering_history_exists", (G7,)),
            ),
        ),
        by=cap_g, at=t0,
    )

    # the adjacent committed flaw + the spatial edge that makes it g7's neighbor.
    if with_adjacent_flaw:
        w.commit(
            Intent(
                verb="note_flaw",
                payload=(("kind", "microfracture_seed"),),
                evidence="survey",
                adds=(
                    Fact("flaw", ("flaw1", ROCK, "hairline_seed")),
                    Fact("adjacent", (G7, "flaw1")),
                ),
            ),
            by=cap_g, at=t0,
        )

    # a read+draw view capability the inspection uses.
    cap_view = grant(root,
                     {"glyph", "glyph_depth", "glyph_microdetail",
                      "adjacent", "flaw", "exposure", "material"},
                     {"read", "draw"}, ("all",), "view")
    return w, cap_view


def run_trace(seed: bytes = b"aeriea-seed-0", verbose: bool = False):
    """Run the full §5 hard case and return a structured record of each step's
    Answer, for assertion by the harness."""
    w, cap_view = build_world(seed)

    # (b) walk away -- nothing ticks. The log does not grow.
    log_after_carve = len(w.log)

    # (c) the 3-year jump -- one coordinate. Coarse glance first.
    t1 = coord(t=3 * YEAR)
    glance = w.materialize(G7_key(), t1, budget=0, under=cap_view)

    # (d) close inspection -- cone-constrained weathered detail, zero facade.
    deep = w.materialize(G7_key(), t1, budget=4, under=cap_view)

    if verbose:
        print("carve log len:", log_after_carve)
        print("glance (budget=0):", glance.answer)
        print("deep   (budget=4):", deep.answer)

    return {
        "world": w,
        "cap_view": cap_view,
        "log_after_carve": log_after_carve,
        "glance": glance,
        "deep": deep,
        "t1": t1,
    }


def G7_key() -> tuple:
    return (G7,)


if __name__ == "__main__":
    rec = run_trace(verbose=True)
    w = rec["world"]
    # determinism / replay: rebuild from seed+log, assert bit-identical.
    w2 = replay(w.log, w.seed)
    assert world_digest(w) == world_digest(w2), "REPLAY NOT BIT-IDENTICAL"
    print("replay bit-identical:", world_digest(w).hex()[:16])
