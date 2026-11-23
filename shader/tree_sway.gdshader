shader_type canvas_item;
// Tree wind (optimized): the crown bends gently, the trunk never moves.
// Heavy math runs ONCE per tree (vertex), each pixel only does a tiny bit of work.

global uniform float wind_strength;
global uniform float wind_time;

uniform float leaves_start = 0.35;   // where the leaves begin, from the bottom (0-1)
uniform float bend_px = 1.5;         // how far the top of the crown bends (pixels)
uniform float bend_speed = 0.6;      // speed of the sway
uniform float wave_px = 0.3;         // soft wave across the crown (0 = off)
uniform float wave_speed = 1.0;
uniform float breathe_px = 0.3;      // crown gently rising/settling (pixels)

varying vec4 tint;
varying float v_sway;      // these are worked out once per tree, in vertex()
varying float v_breathe;
varying float v_wave_t;

void vertex() {
	tint = COLOR;
	float t = wind_time + MODEL_MATRIX[3].x * 0.071 + MODEL_MATRIX[3].y * 0.037;
	v_sway = (sin(t * bend_speed) + 0.35 * sin(t * bend_speed * 2.3 + 1.0)) * bend_px * wind_strength;
	v_breathe = (0.5 + 0.5 * sin(t * bend_speed * 1.3 + 2.0)) * breathe_px * wind_strength;
	v_wave_t = t * wave_speed;
}

void fragment() {
	float m = clamp((1.0 - UV.y - leaves_start) / (1.0 - leaves_start), 0.0, 1.0);
	float wave = sin(v_wave_t - UV.x * 6.0) * wave_px * wind_strength;
	vec2 d = vec2(v_sway * m * m + wave * m, -v_breathe * m);
	COLOR = texture(TEXTURE, UV - d * TEXTURE_PIXEL_SIZE) * tint;
}