## CxgRealizer — first experiment for aeriea's text-generation architecture.
##
## A deterministic Construction-Grammar prose realizer. This is the §8 runtime
## experiment from docs/decisions/text-generation-architecture.md: it ports the
## IDEAS of the Python toy (docs/artifacts/text-gen-design/grammar-candidate-B-cxg.md)
## to GDScript AND grafts the three C-disciplines the determinism+gate judge
## (docs/artifacts/text-gen-design/judge2-determinism-gate.md) ruled MANDATORY:
##
##   1. LEXEME-LEVEL PROVENANCE GATE. The Python toy gated on a `requires`
##      annotation while its `lit` strings silently asserted uncommitted facts
##      (C.head_comes_up asserts "you cross the threshold"; C.gaze_finds asserts
##      eye-contact). Here EVERY construction carries an `asserts` list of the
##      propositions its literal text actually puts on the page, and a construction
##      is licensed iff `asserts ⊆ (committed-true ∪ licensed-falsity)`. An
##      unlicensed assertion is UNREACHABLE at selection, not filtered after.
##   2. TOTAL-ORDER EVERY DRAW. Candidate constructions are sorted by id before any
##      weighted pick; lexical fills sorted. No Dictionary/Set iteration order
##      reaches a selection decision. (Godot Dictionary != CPython insertion order;
##      a naive port would diverge.)
##   3. INTEGER splitmix64 PRNG, INTEGER weights, NO FLOAT in the selection path.
##
## Plus the §7-bet investment the output-quality judge named
## (docs/artifacts/text-gen-design/judge2-output-quality.md): RST-style COHESION
## constructions (concession / cause / elaboration) as first-class members, so
## adjacent material is RELATED, not bolted-on tiles. The toy concatenated with
## ". " and read seamy ("She registers you after all this time. Rain ticks against
## the window."); here the join is itself a construction that fuses.
##
## LICENSED FALSITY: the commitment store carries a speech-fact for a LIE
## (Maren says she barely noticed, which is false — she is glad). The lie surfaces
## ONLY through the speech-fact license; the underlying false proposition
## (stance.indifferent) is NOT committed-true, so no NARRATION can assert it.
##
## Determinism: same (seed, voice) -> byte-identical output. No randf(), no time,
## no hashing of strings at runtime, no global mutable state.
class_name CxgRealizer
extends RefCounted


# ===========================================================================
# splitmix64 — integer-only deterministic PRNG (no float, no string hashing).
# GDScript ints are 64-bit signed; bit ops wrap as two's-complement, which is the
# same bit pattern splitmix64 wants. We never compare these as signed magnitudes;
# every draw is `(value mod total)` with a non-negative total and a non-negative
# remainder, so the sign of the raw 64-bit word never reaches a selection decision.
# ===========================================================================
class Rng:
	extends RefCounted
	var s: int

	func _init(seed: int) -> void:
		s = seed

	func next() -> int:
		s = s + -0x61C8864680B583EB           # 0x9E3779B97F4A7C15 as signed; wraps mod 2^64
		var z: int = s
		z = (z ^ (z >> 30)) * -0x40A7B892E31B1A47   # 0xBF58476D1CE4E5B9 as signed
		z = (z ^ (z >> 27)) * -0x6B2FB644ECCEEE15   # 0x94D049BB133111EB as signed
		z = z ^ (z >> 31)
		return z

	## Non-negative draw in [0, n). `n` must be > 0. Uses the unsigned low bits of
	## the 64-bit word: mask off the sign bit, then mod. Deterministic and float-free.
	func below(n: int) -> int:
		var raw: int = next() & 0x7FFFFFFFFFFFFFFF   # drop sign bit -> non-negative
		return raw % n

	## Deterministic integer-weighted pick over an ALREADY-TOTALLY-ORDERED list of
	## [item, weight] pairs (weights are positive ints). No float anywhere.
	func pick(weighted: Array) -> Variant:
		var total: int = 0
		for pair in weighted:
			total += int(pair[1])
		if total <= 0:
			return weighted[weighted.size() - 1][0]
		var r: int = below(total)
		for pair in weighted:
			var w: int = int(pair[1])
			if r < w:
				return pair[0]
			r -= w
		return weighted[weighted.size() - 1][0]


