// PerspectiveQuad2D - Uniform Declarations

// Precomputed by PerspectiveQuad2D/PerspectiveQuadShape
group_uniforms PerspectiveMath;
uniform mat3 matrix_inv;
uniform vec2 frame_size = vec2(1.0);
uniform vec2 frame_offset = vec2(0.0);
uniform vec2 plane_size;

// Sprite2D-style placement (centered/offset) and mirroring (flip_h/flip_v)
group_uniforms OffsetAndFlipping;
uniform vec2 origin_offset = vec2(0.0);
uniform vec2 flip_vector = vec2(0.0);

// Texture atlas support
group_uniforms TextureAtlases;
uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 atlas_texel_size = vec2(0.0);
uniform vec4 atlas_margin_rect = vec4(0.0, 0.0, 1.0, 1.0);

// Antialiasing
group_uniforms Antialiasing;
uniform bool antialiased = false;