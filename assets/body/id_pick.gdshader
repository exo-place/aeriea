// ID-buffer pick shader (GpuIdPicker). Renders the body's RENDER-VERTEX INDEX as a
// color so a 1-pixel readback under the cursor decodes to a vertex. Unshaded; the
// surface is rendered with its real skinning + morphs so the picked surface is the
// actually-displayed one (the whole point of the GPU backend over a rest-space CPU scan).
//
// CUSTOM0 carries the index as RGBA8_UNORM (set at asset-build time in body_converter.gd):
// per render vertex, bytes [low, mid, high, 255] of the 24-bit index, delivered to the
// shader as a normalized vec4 (each component bytes/255). We pass it FLAT (no
// interpolation) so every fragment of a triangle carries exactly ONE vertex's id (the
// provoking vertex) — without `flat`, the bytes would be barycentrically blended into
// garbage. We re-emit the same bytes to ALBEDO; the SubViewport is configured (no HDR,
// no tonemap, sRGB-disabled / raw) so the 8-bit bytes survive un-mangled to readback.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

varying flat vec4 v_id;

void vertex() {
	v_id = CUSTOM0;
}

void fragment() {
	ALBEDO = v_id.rgb;
	ALPHA = 1.0;
}