# ===========================================================================
# COMMITMENT STORE
#   props_true     : propositions that are TRUE in the world / POV. NARRATION may
#                    only assert these (the hard gate).
#   speech_facts   : licensed-falsity frame. Each is a committed FACT that a
#                    character SAID a thing; the said-content may be false. A SPEECH
#                    construction may surface speech_fact assertions even though the
#                    underlying proposition is not in props_true. This is the only
#                    door to falsity: she *says* X is itself true; X need not be.
# ===========================================================================
class Commitments:
	extends RefCounted
	var props_true: Dictionary = {}          # prop_key -> true
	var speech_props: Dictionary = {}        # prop_key -> true (licensed in SPEECH only)

	func commit(prop: String) -> void:
		props_true[prop] = true

	## License a possibly-false proposition to be ASSERTED IN DIALOGUE only.
	func license_speech(prop: String) -> void:
		speech_props[prop] = true

	## Is `prop` licensed for narration (must be world-true)?
	func narratable(prop: String) -> bool:
		return props_true.has(prop)

	## Is `prop` licensed for speech (world-true OR a licensed speech-fact)?
	func speakable(prop: String) -> bool:
		return props_true.has(prop) or speech_props.has(prop)


# ===========================================================================
# CONSTRUCTION DATA SHAPE (plain dicts; built once, never iterated into a draw).
#   id        : stable name (sort key for total-ordering)
#   sem       : meaning category it realizes
#   form      : ordered list of form elements:
#                 ["lit", "text"]                    fixed material
#                 ["slot", sem, role]                a typed hole -> recurse
#   reg       : Array of register tags (taste-space coordinate)
#   asserts   : Array of propositions the construction's OWN literal text puts on
#               the page (NOT counting what its slots assert — those are gated
#               when THEY are realized). THIS is the lexeme-level provenance: the
#               gate reads what the surface actually says.
#   speech    : if true, this construction is a SPOKEN line; its `asserts` are
#               gated by `speakable` (licensed-falsity allowed). Otherwise `asserts`
#               are gated by `narratable` (world-true only).
#   weight    : integer base preference mass
# ===========================================================================

static func _lit(t: String) -> Array: return ["lit", t]
static func _slot(sem: String, role: String = "") -> Array: return ["slot", sem, role]

