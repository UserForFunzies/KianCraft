// Cracks drawn on a block while you mine it. Each crack pixel stores (in red)
// how far mining must get before it appears, so cracks spread from the middle.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D cracks : filter_nearest;
uniform float progress = 0.0;

void fragment() {
	vec4 c = texture(cracks, UV);
	if (c.a < 0.5 || c.r > progress) {
		discard;
	}
	ALBEDO = vec3(0.06, 0.05, 0.05);
	ALPHA = 0.75;
}
