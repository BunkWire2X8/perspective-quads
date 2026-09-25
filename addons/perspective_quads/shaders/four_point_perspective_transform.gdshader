shader_type canvas_item;

#include "includes/perspective_uniforms.gdshaderinc"
#include "includes/perspective_math.gdshaderinc"
#include "includes/perspective_aa.gdshaderinc"

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
	VERTEX = VERTEX * frame_size + plane_size * frame_offset + origin_offset;
}

void fragment() {
	vec2 pUV = mult_mat_inv_point(matrix_inv, UV * frame_size + frame_offset);
	float coverage = edge_coverage(pUV);
	if (coverage <= 0.0) discard;
	
	vec2 texUV = mix(pUV, 1.0 - pUV, flip_vector);
	vec2 marginUV = (texUV - atlas_margin_rect.xy) / atlas_margin_rect.zw;
	coverage *= edge_coverage(marginUV);
	if (coverage <= 0.0) discard;
	
	vec2 inset = atlas_texel_size * 0.5;
	vec2 region_min = atlas_region.xy + inset;
	vec2 region_max = atlas_region.xy + atlas_region.zw - inset;
	vec2 sample_uv = clamp(atlas_region.xy + marginUV * atlas_region.zw, region_min, region_max);
	COLOR = textureLod(TEXTURE, sample_uv, 0.0) * vertex_color;
	COLOR.a *= coverage;
}