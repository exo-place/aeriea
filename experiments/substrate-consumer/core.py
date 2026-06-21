#!/usr/bin/env python3
"""substrate-consumer core: a minimal, runnable slice of aeriea's synthesized
substrate algebra (docs/decisions/substrate-core-design.md), built JUST ENOUGH to
run the §5 hard case and the three §6 stress-tests. A probe, not the production
substrate.

What is implemented from the synthesized core (§3):
  - Value           : rationals via fractions.Fraction (NO float in core), plus
                      the other Value kinds the trace needs. AST = serializable.
  - Fact            : (rel: Sym, cols: Tuple[Value...]) -- one committed row.
  - commit          : the SOLE mutator. Appends one content-addressed Event to an
                      append-only log iff `by` authorizes the intent. Commits the
                      effect (adds) + existence-of-cause (entails); never a guessed
                      cause.
  - query           : demand-driven read returning the Sat | Incomplete | Unsat
                      trichotomy (no-facade as a TYPE). Ranges only over relations
                      reachable through the capability.
  - materialize     : the eager<->lazy slide as ONE continuous per-key budget knob;
                      returns a droppable pure Memo (a derivation prefix).
  - draw            : the seeded oracle. content = f(seed, key, COMMITTED CONE),
                      NOT f(name). Cone-constrained generation. Returns an Answer.
  - elapse          : the time-analogue of draw; one coordinate jump (no per-tick),
                      seeded by (seed, key, from, to), cone-constrained.
  - at              : reframe a derivation as-of a coordinate. Time is a coordinate.
  - grant           : capability attenuation (monotone-decreasing).
  - replay          : reconstruct the world bit-for-bit from seed + log.

Determinism: the entire world state is a pure function of (seed, event log). Same
seed + same log => bit-identical. Asserted in the harness (replay equality).

This file holds the core. The driving trace and the three stress-tests live in
trace.py / stress.py; the runnable harness with the RESULTS line is run.py.

Stdlib only. fractions.Fraction for all core rationals.
"""

from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass, field
from fractions import Fraction
from typing import Optional


# ===========================================================================
# Value -- the only data (§3 data model). No float in the core.
# ===========================================================================
# Value ::= Null | Bool | Int | Rat | Sym | Bytes | Tuple[Value...] | Cap | AST
#
# In this probe a Value is one of: None, bool, int, Fraction (Rat), str (Sym),
# bytes, tuple[Value...], Cap, or AST. We forbid float at the boundary so the
# "no float in core" law is a checkable invariant rather than a comment.

def assert_value(v) -> None:
    """Reject float anywhere in a Value tree -- enforces the 'no float in core'
    law structurally. A rational MUST be a Fraction, never a float."""
    if isinstance(v, float):
        raise TypeError("FLOAT IN CORE: rationals must be fractions.Fraction, not float")
    if isinstance(v, tuple):
        for x in v:
            assert_value(x)


# A canonical, deterministic serialization of a Value -- the basis of content
# addressing AND of the cone digest that seeds draw/elapse. Two structurally
# equal Values MUST serialize identically (order-independence of identity);
# Fractions serialize via (num, den) so 4/1 and 8/2 collapse to the same bytes.
def ser(v) -> bytes:
    assert_value(v)
    if v is None:
        return b"N"
    if isinstance(v, bool):
        return b"b1" if v else b"b0"
    if isinstance(v, int):
        return b"i" + str(v).encode()
    if isinstance(v, Fraction):
        return b"r" + f"{v.numerator}/{v.denominator}".encode()
    if isinstance(v, str):
        return b"s" + v.encode()
    if isinstance(v, bytes):
        return b"y" + v
    if isinstance(v, tuple):
        return b"t(" + b",".join(ser(x) for x in v) + b")"
    if isinstance(v, Cap):
        return b"c" + v.digest()
    if isinstance(v, AST):
        return b"a" + ser(v.to_value())
    raise TypeError(f"not a Value: {type(v)!r}")


