## Picker — a backend-agnostic surface-picking interface.
##
## One method, `pick(screen_pos, camera, target)`, resolves a screen-space cursor to a
## surface hit on a target mesh. The point of the abstraction is GENERALITY, not perf:
## MorphDrag (the character creator's drag-to-modify core) and future in-world
## interaction code (picking skinned NPCs / animated objects) depend ONLY on the
## returned hit shape, so the actual picking strategy — a rest-space CPU spatial grid,
## or a GPU "pick what's rendered" ID buffer — can be swapped without touching callers.
##
## This is an ABSTRACT base (RefCounted). `pick()` must be overridden by a backend
## (see `cpu_accel_picker.gd`). The base implementation returns a miss.
##
## ── Hit result shape ─────────────────────────────────────────────────────────────
## `pick()` returns a Dictionary, EMPTY (`{}`) on a miss, otherwise:
##
##   {
##     hit:                 bool,                # always true on a returned hit
##     render_vertex_index: int,                # index into the surface ARRAY_VERTEX
##                                               #   (the key MorphDrag is built on)
##     triangle_index:      int,                # the FIRST index of the hit triangle in
##                                               #   ARRAY_INDEX (i, i+1, i+2); -1 if N/A
##     barycentric:         Vector3,            # (1-u-v, u, v) over the hit triangle's
##                                               #   3 verts; ZERO if N/A (e.g. GPU id pick)
##     world_pos:           Vector3,            # the hit point in WORLD space
##   }
##
## `render_vertex_index` is the nearest of the hit triangle's three verts to the exact
## hit point — matching the creator's historical refinement so the picked vertex (and
## thus the engaged modifier set) is unchanged from the old brute-force scan.
##
## ── target shape ─────────────────────────────────────────────────────────────────
## `target` is a small Dictionary the CALLER supplies so the interface stays
## rendering-agnostic. Backends read only the fields they need; all are optional:
##
##   {
##     mesh_instance: MeshInstance3D,           # GPU backend: the rendered surface
##     skeleton:      Skeleton3D,               # GPU backend: skinning source
##     world_xf:      Transform3D,              # world transform of the rest geometry
##                                               #   (CPU backend rays through its inverse)
##     rest_positions: PackedVector3Array,      # CPU backend: rest-space ARRAY_VERTEX
##     tris:           PackedInt32Array,         # CPU backend: ARRAY_INDEX (3 per tri)
##   }
##
## The CPU backend uses `rest_positions` / `tris` / `world_xf`; a GPU backend uses
## `mesh_instance` / `skeleton`. Picking is editor/UI only — it never enters the seeded
## sim, the action log, or a golden trace.
class_name Picker
extends RefCounted


## Resolve a screen position to a surface hit on `target`. Returns the hit Dictionary
## documented above, or `{}` on a miss. ABSTRACT — backends override this.
func pick(_screen_pos: Vector2, _camera: Camera3D, _target: Dictionary) -> Dictionary:
	push_error("Picker.pick() is abstract — use a concrete backend (e.g. CpuAccelPicker).")
	return {}
