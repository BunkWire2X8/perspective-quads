shader_type canvas_item;

uniform float time_scale : hint_range(0.0, 10.0) = 1.0;
uniform float bar_count : hint_range(1.0, 32.0) = 8.0;

#include "includes/perspective_uniforms.gdshaderinc"
#include "includes/perspective_math.gdshaderinc"
#include "includes/perspective_aa.gdshaderinc"

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
	VERTEX = VERTEX * frame_size + plane_size * frame_offset + origin_offset;
}

vec3 test_pattern(vec2 uv, float t) {
	// Scrolling SMPTE-style color bars
	float shifted = fract(uv.x + t * 0.05);
	float bar = floor(shifted * bar_count);
	float hue = bar / bar_count;
	
	vec3 col = vec3(
		abs(hue * 6.0 - 3.0) - 1.0,
		2.0 - abs(hue * 6.0 - 2.0),
		2.0 - abs(hue * 6.0 - 4.0)
	);
	col = clamp(col, 0.0, 1.0);
	
	// Pulsing scanline sweep
	float sweep = smoothstep(0.0, 0.02, abs(fract(uv.y - t * 0.2) - 0.5) - 0.48);
	col *= mix(0.6, 1.0, sweep);
	
	// Thin moving center line
	float line = smoothstep(0.004, 0.0, abs(uv.y - fract(t * 0.15)));
	col = mix(col, vec3(1.0), line);
	
	return col;
}

void fragment() {
	vec2 pUV = mult_mat_inv_point(matrix_inv, UV * frame_size + frame_offset);
	float coverage = edge_coverage(pUV);
	if (coverage <= 0.0) discard;
	
	vec2 texUV = mix(pUV, 1.0 - pUV, flip_vector);
	vec3 pattern = test_pattern(texUV, TIME * time_scale);
	COLOR = vec4(pattern, 1.0) * vertex_color;
	COLOR.a *= coverage;
}