# The micro-constructicon. Two contrasting voices share the inventory; the VOICE
# affinity vectors (below) re-rank which constructions win, so the SAME content
# reads in different voices. Cohesion constructions (CO.*) are first-class.
static func _constructicon() -> Array:
	return [

	# ---- DISCOURSE grain: how the noticing beat is staged. The discourse cxn is
	#      where STRUCTURE/CADENCE is chosen FIRST, before any word. The cohesive
	#      variants weave ambient INTO the clause via a relation, instead of
	#      appending a free-standing sentence (the anti-tile-seam move). ----

	# perception, THEN — cohesively joined by a concession/elaboration — the notice,
	# then her line. The join is a COHESION construction, not a bare ". ".
	{ "id": "D.weave_percept_notice_speech", "sem": "BEAT_NOTICE",
	  "form": [ _slot("COHESION_AMBIENT_NOTICE", "weave"), _lit(". "), _slot("SPEECH", "line") ],
	  "reg": ["lyric", "intimate", "plain"], "asserts": [], "weight": 4 },

	# speech first, her line landing before the narration settles, ambient woven as a coda relation
	{ "id": "D.speech_then_woven_percept", "sem": "BEAT_NOTICE",
	  "form": [ _slot("SPEECH", "line"), _lit(" "), _slot("COHESION_NOTICE_AMBIENT", "weave"), _lit(".") ],
	  "reg": ["terse", "wry", "gruff"], "asserts": [], "weight": 3 },

	# interior only — guarded enough to say nothing; ambient woven to the notice
	{ "id": "D.interior_only", "sem": "BEAT_NOTICE",
	  "form": [ _slot("COHESION_AMBIENT_NOTICE", "weave"), _lit(".") ],
	  "reg": ["terse", "gruff", "lyric"], "asserts": [], "weight": 2 },

	# ---- COHESION grain (RST): these FUSE two propositions with a relation so the
	#      result reads woven, not adjacent. Each takes the ambient + notice clauses
	#      as slots and joins them with a concessive/causal/elaborative connective.
	#      The connective itself asserts NOTHING new (it relates committed facts), so
	#      `asserts` is empty — relation, not proposition. ----

	# concession: rain notwithstanding, she still registers you. ("for all that")
	{ "id": "CO.ambient_concede_notice", "sem": "COHESION_AMBIENT_NOTICE",
	  "form": [ _slot("AMBIENT", "a"), _lit(" — and for all of it, "), _slot("NOTICE_CLAUSE_LC", "b") ],
	  "reg": ["lyric", "intimate"], "asserts": [], "weight": 3 },

	# cause/backdrop: the rain sets the hush IN WHICH the notice happens
	{ "id": "CO.ambient_backdrop_notice", "sem": "COHESION_AMBIENT_NOTICE",
	  "form": [ _slot("AMBIENT", "a"), _lit(", and in that hush "), _slot("NOTICE_CLAUSE_LC", "b") ],
	  "reg": ["lyric", "plain"], "asserts": [], "weight": 2 },

	# terse weave: ambient clause, em-dash, clipped notice
	{ "id": "CO.ambient_dash_notice", "sem": "COHESION_AMBIENT_NOTICE",
	  "form": [ _slot("AMBIENT", "a"), _lit(" — "), _slot("NOTICE_CLAUSE_LC", "b") ],
	  "reg": ["terse", "gruff", "wry"], "asserts": [], "weight": 2 },

	# the reverse direction: notice first, ambient as a relating coda ("while ...")
	{ "id": "CO.notice_while_ambient", "sem": "COHESION_NOTICE_AMBIENT",
	  "form": [ _slot("NOTICE_CLAUSE", "a"), _lit(" The rain keeps on at the glass the whole time, "), _slot("AMBIENT_REL", "b") ],
	  "reg": ["plain", "lyric", "intimate"], "asserts": [], "weight": 2 },

	# terser reverse: notice, then a short ambient beat fused by "—"
	{ "id": "CO.notice_dash_ambient", "sem": "COHESION_NOTICE_AMBIENT",
	  "form": [ _slot("NOTICE_CLAUSE", "a"), _lit(" Behind you, "), _slot("AMBIENT_REL", "b") ],
	  "reg": ["terse", "wry", "gruff"], "asserts": [], "weight": 2 },

	# ---- CLAUSE / argument-structure grain: the NOTICE event. Two surface forms:
	#      sentence-initial (capitalized) NOTICE_CLAUSE, and lowercase-continuation
	#      NOTICE_CLAUSE_LC for use INSIDE a cohesion weave. The `asserts` on each
	#      is EXACTLY what its literal text claims — the lexeme-level provenance. ----

	# transitive "registers you" — asserts the notice; absence adjunct asserts absence
	{ "id": "C.registers", "sem": "NOTICE_CLAUSE",
	  "form": [ _slot("ACTOR_NOM", "subj"), _lit(" registers you "), _slot("ABSENCE_ADJ", "adj"), _lit(".") ],
	  "reg": ["terse", "wry", "plain"], "asserts": ["event.notice_return"], "weight": 3 },
	{ "id": "C.registers_lc", "sem": "NOTICE_CLAUSE_LC",
	  "form": [ _slot("ACTOR_NOM_LC", "subj"), _lit(" registers you "), _slot("ABSENCE_ADJ", "adj") ],
	  "reg": ["terse", "wry", "plain"], "asserts": ["event.notice_return"], "weight": 3 },

	# "her eyes come up" double-take — asserts ONLY the look coming up. NOTE: unlike
	# the toy's C.head_comes_up, it does NOT assert "you cross the threshold" (an
	# uncommitted spatial fact). The gate would block that lexeme; we never wrote it.
	{ "id": "C.eyes_up", "sem": "NOTICE_CLAUSE",
	  "form": [ _slot("ACTOR_POSS", "poss"), _lit(" eyes come up "), _slot("ABSENCE_ADJ", "adj"), _lit(".") ],
	  "reg": ["plain", "gruff", "terse"], "asserts": ["event.notice_return"], "weight": 2 },
	{ "id": "C.eyes_up_lc", "sem": "NOTICE_CLAUSE_LC",
	  "form": [ _slot("ACTOR_POSS_LC", "poss"), _lit(" eyes come up "), _slot("ABSENCE_ADJ", "adj") ],
	  "reg": ["plain", "gruff", "terse"], "asserts": ["event.notice_return"], "weight": 2 },

	# addressee-fronted existential "there you are again" — lyric
	{ "id": "C.there_you_are", "sem": "NOTICE_CLAUSE",
	  "form": [ _lit("there you are again, "), _slot("ABSENCE_NP", "np"), _lit(".") ],
	  "reg": ["lyric", "intimate"], "asserts": ["event.notice_return"], "weight": 2 },
	{ "id": "C.there_you_are_lc", "sem": "NOTICE_CLAUSE_LC",
	  "form": [ _lit("there you are again, "), _slot("ABSENCE_NP", "np") ],
	  "reg": ["lyric", "intimate"], "asserts": ["event.notice_return"], "weight": 2 },

	# ---- A POISONED CONSTRUCTION (gate test). This asserts a spatial fact
	#      "you cross the threshold" that is NEVER committed. With the lexeme-level
	#      gate it is UNREACHABLE — proof the gate blocks at selection, not after.
	#      (The orchestrator's gate test asserts this id can never appear.) ----
	{ "id": "C.threshold_BAD", "sem": "NOTICE_CLAUSE_LC",
	  "form": [ _slot("ACTOR_POSS_LC", "poss"), _lit(" head comes up the moment you cross the threshold") ],
	  "reg": ["plain", "gruff"], "asserts": ["event.notice_return", "scene.threshold_crossing"], "weight": 2 },

	# ---- ABSENCE adjunct (the long-absence commitment), several phrasings ----
	{ "id": "A.after_all_this_time", "sem": "ABSENCE_ADJ",
	  "form": [ _lit("after all this time") ], "reg": ["plain", "terse", "wry"],
	  "asserts": ["event.long_absence"], "weight": 2 },
	{ "id": "A.so_long_gone", "sem": "ABSENCE_ADJ",
	  "form": [ _lit("after being gone so long") ], "reg": ["plain", "gruff", "terse"],
	  "asserts": ["event.long_absence"], "weight": 2 },
	{ "id": "A.like_no_gap", "sem": "ABSENCE_ADJ",
	  "form": [ _lit("as if no time had gone at all") ], "reg": ["lyric", "intimate"],
	  "asserts": ["event.long_absence"], "weight": 1 },
	{ "id": "A.np_months", "sem": "ABSENCE_NP",
	  "form": [ _lit("the months since folding shut to nothing") ], "reg": ["lyric", "intimate"],
	  "asserts": ["event.long_absence"], "weight": 2 },
	{ "id": "A.np_long", "sem": "ABSENCE_NP",
	  "form": [ _lit("the long quiet closing over behind you") ], "reg": ["lyric"],
	  "asserts": ["event.long_absence"], "weight": 1 },

	# ---- ACTOR reference, two cases x two surface positions (sentence-initial vs
	#      mid-sentence lowercase). Names assert nothing propositional. ----
	{ "id": "N.maren_nom", "sem": "ACTOR_NOM", "form": [ _lit("Maren") ], "reg": ["any"], "asserts": [], "weight": 2 },
	{ "id": "N.she_nom", "sem": "ACTOR_NOM", "form": [ _lit("She") ], "reg": ["any"], "asserts": [], "weight": 2 },
	{ "id": "N.maren_nom_lc", "sem": "ACTOR_NOM_LC", "form": [ _lit("Maren") ], "reg": ["any"], "asserts": [], "weight": 2 },
	{ "id": "N.she_nom_lc", "sem": "ACTOR_NOM_LC", "form": [ _lit("she") ], "reg": ["any"], "asserts": [], "weight": 2 },
	{ "id": "N.maren_poss", "sem": "ACTOR_POSS", "form": [ _lit("Maren's") ], "reg": ["any"], "asserts": [], "weight": 2 },
	{ "id": "N.her_poss", "sem": "ACTOR_POSS", "form": [ _lit("Her") ], "reg": ["any"], "asserts": [], "weight": 1 },
	{ "id": "N.maren_poss_lc", "sem": "ACTOR_POSS_LC", "form": [ _lit("Maren's") ], "reg": ["any"], "asserts": [], "weight": 2 },
	{ "id": "N.her_poss_lc", "sem": "ACTOR_POSS_LC", "form": [ _lit("her") ], "reg": ["any"], "asserts": [], "weight": 1 },

	# ---- AMBIENT (rain commitment), several grains. Sentence-form for stand-alone
	#      slots; AMBIENT_REL for a relating-coda position. ----
	{ "id": "R.rain_glass", "sem": "AMBIENT",
	  "form": [ _lit("Rain ticks at the window") ], "reg": ["plain", "terse"],
	  "asserts": ["ambient.raining"], "weight": 2 },
	{ "id": "R.rain_lyric", "sem": "AMBIENT",
	  "form": [ _lit("The rain comes down soft and steady, blurring the street to grey") ],
	  "reg": ["lyric", "intimate"], "asserts": ["ambient.raining"], "weight": 2 },
	{ "id": "R.rain_hush", "sem": "AMBIENT",
	  "form": [ _lit("The rain hushes everything past the glass") ],
	  "reg": ["lyric", "intimate", "plain"], "asserts": ["ambient.raining"], "weight": 2 },
	{ "id": "R.rain_low", "sem": "AMBIENT",
	  "form": [ _lit("Outside, the rain keeps up its low argument") ], "reg": ["wry", "gruff", "plain"],
	  "asserts": ["ambient.raining"], "weight": 2 },
	# relating-coda forms (read as a continuation, lowercase, no leading capital)
	{ "id": "R.rel_saying", "sem": "AMBIENT_REL",
	  "form": [ _lit("saying the rest for her") ], "reg": ["lyric", "intimate"],
	  "asserts": ["ambient.raining"], "weight": 2 },
	{ "id": "R.rel_steady", "sem": "AMBIENT_REL",
	  "form": [ _lit("steady as an old argument") ], "reg": ["plain", "terse", "wry"],
	  "asserts": ["ambient.raining"], "weight": 2 },

	# ---- SPEECH grain: spoken lines. THIS is where licensed falsity may surface,
	#      because a SPEECH cxn is gated by `speakable`, not `narratable`. ----

	# guarded-but-glad fused in ONE line: glad core + guarded tag (the subtext unit)
	{ "id": "S.glad_undercut", "sem": "SPEECH", "speech": true,
	  "form": [ _lit("\""), _slot("GLAD_CORE", "core"), _lit(",\" "), _slot("GUARDED_TAG", "tag") ],
	  "reg": ["intimate", "plain", "lyric"], "asserts": [], "weight": 3 },
	# clipped guarded opener, no glad shown out loud
	{ "id": "S.guarded_line", "sem": "SPEECH", "speech": true,
	  "form": [ _lit("\""), _slot("GUARDED_OPENER", "op"), _lit("\"") ],
	  "reg": ["terse", "wry", "gruff"], "asserts": [], "weight": 3 },
	# THE LICENSED LIE: she says she barely noticed (false; she is glad). Gated by a
	# speech_prop, NOT props_true. Only reachable when the lie is licensed.
	{ "id": "S.lie_indifferent", "sem": "SPEECH", "speech": true,
	  "form": [ _lit("\"Didn't even clock you'd gone,\" she says, like it's nothing.") ],
	  "reg": ["wry", "gruff", "terse"], "asserts": ["speech.claims_indifferent"], "weight": 2 },

	# GLAD core — deliberately NON-STANDARD voice-B dialogue: comma-splice / fragment
	{ "id": "GL.came_back", "sem": "GLAD_CORE",
	  "form": [ _lit("You came back") ], "reg": ["plain", "intimate", "lyric"],
	  "asserts": ["stance.glad"], "weight": 2 },
	{ "id": "GL.didnt_think", "sem": "GLAD_CORE",
	  "form": [ _lit("I didn't think you would") ], "reg": ["intimate", "plain"],
	  "asserts": ["stance.glad"], "weight": 2 },
	# voice-B ungrammatical: run-on / comma-splice, the deliberate non-standard form
	{ "id": "GL.runon_slang", "sem": "GLAD_CORE",
	  "form": [ _lit("Look at you, you're back, you actually came back") ],
	  "reg": ["wry", "intimate"], "asserts": ["stance.glad"], "weight": 2 },

	# GUARDED tags (close the glad core with held-back wariness)
	{ "id": "T.tag_dry", "sem": "GUARDED_TAG",
	  "form": [ _lit("she says, not quite looking at you.") ], "reg": ["plain", "terse"],
	  "asserts": ["stance.guarded"], "weight": 2 },
	{ "id": "T.tag_soft", "sem": "GUARDED_TAG",
	  "form": [ _lit("she says, and the wariness in it doesn't quite cover the rest.") ],
	  "reg": ["lyric", "intimate"], "asserts": ["stance.guarded"], "weight": 2 },
	{ "id": "T.tag_frag", "sem": "GUARDED_TAG",
	  "form": [ _lit("she says. Doesn't move toward you. Doesn't have to.") ],
	  "reg": ["wry", "terse", "gruff"], "asserts": ["stance.guarded"], "weight": 2 },

	# GUARDED openers
	{ "id": "G.look_who", "sem": "GUARDED_OPENER",
	  "form": [ _lit("Look who it is.") ], "reg": ["wry", "gruff"],
	  "asserts": ["stance.guarded"], "weight": 2 },
	{ "id": "G.youre_back", "sem": "GUARDED_OPENER",
	  "form": [ _lit("So. You're back.") ], "reg": ["terse", "gruff"],
	  "asserts": ["stance.guarded"], "weight": 2 },
	{ "id": "G.forgot_way", "sem": "GUARDED_OPENER",
	  "form": [ _lit("Thought you'd forgotten the way back.") ], "reg": ["wry", "terse"],
	  "asserts": ["stance.guarded", "event.long_absence"], "weight": 2 },
	]


