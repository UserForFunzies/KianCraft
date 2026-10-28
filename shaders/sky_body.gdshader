// Sun and moon squares: always full brightness and never hidden by fog.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_mix;

uniform vec4 color : source_color = vec4(1.0, 0.95, 0.6, 1.0);

void fragment() {
	// Slightly brighter in the middle, like a glowing disc.
	vec2 c = UV - vec2(0.5);
	float edge = 1.0 - smoothstep(0.35, 0.5, max(abs(c.x), abs(c.y)));
	ALBEDO = color.rgb * (0.85 + 0.15 * edge);
	ALPHA = color.a;
}
