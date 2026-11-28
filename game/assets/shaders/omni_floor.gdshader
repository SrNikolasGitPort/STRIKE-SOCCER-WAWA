shader_type spatial;
// Piso da Dimensão Omnisférica: mesmo padrão da cúpula, projetado no chão.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 col_a : source_color = vec4(0.1, 0.2, 0.6, 1.0);
uniform vec4 col_b : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float cells = 14.0;
uniform float line_w = 0.07;
uniform int pattern = 0;
uniform float open_amt = 1.0;
uniform float power = 1.0;

varying vec2 p;

void vertex() {
	p = VERTEX.xy;
}

void fragment() {
	float rr0 = length(p) * 2.0; // 0 no centro, ~1 na borda (quad de lado 2R)
	if (rr0 > open_amt) {
		discard;
	}
	float t = TIME;
	vec3 c;
	float a;
	if (pattern == 0) {
		vec2 uv = p * cells * 0.5 + vec2(t * 0.15, 0.0);
		vec2 f = fract(uv);
		float chk = mod(floor(uv.x) + floor(uv.y), 2.0);
		vec2 g = abs(f - 0.5);
		float edge = smoothstep(0.5 - line_w, 0.5, max(g.x, g.y));
		c = mix(col_a.rgb * 0.4, col_b.rgb * 0.7, chk) + col_b.rgb * edge * 1.3;
		a = 0.10 + 0.30 * chk + 0.5 * edge;
	} else {
		float rr = rr0 * cells * 0.5 - t * 0.5;
		float fr = fract(rr);
		float ring = smoothstep(0.1, 0.0, min(fr, 1.0 - fr));
		float lon = atan(p.y, p.x) / 6.2831853;
		float sp = fract(lon * 24.0);
		float spoke = smoothstep(0.05, 0.0, min(sp, 1.0 - sp));
		float chk = mod(floor(rr) + floor(lon * 24.0), 2.0);
		float edge = max(ring, spoke);
		c = mix(col_a.rgb * 0.4, col_b.rgb * 0.7, chk) + col_b.rgb * edge * 1.4;
		a = 0.10 + 0.30 * chk + 0.5 * edge;
	}
	float edge_ring = smoothstep(0.06, 0.0, abs(rr0 - open_amt * 0.97));
	a = a * smoothstep(1.0, 0.8, rr0) + edge_ring * 1.0;
	c += col_b.rgb * edge_ring * 1.5;
	ALBEDO = c * power;
	ALPHA = clamp(a, 0.0, 1.0) * power;
}
