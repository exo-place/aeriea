## THROWAWAY PROTOTYPE — body/transformation substrate, PLAIN MODEL.
##
## Supersedes the earlier cell/fold/Expr/mget kernel. Expected-wrong learning
## artifact; NOT wired into any game scene. See the friction log returned with
## this prototype.
##
## THE PLAIN MODEL, in full:
##   - STATE is a tree of parts. A Part is a PLAIN STRUCT: named fields holding
##     plain values (numbers/strings/bools/lists), plus ordered children and a
##     parent. A field holds a value; read it directly (`part.fields["p"]`).
##     There is no value|expr union, no cell, no accessor, no discriminator.
##   - BEHAVIOR is SEPARATE from state. A transformation is a plain function that
##     reads the tree and writes new field values into parts. Parts do not carry
##     transformations. Data and computation are separate.
##   - EXECUTION: each tick runs all active transformations in a deterministic
##     order (this prototype uses the order they were listed), mutating part
##     fields IN PLACE. No snapshot, no buffer. Determinism comes from the order:
##     same setup + same seed re-run gives identical results.
##   - Per-transition PROGRESS is accumulated plain-field state that a
##     transformation steps forward. It is NOT computed from a clock or a tick
##     count. That is what lets a transition pause (decline to advance) and lets
##     two transitions run in parallel out of step.
class_name TFPart
extends RefCounted

## A node in the body tree. Just data: named fields + tree links.
var parent: TFPart = null
var children: Array = []      ## ordered Array[TFPart]
var fields: Dictionary = {}   ## plain field name -> plain value

func add_child(c: TFPart) -> TFPart:
	c.parent = self
	children.append(c)
	return c
