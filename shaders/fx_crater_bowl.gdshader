shader_type spatial;
// Explosion round B: the inside of a crater, below the map ground. No depth test (the ground is in front of it), but
// only where the crater's mask marked the stencil. A bowl is convex, so it never has to cover itself.
render_mode cull_back, depth_test_disabled, depth_draw_never, diffuse_lambert_wrap, specular_disabled;
stencil_mode read, compare_equal, 32;

#include "res://shaders/fx_common.gdshaderinc"

void fragment() {
	ALBEDO = fx_lin(COLOR.rgb);
	ROUGHNESS = 1.0;
	ALPHA = 1.0;
}
