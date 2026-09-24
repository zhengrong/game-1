shader_type canvas_item;
render_mode unshaded, blend_mix;
// Data: mode + arc angle, simulation age, strength, opacity. No wall-clock TIME.
varying vec4 shield;
uniform bool hdr_canvas = true;
void vertex() {
	shield = COLOR;
	// HDR canvas converts vertex RGB from sRGB; restore numeric draw parameters.
	if (hdr_canvas) {
		shield.rgb = mix(12.92 * COLOR.rgb, 1.055 * pow(max(COLOR.rgb, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), COLOR.rgb));
	}
}
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * 1.2;
	float r = length(p);
	float angle = atan(p.x, -p.y);
	float inside = 1.0 - smoothstep(0.99, 1.01, r);
	float edge = exp(-pow((r - 1.0) / 0.018, 2.0));
	float halo = exp(-pow((r - 1.0) / 0.075, 2.0));
	float age = shield.g;
	vec3 tint = vec3(0.18, 0.58, 1.3);
	float alpha;
	float light;
	if (shield.r < 0.5) {
		// Rounded membrane: interior stays transparent, grazing angles catch light.
		float fresnel = pow(clamp(r, 0.0, 1.0), 5.0) * inside;
		float sweep = pow(max(0.0, cos(angle - age * 0.7 - 0.5)), 12.0);
		alpha = inside * 0.035 + fresnel * 0.25 + halo * 0.15 + edge * 0.48;
		light = 0.5 + fresnel * 0.5 + edge * 0.7 + sweep * fresnel;
	} else {
		tint = shield.b >= 0.5 ? vec3(0.58, 0.23, 1.15) : (shield.b >= 0.166667 ? vec3(1.15, 0.13, 0.48) : vec3(1.3, 0.07, 0.12));
		float sweep = pow(max(0.0, cos(angle * 2.0 - age * 1.5)), 14.0);
		float front = exp(-pow((r - min(1.0, age / 0.25)) / 0.035, 2.0)) * (1.0 - smoothstep(0.0, 0.25, age));
		alpha = inside * 0.018 + halo * 0.16 + edge * 0.58 + front * 0.28;
		light = 0.5 + edge * (0.6 + sweep * 0.5) + front;
		if (shield.r >= 2.0) {
			float half_angle = fract(shield.r) * 3.14159265;
			float arc = 1.0 - smoothstep(half_angle - 0.04, half_angle, abs(angle));
			float panel = smoothstep(0.73, 0.94, r) * inside;
			alpha = (panel * 0.4 + halo * 0.2 + edge * 0.65 + front * panel * 0.35) * arc;
			light += panel * 0.35;
		}
	}
	COLOR = vec4(tint * light + vec3(edge * 0.28), clamp(alpha * shield.a, 0.0, 0.92));
}
