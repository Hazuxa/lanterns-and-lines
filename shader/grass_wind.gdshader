shader_type canvas_item;

global uniform float wind_strength;
global uniform float wind_time;
global uniform vec2 player_pos;
global uniform vec2 grass_push;
global uniform vec3 ff_light0;
global uniform vec3 ff_light1;
global uniform vec3 ff_light2;
global uniform vec3 ff_light3;

uniform float bend = 0.12;          // wind (same as your original)
uniform float bend_speed = 1.2;
uniform float gust_wobble = 0.35;
uniform float push_radius = 20.0;   // player push
uniform float push_strength = 0.12;
uniform float drag = 0.05;
uniform float max_push = 0.12;
uniform float ff_radius = 18.0;     // how far a firefly lights the grass
uniform float ff_strength = 0.35;   // how bright the grass gets
uniform vec3 ff_color = vec3(0.85, 1.0, 0.5);

varying vec4 tint;
varying vec2 wpos;

float ff(vec3 L, vec2 p) {
	if (L.z <= 0.0) { return 0.0; }
	return L.z * (1.0 - smoothstep(0.0, ff_radius, distance(p, L.xy)));
}

void vertex() {
	tint = COLOR;
	float height = max(-VERTEX.y, 0.0);
	vec2 base = MODEL_MATRIX[3].xy;

	float t = wind_time * bend_speed + base.x * 0.07 + base.y * 0.03;
	float lean = (sin(t) + gust_wobble * sin(t * 2.7 + 1.3)) * bend * wind_strength;

	vec2 d = base - player_pos;
	float touch = 1.0 - smoothstep(0.0, push_radius, length(d));
	float push = (clamp(d.x * 0.2, -1.0, 1.0) * push_strength + grass_push.x * drag) * touch;
	lean += clamp(push, -max_push, max_push);

	VERTEX.x += lean * height;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * tint;
	float l = ff(ff_light0, wpos) + ff(ff_light1, wpos) + ff(ff_light2, wpos) + ff(ff_light3, wpos);
	c.rgb += ff_color * min(l, 1.0) * ff_strength * c.a;
	COLOR = c;
}