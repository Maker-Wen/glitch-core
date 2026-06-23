shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	vec2 centered = UV - vec2(0.5, 0.5);
	float angle = atan(centered.y, centered.x) + 1.57079632679;
	if (angle < 0.0) {
		angle += 6.28318530718;
	}
	float fill = clamp(progress, 0.0, 1.0) * 6.28318530718;
	if (angle > fill) {
		color.a = 0.0;
	}
	COLOR = color;
}
