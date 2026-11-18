shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;

// 与 voxel.gdshader 相同的调色板着色（接受实时光照），但支持建筑遮挡时「挖空」。
// 注意：一个建筑由很多盒子叠成，alpha 混合会让多层透明度相乘（0.45³≈0.09），
// 后面的角色几乎完全看不见。这里改用 4×4 Bayer 抖动：按屏幕像素裁剪，
// 各层在同一个像素上同时保留或同时丢弃，角色能从稳定的缝隙里透出来。

uniform sampler2D albedo_tex : filter_nearest, repeat_enable;
uniform sampler2D palette_tex : filter_nearest;
// 0 = 完全不透明；1 = 完全裁掉。0.7 大约保留 30% 像素。
uniform float fade : hint_range(0.0, 1.0) = 0.0;

int bayer2(int x, int y) {
	if (x == 0) {
		return y == 0 ? 0 : 2;
	}
	return y == 0 ? 3 : 1;
}

int bayer4(int x, int y) {
	return 4 * bayer2(x / 2, y / 2) + bayer2(x % 2, y % 2);
}

void fragment() {
	vec4 base = texture(albedo_tex, UV);
	vec4 tint = texture(palette_tex, vec2(clamp(UV2.x, 0.0, 1.0), 0.5));
	ALBEDO = base.rgb * tint.rgb;
	ALPHA = 1.0;

	int px = int(mod(floor(FRAGCOORD.x), 4.0));
	int py = int(mod(floor(FRAGCOORD.y), 4.0));
	float threshold = (float(bayer4(px, py)) + 0.5) / 16.0;
	if (fade > threshold) {
		discard;
	}
}
