// PerspectiveQuad2D - Math Helpers
vec2 mult_mat_inv_point(mat3 mat_inv, vec2 point) {
	vec3 result = mat_inv * vec3(point, 1.0);
	return vec2(result.x / result.z, result.y / result.z);
}