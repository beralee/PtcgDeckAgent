shader_type canvas_item;
// Feather only the atlas-cell perimeter so authored glows never end in a hard box.
void fragment() {
	vec2 cell = fract(UV * vec2(3.0, 2.0));
	vec2 edge = min(cell, vec2(1.0)-cell);
	float feather = smoothstep(0.0, 0.035, edge.x) * smoothstep(0.0, 0.025, edge.y);
	COLOR.a *= feather;
}