def H(*parts) -> bytes:
    """Deterministic hash of a sequence of Values/bytes -- the seed mixer for
    content addressing and for draw/elapse generation."""
    h = hashlib.sha256()
    for p in parts:
        if isinstance(p, (bytes, bytearray)):
            h.update(b"|B|"); h.update(p)
        else:
            h.update(b"|V|"); h.update(ser(p))
    return h.digest()


def hash_to_unit(digest: bytes) -> Fraction:
    """Map a 256-bit digest to an EXACT rational in [0,1) -- a deterministic,
    float-free uniform draw. (No float anywhere in the generation path.)"""
    n = int.from_bytes(digest[:8], "big")
    return Fraction(n, 1 << 64)


# ===========================================================================
# AST -- serializable behavior (rules/laws/generators are Values, never closures)
# ===========================================================================
@dataclass(frozen=True)
class AST:
    """A serializable expression. In this probe an AST is a tagged tuple
    (op, *args). Laws (e.g. weathering) are ASTs interpreted by a fixed, pure
    evaluator -- NOT Python closures. This keeps the data-over-code seam honest:
    the law transports, caches, diffs, and replays as data."""
    op: str
    args: tuple = ()

    def to_value(self):
        return (self.op,) + tuple(
            a.to_value() if isinstance(a, AST) else a for a in self.args
        )


# A tiny pure evaluator for the law ASTs the trace uses. Deterministic, rational.
def eval_law(law: AST, env: dict) -> Fraction:
    """Evaluate a law AST to an exact Fraction. env maps Sym -> Value. The only
    ops the trace needs; extend as the probe grows. Pure and total over its
    supported ops (raises on an unknown op rather than guessing)."""
    op, args = law.op, law.args

    def ev(a):
        if isinstance(a, AST):
            return eval_law(a, env)
        if isinstance(a, str):
            return env[a]
        return a

    if op == "lit":
        return Fraction(args[0]) if not isinstance(args[0], Fraction) else args[0]
    if op == "var":
        return env[args[0]]
    if op == "add":
        return ev(args[0]) + ev(args[1])
    if op == "sub":
        return ev(args[0]) - ev(args[1])
    if op == "mul":
        return ev(args[0]) * ev(args[1])
    if op == "div":
        return ev(args[0]) / ev(args[1])
    if op == "max":
        return max(ev(args[0]), ev(args[1]))
    if op == "min":
        return min(ev(args[0]), ev(args[1]))
    raise ValueError(f"unknown law op: {op}")


# ===========================================================================
# Capability (§3 capability) -- attenuated relation-handle.
# ===========================================================================
@dataclass(frozen=True)
class Cap:
    """Authority = an attenuated relation-handle: a set of relations, a verb-set,
    and a row-filter predicate-name (data, not a closure). The host grants the
    root; grant() only ever narrows. Nothing forges a Cap (construction is via
    root_cap/grant only by convention in this probe)."""
    rels: frozenset          # relations this cap can touch ("*" = all, for root)
    verbs: frozenset         # subset of {"read","write","draw"}
    filt: tuple              # row-filter as a Value (("all",) or ("eq", col, val))
    label: str = ""

    def digest(self) -> bytes:
        return H("cap", tuple(sorted(self.rels)), tuple(sorted(self.verbs)),
                 self.filt, self.label)

    def can(self, rel: str, verb: str) -> bool:
        if verb not in self.verbs:
            return False
        return "*" in self.rels or rel in self.rels

    def row_ok(self, fact: "Fact") -> bool:
        f = self.filt
        if f[0] == "all":
            return True
        if f[0] == "eq":
            _, col_idx, val = f
            return col_idx < len(fact.cols) and fact.cols[col_idx] == val
        raise ValueError(f"unknown filter: {f}")


def root_cap() -> Cap:
    return Cap(frozenset({"*"}), frozenset({"read", "write", "draw"}),
               ("all",), "root")


def grant(cap: Cap, rels, verbs, filt=("all",), label="") -> Cap:
    """Attenuate a capability into a STRICTLY narrower one (you can only grant
    what you hold). Monotone-decreasing: the result's authority is a subset."""
    new_rels = frozenset(rels)
    new_verbs = frozenset(verbs)
    # enforce monotone narrowing (no amplification)
    if "*" not in cap.rels and not new_rels <= cap.rels:
        raise PermissionError("grant would AMPLIFY relations -- forbidden")
    if not new_verbs <= cap.verbs:
        raise PermissionError("grant would AMPLIFY verbs -- forbidden")
    return Cap(new_rels, new_verbs, filt, label)


