shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, depth_draw_opaque;

// 方块模型：图集纹理 × UV2 索引的调色板纹理。
// 不使用顶点色，避免部分 Android GLES/ANGLE 驱动的通道顺序问题。

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D palette_tex : filter_nearest;

void fragment() {
	vec4 base = texture(albedo_tex, UV);
	vec4 tint = texture(palette_tex, vec2(clamp(UV2.x, 0.0, 1.0), 0.5));
	ALBEDO = base.rgb * tint.rgb;
	ALPHA = 1.0;
}
