shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, blend_mix, depth_draw_never;

// 与 voxel.gdshader 相同的调色板着色，但支持整件模型淡出（玩家躲到建筑后方时使用）。

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D palette_tex : filter_nearest;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 base = texture(albedo_tex, UV);
	vec4 tint = texture(palette_tex, vec2(clamp(UV2.x, 0.0, 1.0), 0.5));
	ALBEDO = base.rgb * tint.rgb;
	ALPHA = fade;
}