# ===========================================================================
# VOICE / TASTE-SPACE. Integer affinity multipliers per register tag. A voice is a
# point in this space; mood/register would MOVE the point at runtime. Two
# contrasting anchors are exercised here (and three more to show the space is
# parameterized, not two locked voices).
# ===========================================================================
static func _voices() -> Dictionary:
	return {
		# Voice A: guarded, literary close-third narrator
		"literary_guarded": { "lyric": 4, "intimate": 3, "plain": 3, "wry": 1, "terse": 1, "gruff": 1, "any": 2 },
		# Voice B: slangy, terse, wry character whose dialogue runs non-standard
		"slangy_wry":       { "wry": 4, "terse": 4, "gruff": 3, "plain": 2, "lyric": 1, "intimate": 1, "any": 2 },
		# extra points in the space (parameterization, not locked voices)
		"plain_flat":       { "plain": 4, "terse": 2, "gruff": 2, "wry": 2, "lyric": 1, "intimate": 1, "any": 2 },
		"intimate_soft":    { "intimate": 4, "lyric": 4, "plain": 2, "wry": 1, "terse": 1, "gruff": 1, "any": 2 },
		"gruff_guard":      { "gruff": 4, "terse": 3, "wry": 2, "plain": 2, "lyric": 1, "intimate": 1, "any": 2 },
	}


