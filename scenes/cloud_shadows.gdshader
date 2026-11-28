shader_type canvas_item;
render_mode blend_mul, unshaded;

global uniform float wind_time;

const float CLOUD_PIXEL = 1.0;                  // 1 = one game pixel (smooth but on the grid)

uniform sampler2D noise : repeat_enable, filter_linear;
uniform float scale = 0.0008;                   // smaller = bigger clouds
uniform vec2 direction = vec2(1.0, 0.35);       // which way the clouds drift
uniform float speed = 5.0;                      // drift speed (uses your wind)
uniform float coverage = 0.3;                   // how much of the ground is shaded (0-1)
uniform float softness = 0.14;                  // how soft the cloud edges fade

uniform vec3 day_shadow = vec3(0.90, 0.91, 0.97);    // daytime shadow colour (light, cool)
uniform vec3 night_shadow = vec3(0.72, 0.76, 0.95);  // night: soft blue
uniform float night_amount = 0.3;               // how visible at night (0.2-0.4 = barely)
uniform float night = 0.0;                      // set by the script (0 day -> 1 night)

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 cc_logical = wpos;
	vec2 cc_cell = floor(cc_logical / CLOUD_PIXEL);          // snap to game pixels
	vec2 uv = (cc_cell * CLOUD_PIXEL + normalize(direction) * wind_time * speed) * scale;
	float v = texture(noise, uv).r * 0.9 + texture(noise, uv * 2.3 + 0.37).r * 0.1;
	float c = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, v);

	vec3 col = mix(day_shadow, night_shadow, night);
	float amount = mix(1.0, night_amount, night);
	COLOR = vec4(mix(vec3(1.0), col, c * amount), 1.0);
}