shader_type canvas_item;
// Grass that BENDS as one piece in the wind (the whole texture leans, the base stays planted).
// Follows the Wind node, like the trees.
// The grass's origin must be at the BOTTOM of the picture (your tall grass already is).

global uniform float wind_strength;   // from wind.gd
global uniform float wind_time;       // from wind.gd

uniform float bend = 0.12;           // how far it leans (0.12 = top moves 12% of its height)
uniform float bend_speed = 1.2;      // how fast it sways
uniform float gust_wobble = 0.35;    // extra little back-and-forth on top of the sway
uniform float squash = 0.25;         // shrinks a little when it leans, so blades look like they bend

varying vec4 v_color;

void vertex() {
	v_color = COLOR;
	// each clump has its own timing from where it stands
	float phase = MODEL_MATRIX[3].x * 0.09 + MODEL_MATRIX[3].y * 0.05;
	float t = wind_time * bend_speed + phase;
	float lean = (sin(t) + sin(t * 2.3 + 1.0) * gust_wobble) * bend * wind_strength;

	// VERTEX.y is 0 at the base and negative going up: only the top moves
	float height = -VERTEX.y;
	VERTEX.x += lean * height;
	VERTEX.y += abs(lean) * squash * height;     // dips a little while leaning
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * v_color;
}