# ===========================================================================
# GATE + selection.
# ===========================================================================

## A construction is licensed iff every proposition its OWN literal text asserts is
## permitted for its modality (narratable for narration, speakable for speech).
## This is the lexeme-level provenance gate: unlicensed assertion is unreachable.
static func _licensed(cxn: Dictionary, commit: Commitments) -> bool:
	var is_speech: bool = bool(cxn.get("speech", false))
	for prop in cxn.get("asserts", []):
		if is_speech:
			if not commit.speakable(prop):
				return false
		else:
			if not commit.narratable(prop):
				return false
	return true


## Voice affinity: base weight scaled by the voice's strongest affinity over the
## construction's register tags. Integer-only.
static func _voice_weight(cxn: Dictionary, voice: Dictionary) -> int:
	var best: int = 1
	for tag in cxn.get("reg", []):
		var m: int = int(voice.get(tag, 1))
		if m > best:
			best = m
	return int(cxn.get("weight", 1)) * best


# ===========================================================================
# Realizer — top-down recursive realization, fully total-ordered before any draw.
# Returns [text, used_ids].
# ===========================================================================
static func realize(sem: String, rng: Rng, voice: Dictionary, commit: Commitments, by_sem: Dictionary) -> Array:
	var raw: Array = by_sem.get(sem, [])
	# Build the licensed candidate list, then TOTAL-ORDER by id BEFORE any pick so
	# Dictionary/Array iteration order never reaches the draw.
	var cands: Array = []
	for cxn in raw:
		if _licensed(cxn, commit):
			cands.append(cxn)
	cands.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	if cands.is_empty():
		return ["<%s?>" % sem, ["<gap:%s>" % sem]]
	var weighted: Array = []
	for cxn in cands:
		weighted.append([cxn, _voice_weight(cxn, voice)])
	var chosen: Dictionary = rng.pick(weighted)
	var out: String = ""
	var used: Array = [chosen["id"]]
	for el in chosen["form"]:
		if el[0] == "lit":
			out += el[1]
		else:
			var sub: Array = realize(el[1], rng, voice, commit, by_sem)
			out += sub[0]
			used.append_array(sub[1])
	return [out, used]


