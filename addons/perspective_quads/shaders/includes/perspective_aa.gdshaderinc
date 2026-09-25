// PerspectiveQuad2D - Edge Coverage / Antialiasing

float edge_coverage(vec2 uv) {
	if (!antialiased)
		return float(uv.x <= 1.0 && uv.y <= 1.0 && uv.x >= 0.0 && uv.y >= 0.0);
	
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec2 fw = vec2(length(vec2(dx.x, dy.x)), length(vec2(dx.y, dy.y)));
	
	fw = clamp(fw, vec2(1e-5), vec2(0.25));
	
	vec2 lo = smoothstep(-fw, fw, uv);
	vec2 hi = smoothstep(-fw, fw, vec2(1.0) - uv);
	return lo.x * lo.y * hi.x * hi.y;
}