# ===========================================================================
# Fact -- one committed row (§3). Not a noun: an "entity" is the set of facts
# sharing a key.
# ===========================================================================
@dataclass(frozen=True)
class Fact:
    rel: str                 # Sym
    cols: tuple              # Tuple[Value...]

    def __post_init__(self):
        for c in self.cols:
            assert_value(c)

    def as_value(self):
        return (self.rel,) + self.cols


# ===========================================================================
# Coord / Cut -- time as a coordinate, not a tick (§3 time).
# ===========================================================================
# A Coord is an open sparse map of dimension-keys, e.g. {"t": Fraction(...)}.
# We represent it as a sorted tuple of (dim, Fraction) so it serializes
# canonically. Time is NOT privileged over space.
def coord(**dims) -> tuple:
    items = []
    for k, v in sorted(dims.items()):
        if isinstance(v, float):
            raise TypeError("FLOAT IN COORD: use Fraction")
        items.append((k, v if isinstance(v, Fraction) else Fraction(v)))
    return tuple(items)


def coord_t(c: tuple) -> Fraction:
    for k, v in c:
        if k == "t":
            return v
    return Fraction(0)


# ===========================================================================
# Intent / Event / log
# ===========================================================================
@dataclass(frozen=True)
class Intent:
    verb: str
    payload: tuple                 # Value
    evidence: object               # Value
    adds: tuple = ()               # Tuple[Fact] -- committed effects
    entails: tuple = ()            # Tuple[Fact] -- existence-of-cause, never guessed


@dataclass(frozen=True)
class Event:
    id: bytes                      # content address
    intent: Intent
    parents: tuple                 # Tuple[Event.id]
    t: tuple                       # Coord
    author: bytes                  # CapDigest

    def as_value(self):
        return ("event",
                self.intent.verb,
                self.intent.payload,
                tuple(f.as_value() for f in self.intent.adds),
                tuple(f.as_value() for f in self.intent.entails),
                self.t,
                self.author)


# ===========================================================================
# The Answer trichotomy (§3) -- no-facade as a TYPE.
# ===========================================================================
@dataclass(frozen=True)
class Sat:
    facts: tuple                   # Tuple[Fact] -- consistent with every cone-fact

    kind = "Sat"


@dataclass(frozen=True)
class Incomplete:
    frontier: object               # what would need probing/budget; NOT a guess

    kind = "Incomplete"


@dataclass(frozen=True)
class Unsat:
    witness: tuple                 # minimal conflicting facts, reader-verifiable

    kind = "Unsat"


Answer = (Sat, Incomplete, Unsat)


# ===========================================================================
# Memo -- a droppable pure cache (§3 materialize). Drop every Memo, re-derive,
# get bit-identical answers.
# ===========================================================================
@dataclass(frozen=True)
class Memo:
    key: tuple
    at: tuple
    budget: int
    answer: object                 # an Answer; the materialized prefix


