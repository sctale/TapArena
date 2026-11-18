shader_type spatial;
render_mode cull_disabled, specular_disabled;

// 方块模型：图集纹理 × UV2 索引的调色板纹理，接受实时太阳光与阴影。
// 不使用顶点色，避免部分 Android GLES/ANGLE 驱动的通道顺序问题。
// 不写 ALPHA：一旦写 ALPHA，Godot 会把整个模型归入透明队列（不写深度、按物体排序），
// 背面会透出正面的脸、身体各部件也会互相透叠。角色/建筑/野怪全部走这个不透明着色器，
// 需要半透明的物体（技能圈、建筑遮挡）另用 _alpha_material / voxel_fade.gdshader。

uniform sampler2D albedo_tex : filter_nearest, repeat_enable;
uniform sampler2D palette_tex : filter_nearest;

void fragment() {
	vec4 base = texture(albedo_tex, UV);
	vec4 tint = texture(palette_tex, vec2(clamp(UV2.x, 0.0, 1.0), 0.5));
	ALBEDO = base.rgb * tint.rgb;
}
