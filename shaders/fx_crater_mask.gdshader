shader_type spatial;
// Explosion round B: a crater's outline on the map ground. Draws nothing; marks the stencil where it is seen, so the
// crater's bowl (fx_crater_bowl) shows only there, like a hole in the ground. Drawn before the bowl (render_priority).
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
stencil_mode write, compare_always, 32;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
