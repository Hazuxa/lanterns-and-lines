shader_type canvas_item;
// Title sways like the grass: the whole picture leans left/right as ONE piece
// (bottom stays put, top moves), plus a tiny bob. Only moves the 4 corners = super cheap.

uniform float bend = 0.035;        // how far it leans (0.035 = top moves 3.5% of its height)
uniform float bend_speed = 1.0;    // how fast it sways
uniform float wobble = 0.35;       // extra little back-and-forth so it isn't a perfect pendulum
uniform float bob_px = 1.0;        // gentle up/down float (pixels)

varying vec4 tint;

void vertex() {
	tint = COLOR;                                         // keeps the fade-in working
	float t = TIME * bend_speed;
	float lean = (sin(t) + sin(t * 2.3 + 1.0) * wobble) * bend;
	float height = (1.0 - UV.y) / TEXTURE_PIXEL_SIZE.y;  // 0 at the bottom edge, full height at the top
	VERTEX.x += lean * height;                            // only the top moves sideways
	VERTEX.y += sin(t * 1.3) * bob_px;                    // whole title floats a little
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * tint;
}