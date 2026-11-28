shader_type canvas_item;
render_mode unshaded;

global uniform float wind_time;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// these get copied from the CloudShadows material automatically (keep defaults the same)
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float scale = 0.0008;
uniform vec2 direction = vec2(1.0, 0.35);
uniform float speed = 5.0;
uniform float coverage = 0.3;
uniform float softness = 0.14;

uniform float cloud_fade = 0.75;    // how much shadows fade under a cloud (0 = none, 1 = gone)

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec2 cc_cell = floor(wpos);
	vec2 uv = (cc_cell + normalize(direction) * wind_time * speed) * scale;
	float v = texture(noise, uv).r * 0.9 + texture(noise, uv * 2.3 + 0.37).r * 0.1;
	float cloud = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, v);
	c.a *= 1.0 - cloud * cloud_fade;
	COLOR *= c;
}