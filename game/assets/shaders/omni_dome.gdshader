shader_type spatial;
// Dimensão Omnisférica (Metavisão): cúpula quadriculada (ou radial) que se abre do chão ao topo.
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;

uniform vec4 col_a : source_color = vec4(0.1, 0.2, 0.6, 1.0);
uniform vec4 col_b : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float cells = 14.0;
uniform float line_w = 0.07;
uniform int pattern = 0;      // 0 = quadriculado, 1 = radial (anéis + raios, "centro")
uniform float open_amt = 1.0; // 0..1 revela de baixo para cima
uniform float power = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 d = normalize(lp);
	if (d.y < -0.02) {
		discard;
	}
	float lat = asin(clamp(d.y, -1.0, 1.0)) / 1.5707963;
	if (lat > open_amt * 1.02) {
		discard;
	}
	float lon = atan(d.z, d.x) / 6.2831853;
	float t = TIME;
	vec3 c;
	float a;
	if (pattern == 0) {
		vec2 uv = vec2((lon + t * 0.015) * cells * 2.0, (lat + t * 0.02) * cells);
		vec2 f = fract(uv);
		float chk = mod(floor(uv.x) + floor(uv.y), 2.0);
		vec2 g = abs(f - 0.5);
		float edge = smoothstep(0.5 - line_w, 0.5, max(g.x, g.y));
		c = mix(col_a.rgb * 0.5, col_b.rgb * 0.75, chk) + col_b.rgb * edge * 1.4;
		a = 0.10 + 0.28 * chk + 0.5 * edge;
	} else {
		float r = acos(clamp(d.y, -1.0, 1.0)) / 1.5707963;
		float rr = r * cells * 0.5 - t * 0.35;
		float fr = fract(rr);
		float ring = smoothstep(0.1, 0.0, min(fr, 1.0 - fr));
		float sp = fract(lon * 24.0);
		float spoke = smoothstep(0.05, 0.0, min(sp, 1.0 - sp));
		float chk = mod(floor(rr) + floor(lon * 24.0), 2.0);
		float edge = max(ring, spoke);
		c = mix(col_a.rgb * 0.5, col_b.rgb * 0.75, chk) + col_b.rgb * edge * 1.5;
		a = 0.10 + 0.28 * chk + 0.5 * edge;
	}
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float rim = smoothstep(0.14, 0.0, lat);
	float front = smoothstep(0.07, 0.0, abs(lat - open_amt));
	a += fres * 0.55 + rim * 1.0 + front * 0.9;
	c += col_b.rgb * (fres * 0.8 + rim * 1.2 + front * 1.2);
	a *= mix(0.65, 1.0, smoothstep(0.0, 0.5, lat));
	ALBEDO = c * power;
	ALPHA = clamp(a, 0.0, 1.0) * power;
}
