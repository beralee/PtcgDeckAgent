shader_type spatial;
render_mode unshaded, cull_disabled;

// glTF COLOR_0 stores linear values. Compatibility renders directly in sRGB,
// so convert once per vertex rather than losing the authored palette in shadows.
void vertex() {
	if (OUTPUT_IS_SRGB) {
		vec3 linear_color = max(COLOR.rgb, vec3(0.0));
		COLOR.rgb = mix(12.92 * linear_color,
			1.055 * pow(linear_color, vec3(1.0 / 2.4)) - 0.055,
			step(vec3(0.0031308), linear_color));
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