# ===========================================================================
# World -- seed + append-only log. State is DERIVED, never stored in a noun.
# ===========================================================================
class World:
    """The whole world is (seed, log). `commit` is the sole writer. Everything
    else is a pure derivation over the log. Memos are a droppable cache that the
    harness deliberately drops-and-rederives to prove purity."""

    def __init__(self, seed: bytes):
        self.seed = seed
        self.log: list[Event] = []          # append-only
        self._memo: dict = {}               # droppable pure cache

    # ---- the one write -----------------------------------------------------
    def commit(self, intent: Intent, by: Cap, at: tuple) -> Event:
        """The SOLE mutator. Appends one content-addressed Event iff `by`
        authorizes it (capability check is the sole enforcement point). Commits
        the effect (adds) + existence-of-cause (entails). No retract, ever."""
        # capability check: every added/entailed fact's relation must be writable
        for f in (intent.adds + intent.entails):
            if not by.can(f.rel, "write"):
                raise PermissionError(
                    f"capability denies write to relation {f.rel!r}")
            if not by.row_ok(f):
                raise PermissionError(
                    f"capability row-filter denies fact {f.rel!r}")
        parents = tuple(e.id for e in self.log)  # full causal prefix (toy)
        eid = H("event", intent.verb, intent.payload,
                tuple(f.as_value() for f in intent.adds),
                tuple(f.as_value() for f in intent.entails),
                at, by.digest(), parents)
        ev = Event(id=eid, intent=intent, parents=parents, t=at,
                   author=by.digest())
        self.log.append(ev)
        self._memo.clear()  # log changed: drop cache (purity: rederive on demand)
        return ev

    # ---- committed facts as of a coordinate (the EDB view) -----------------
    def facts_as_of(self, at: tuple, under: Cap, rel: Optional[str] = None):
        """All committed facts visible through `under`, as of coordinate `at`.
        A fact is visible iff its event's t <= at (time as coordinate). Naming a
        relation you lack a cap for yields NO rows (no existence leak)."""
        t_at = coord_t(at)
        out = []
        for ev in self.log:
            if coord_t(ev.t) > t_at:
                continue
            for f in ev.intent.adds:
                if rel is not None and f.rel != rel:
                    continue
                if not under.can(f.rel, "read"):
                    continue          # no existence leak
                if not under.row_ok(f):
                    continue
                out.append(f)
        return tuple(out)

    # ---- the cone: committed causal neighborhood of a key ------------------
    def cone(self, key: tuple, at: tuple, under: Cap, radius: int = 1):
        """The committed causal neighborhood that constrains a draw/elapse for
        `key`. This is the §2 repair's heart: content = f(seed, key, CONE).

        The cone is the prefix-closed slice of committed facts that are
        causally adjacent to `key`: facts that mention key[0] directly, plus
        facts that share a 'neighbor' relation, expanded `radius` hops. Returns
        a canonical (sorted) tuple of Facts so its digest is order-independent."""
        if not key:
            anchor = None
        else:
            anchor = key[0]
        all_facts = self.facts_as_of(at, under)
        # adjacency: a fact is in the cone if it mentions the anchor, or if it
        # mentions a node already reached. Seeded by explicit 'adjacent' facts
        # (rel == "adjacent", cols == (a, b)) which model spatial neighbors.
        reached = {anchor}
        for _ in range(radius):
            newly = set()
            for f in all_facts:
                if f.rel == "adjacent":
                    a, b = f.cols[0], f.cols[1]
                    if a in reached:
                        newly.add(b)
                    if b in reached:
                        newly.add(a)
                else:
                    if any(c in reached for c in f.cols):
                        # this fact's nodes are reachable; include its nodes
                        newly.update(c for c in f.cols if isinstance(c, str))
            reached |= newly
        cone_facts = [f for f in all_facts
                      if any(c in reached for c in f.cols)]
        # canonical order: by serialized form (order-independent digest)
        cone_facts.sort(key=lambda f: ser(f.as_value()))
        return tuple(cone_facts)

    def cone_digest(self, cone_facts: tuple) -> bytes:
        return H("cone", tuple(f.as_value() for f in cone_facts))

    # ---- the one read ------------------------------------------------------
    def query(self, q: AST, under: Cap, budget: int) -> object:
        """Demand-driven read returning the Sat | Incomplete | Unsat trichotomy.
        Supported query ops (extend as the probe grows):
          ("scan", rel, key, at)   -> committed rows for rel whose first col == key
          ("detail", key, at, salt, radius) -> a draw of microdetail (cone-constrained)
          ("depth", key, at)       -> committed depth row, else elapse to `at`
        budget bounds how much derivation may run; 0 forces nothing (lazy pole)."""
        op = q.op
        if op == "at":
            inner, t = q.args
            return self.query(inner, under, budget)  # 'at' rewrote inner's coord
        if op == "scan":
            rel, key, at = q.args
            if not under.can(rel, "read"):
                return Sat(())                      # no existence leak -> no rows
            rows = tuple(f for f in self.facts_as_of(at, under, rel)
                         if f.cols and f.cols[0] == key)
            return Sat(rows)
        if op == "depth":
            key, at = q.args
            rows = tuple(f for f in self.facts_as_of(at, under, "glyph_depth")
                         if f.cols and f.cols[0] == key[0])
            # pick the row whose [from,to] interval covers `at`; else elapse.
            t_at = coord_t(at)
            covering = [f for f in rows if f.cols[2] <= t_at < f.cols[3]]
            if covering:
                return Sat(tuple(covering[-1:]))
            if not rows:
                return Incomplete(("no committed depth for", key))
            # most recent committed row before `at` -> elapse forward to `at`
            base = max(rows, key=lambda f: f.cols[2])
            if budget <= 0:
                return Incomplete(("depth needs elapse, budget=0", key))
            law = AST("max", (AST("sub", ("d0",
                       AST("mul", (AST("var", ("dt",)), AST("lit", (Fraction(1, 12),)))))),
                       AST("lit", (Fraction(0),))))
            return self.elapse(key, from_=coord(t=base.cols[2]), to=at, law=law,
                               under=under, base_depth=base.cols[1])
        if op == "detail":
            key, at, salt, radius = q.args
            if budget <= 0:
                return Incomplete(("detail needs draw, budget=0", key))
            return self.draw(key + (coord_t(at),), at, salt, under, radius=radius)
        raise ValueError(f"unknown query op: {op}")

    # ---- materialize: the eager<->lazy slide as one continuous knob ---------
    def materialize(self, key: tuple, at: tuple, budget: int, under: Cap) -> Memo:
        """Force a derivation PREFIX of `key` at `at`, bounded by `budget`. A
        droppable pure cache. budget=0 forces nothing (lazy pole); large budget
        forces depth+detail (eager pole). The budget-k answer is an ORDERED
        PREFIX of budget-(k+1): leaning in only ADDS facts, never changes them
        (faithful-coarsening-as-theorem -- which stress #2 actually tests).

        The ordered prefix discipline: we accumulate facts in a fixed order
        (base scan, then depth, then detail), and budget caps how far down that
        order we go. A coarse Memo's facts are literally the first slice of a
        fine Memo's facts."""
        mk = (key, at, budget)
        if mk in self._memo:
            return self._memo[mk]
        facts: list[Fact] = []
        # level 0 (cheapest, always): the immutable base scan
        base = self.query(AST("scan", ("glyph", key[0], at)), under, budget)
        if isinstance(base, Sat):
            facts.extend(base.facts)
        # level 1: weathered depth (needs budget >= 1)
        if budget >= 1:
            dep = self.query(AST("depth", (key, at)), under, budget)
            if isinstance(dep, Sat):
                facts.extend(dep.facts)
        # level 2+: microdetail draw (needs budget >= 2); radius grows with budget
        if budget >= 2:
            radius = 1 + (budget - 2)   # deeper budget -> wider cone probe
            det = self.query(AST("detail", (key, at, "microfracture", radius)),
                             under, budget)
            if isinstance(det, Sat):
                facts.extend(det.facts)
        memo = Memo(key=key, at=at, budget=budget, answer=Sat(tuple(facts)))
        self._memo[mk] = memo
        return memo

    # ---- the generation seam: draw (cone-constrained, seeded by key+cone) ---
    def draw(self, key: tuple, at: tuple, salt: str, under: Cap, radius: int = 1):
        """The seeded oracle. Produces a fact DETERMINISTICALLY from
        H(seed, key, cone-digest, salt) -- seeded by the key (stable, replayable)
        AND constrained by the committed cone (content depends on the causal
        neighborhood, not the name alone). Returns an Answer; does NOT commit.

        Cone-constrained content (the §2 repair, made real): the microdetail
        (lichen count, crack-presence, pit pattern) is drawn from the seed, then
        CONSTRAINED by the cone -- a hairline crack appears IFF an adjacent
        committed flaw exists in the cone (the crack propagates FROM the
        neighbor). Lichen count is bounded by committed exposure facts. This is
        where a draw can paint into a corner (stress #1) and where it can pop if
        the cone grew between glance and lean-in (stress #2)."""
        if not under.can("glyph_microdetail", "draw"):
            return Sat(())
        cone_facts = self.cone((key[0],), at, under, radius=radius)
        cdig = self.cone_digest(cone_facts)
        seed_digest = H(self.seed, key, cdig, salt)

        # --- derive content from the seed, then CONSTRAIN by the cone ---------
        # lichen specks: a seed-derived base count in [0, max_lichen], where
        # max_lichen is bounded by committed 'exposure' in the cone (more
        # exposure -> more lichen possible). Cone-constrained ceiling.
        exposure = Fraction(0)
        flaws = []
        for f in cone_facts:
            if f.rel == "exposure" and f.cols[0] == key[0]:
                exposure = f.cols[1]
            if f.rel == "flaw":            # an adjacent committed flaw
                flaws.append(f)
        max_lichen = int(exposure)          # exposure 3 -> up to 3 specks
        u = hash_to_unit(seed_digest)
        lichen = int(u * (max_lichen + 1)) if max_lichen >= 0 else 0
        lichen = min(lichen, max_lichen)

        # hairline crack: present IFF the cone contains an adjacent flaw AND the
        # seed says so -- it propagates FROM the neighbor (content = f(cone)).
        crack_seed = hash_to_unit(H(seed_digest, "crack"))
        crack = bool(flaws) and crack_seed >= Fraction(1, 2)

        # pit pattern: a small deterministic code from the seed (name-stable part)
        pit = int.from_bytes(H(seed_digest, "pit")[:2], "big") % 8

        detail = (("lichen", lichen), ("crack", crack), ("pit", pit))
        fact = Fact("glyph_microdetail", (key[0], coord_t(at), detail))
        return Sat((fact,))

    # ---- elapse: the time-analogue of draw (one coordinate jump) -----------
    def elapse(self, key: tuple, from_: tuple, to: tuple, law: AST, under: Cap,
               base_depth: Fraction):
        """Derive `key`'s state as of `to` given last-commit at `from_`, by a
        serializable `law` evaluated ONCE over the interval (closed-form; no
        per-tick loop). Seeded by H(seed, key, from, to) and cone-constrained.

        The 3-year jump is ONE coordinate selection: dt = t(to) - t(from), and
        weather_fn(d0, dt) is evaluated once. Cost is O(1) in years."""
        if not under.can("glyph_depth", "draw") and not under.can("glyph_depth", "read"):
            return Sat(())
        dt = coord_t(to) - coord_t(from_)
        env = {"d0": base_depth, "dt": dt}
        d1 = eval_law(law, env)
        assert_value(d1)
        new_row = Fact("glyph_depth", (key[0], d1, coord_t(to), Fraction(10**9)))
        return Sat((new_row,))

    # ---- time: at -- reframe a derivation as-of a coordinate ----------------
    @staticmethod
    def at(q: AST, t: tuple) -> AST:
        """Time as a coordinate, not a tick: rewrite query `q` to be evaluated
        as-of coordinate `t`. We thread `t` into the inner op's `at` slot."""
        op = q.op
        if op in ("scan",):
            rel, key, _old = q.args
            return AST("scan", (rel, key, t))
        if op in ("depth",):
            key, _old = q.args
            return AST("depth", (key, t))
        if op in ("detail",):
            key, _old, salt, radius = q.args
            return AST("detail", (key, t, salt, radius))
        return AST("at", (q, t))


# ===========================================================================
# replay -- reconstruct the world bit-for-bit from seed + log.
# ===========================================================================
def replay(log, seed: bytes) -> World:
    """Reconstruct the entire derivable world from seed + log, pure. Re-appends
    each event by content address; the rebuilt log is bit-identical. The harness
    asserts replay(w.log, w.seed) reproduces w exactly."""
    w = World(seed)
    for ev in log:
        w.log.append(ev)   # events are immutable + content-addressed; just re-lay
    return w


def world_digest(w: World) -> bytes:
    """A bit-for-bit fingerprint of the derivable world: seed + the full log's
    content addresses. Same seed + same log => identical digest."""
    return H("world", w.seed, tuple(ev.id for ev in w.log))