## Build the sem -> [constructions] index ONCE. The index is only ever READ by key
## and its per-key list is re-sorted at selection, so insertion order is irrelevant.
static func build_index() -> Dictionary:
	var by_sem: Dictionary = {}
	for cxn in _constructicon():
		var sem: String = cxn["sem"]
		if not by_sem.has(sem):
			by_sem[sem] = []
		by_sem[sem].append(cxn)
	return by_sem


## Top-level realization of the noticing beat. Pure function of (seed, voice_name,
## commit). Returns [text, used_ids].
static func realize_beat(seed: int, voice_name: String, commit: Commitments) -> Array:
	var rng := Rng.new(seed)
	var voice: Dictionary = _voices().get(voice_name, _voices()["plain_flat"])
	return realize("BEAT_NOTICE", rng, voice, commit, build_index())


## Convenience: the §8 fixed scene's commitment store.
## "Maren notices the player has returned after a long absence; guarded but glad;
##  it is raining." She LIES in dialogue that she didn't notice (licensed falsity).
static func scene_commitments(license_lie: bool = true) -> Commitments:
	var c := Commitments.new()
	c.commit("event.notice_return")
	c.commit("event.long_absence")
	c.commit("stance.guarded")
	c.commit("stance.glad")
	c.commit("ambient.raining")
	# NOT committed: scene.threshold_crossing, stance.indifferent.
	if license_lie:
		# She SAYS she's indifferent — a committed speech-fact whose content is false.
		c.license_speech("speech.claims_indifferent")
	return c


