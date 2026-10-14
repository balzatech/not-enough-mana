shader_type canvas_item;
// Destello/tinte de panel (V2-18). Para un ColorRect superpuesto al panel.
// Compatibility/WebGL2: solo canvas_item, sin hint_screen_texture ni features de Forward+.
// Daño (hatched=true): rayado diagonal + borde recto => forma angular.
// Curación (hatched=false): halo radial suave => forma redondeada.
// Animar `amount` de 0 a 1 y de vuelta con un Tween.
uniform vec4 tint : source_color = vec4(1.0, 0.32, 0.12, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform bool hatched = true;
uniform float stripe_px = 18.0;
// Tamaño del ColorRect en px (un ColorRect no tiene textura: TEXTURE_PIXEL_SIZE no sirve).
uniform vec2 rect_size = vec2(240.0, 200.0);

void fragment() {
	vec2 sz = rect_size;
	vec2 px = UV * sz;
	float edge = min(min(UV.x, 1.0 - UV.x) * sz.x, min(UV.y, 1.0 - UV.y) * sz.y);
	float a;
	if (hatched) {
		float s = step(0.5, fract((px.x + px.y) / stripe_px));
		a = mix(0.18, 0.45, s) + step(edge, 8.0) * 0.4;
	} else {
		vec2 d = (UV - 0.5) * 2.0;
		a = 0.15 + 0.45 * smoothstep(0.3, 1.1, length(d));
	}
	COLOR = vec4(tint.rgb, clamp(a, 0.0, 1.0) * amount * tint.a);
}
