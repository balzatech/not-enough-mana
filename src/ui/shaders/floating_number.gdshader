shader_type canvas_item;
// Número flotante (V2-18) para un Label: velo de brillo vertical.
// El contorno legible lo da el tema (variaciones FloatDamage/FloatHeal: outline_size 10),
// porque un contorno por shader sobre el atlas de glifos sangra entre glifos.
// Compatibility/WebGL2: solo canvas_item.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// COLOR ya es color de vertice (font_color / outline) * glifo.
	float shine = 1.0 + 0.3 * (0.5 - UV.y);
	COLOR = vec4(COLOR.rgb * shine, COLOR.a * fade);
}