## "Just emit one top construction verbatim" baseline for the honest A/B: pick the
## single highest-weight licensed construction at each grain (no seeded variety, no
## cohesion composition beyond the form). Used to test whether composition+cohesion
## ADD generative value beyond the authored fragments.
static func realize_baseline_top(voice_name: String, commit: Commitments) -> Array:
	var voice: Dictionary = _voices().get(voice_name, _voices()["plain_flat"])
	var by_sem := build_index()
	return _realize_argmax("BEAT_NOTICE", voice, commit, by_sem)

static func _realize_argmax(sem: String, voice: Dictionary, commit: Commitments, by_sem: Dictionary) -> Array:
	var raw: Array = by_sem.get(sem, [])
	var cands: Array = []
	for cxn in raw:
		if _licensed(cxn, commit):
			cands.append(cxn)
	cands.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	if cands.is_empty():
		return ["<%s?>" % sem, ["<gap:%s>" % sem]]
	var chosen: Dictionary = cands[0]
	var best: int = _voice_weight(chosen, voice)
	for cxn in cands:
		var w: int = _voice_weight(cxn, voice)
		if w > best:
			best = w
			chosen = cxn
	var out: String = ""
	var used: Array = [chosen["id"]]
	for el in chosen["form"]:
		if el[0] == "lit":
			out += el[1]
		else:
			var sub: Array = _realize_argmax(el[1], voice, commit, by_sem)
			out += sub[0]
			used.append_array(sub[1])
	return [out, used]
