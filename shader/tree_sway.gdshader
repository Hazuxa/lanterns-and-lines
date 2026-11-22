shader_type canvas_item;
// Wind sway for trees (and their shadows). The Wind node controls how strong it is.

global uniform float wind_strength;   // set by wind.gd (changes with time of day + gusts)
global uniform float wind_time;       // set by wind.gd (keeps the sway smooth when speed changes)

uniform float sway_px = 1.5;        // sway at normal wind (pixels)
uniform float flutter_px = 0.6;     // leaf ripple at normal wind (pixels)
uniform float still_part = 0.3;     // bottom part that never moves (the trunk)

varying float phase;
varying vec4 tint;

void vertex() {
	tint = COLOR;
	phase = MODEL_MATRIX[3].x * 0.071 + MODEL_MATRIX[3].y * 0.037;
}

void fragment() {
	float h = 1.0 - UV.y;
	float bend = smoothstep(still_part, 1.0, h);
	float wave = sin(wind_time + phase) * sway_px * wind_strength * bend * bend
	           + sin(wind_time * 2.9 + UV.y * 18.0 + phase * 2.0) * flutter_px * wind_strength * bend;
	vec4 c = texture(TEXTURE, UV - vec2(wave * TEXTURE_PIXEL_SIZE.x, 0.0));
	COLOR = c * tint;
}