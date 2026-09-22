shader_type canvas_item;
// Alpha-composited emission preserves orange structure where flames overlap.
// HDR highlights still bloom; accumulating additive sprites erased all detail.
render_mode unshaded, blend_mix;
// Vertex color carries age, seed, burst mode and cooling energy.
// Deliberately independent of TIME for paused and captured frames.
varying vec4 effect;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x), mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}
float flow(vec2 p) {
	return noise(p) * 0.58 + noise(p * 2.03 + 8.3) * 0.29 + noise(p * 4.07 + 2.1) * 0.13;
}
void vertex() { effect = COLOR; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (effect.b > 1.5) {
		// A thin luminous boundary over a broader translucent spherical shell.
		float radius = length(p) + (noise(p * 6.0 + effect.r * 1.2) - 0.5) * 0.012;
		float shell = exp(-pow((radius - 0.77) / 0.10, 2.0));
		float rim = exp(-pow((radius - 0.79) / 0.020, 2.0));
		float interior = (1.0 - smoothstep(0.55, 0.80, radius)) * 0.045;
		float reveal = smoothstep(0.0, 0.13, effect.r);
		float fade = pow(1.0 - effect.r, 1.6) * reveal;
		vec3 tint = mix(vec3(1.5, 0.68, 0.20), vec3(1.5, 1.2, 0.83), clamp(-p.y + 0.3, 0.0, 1.0));
		if (effect.g > 1.5) {
			tint = mix(vec3(0.12, 0.6, 1.6), vec3(1.0, 1.7, 2.0), clamp(-p.y + 0.3, 0.0, 1.0));
		} else if (effect.g > 0.5) {
			tint = mix(vec3(0.9, 0.5, 0.65), vec3(1.4, 1.0, 1.6), clamp(-p.y + 0.3, 0.0, 1.0));
		}
		COLOR = vec4(tint, (shell * 0.24 + rim * 0.25 + interior) * fade * effect.a);
	} else {
	vec2 travel = vec2(effect.g * 7.1, effect.r * 2.8);
	float curl = flow(p * 2.5 + travel);
	vec2 warped = p + vec2(curl - 0.5, noise(p * 3.0 - travel) - 0.5) * 0.32;
	float turbulence = flow(warped * 4.0 + travel);
	float taper = mix(0.76, 1.95, smoothstep(-0.65, 0.85, p.y));
	vec2 shape = warped * vec2(mix(taper, 1.0, effect.b), mix(0.85, 1.0, effect.b));
	float body = 1.0 - length(shape) * 1.42 + (turbulence - 0.5) * 0.95;
	// Rolling lobes and advected hot channels, not a uniformly white disc.
	float fingers = sin(p.x * 12.0 + curl * 5.0 + effect.g) * sin(p.y * 8.0 - effect.r * 5.0);
	body += fingers * 0.18 * smoothstep(0.2, 0.9, length(p));
	body -= (1.0 - effect.a) * smoothstep(0.52, 0.75, turbulence) * 0.35;
	float edge = smoothstep(0.0, 0.22, body);
	float channels = flow(warped * 7.0 + travel * vec2(0.8, 1.6));
	float hot = smoothstep(0.30, 0.72, body + (channels - 0.5) * 0.65);
	float white_core = smoothstep(0.48, 0.85, body + (channels - 0.5) * 0.4);
	vec3 flame = mix(vec3(0.95, 0.075, 0.005), vec3(1.65, 0.62, 0.018), smoothstep(0.04, 0.38, body));
	flame = mix(flame, vec3(2.1, 1.65, 0.22), hot);
	flame = mix(flame, vec3(3.0, 2.85, 2.1), white_core * effect.a);
	// Darker cooling folds separate the lobes while fresh channels remain luminous.
	flame *= mix(0.62, 1.0, smoothstep(0.25, 0.65, channels));
	float boundary = 1.0 - smoothstep(0.87, 1.0, max(abs(p.x), abs(p.y)));
	COLOR = vec4(flame, edge * effect.a * boundary * 0.92);
	}
}
