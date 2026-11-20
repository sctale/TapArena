# SPEC — 修新英雄模型缩放 + 首页连续惯性滚动

状态：已修复（4.24.1 / code 67）
日期：2026-11-20
版本目标：4.24.1 / versionCode 67

用户反馈：

1. 新英雄建模尺寸不对；
2. 首页英雄上下滑动不流畅，希望改成王者荣耀那种连贯滚动。

## 1. 新英雄尺寸

### 根因

`battle_view._hero_scale()` 用 `u.height / HERO_DESIGN_H[hero_id]` 计算比例。
旧的 15 位都在 `HERO_DESIGN_H` 里写死 88，5 位新英雄漏登记，走了默认值 **76**，
于是 5 人整体被放大 `88/76 = 1.158` 倍（阿象更夸张，100/76 = 1.316）。

### 改动

- `HERO_DESIGN_H` 补 `monkey / elephant / penguin / sheep / bat = 88.0`。
- 缩放回到统一基准：阿跳 0.89、阿吨 1.14、冰冰 0.82、云朵 1.00、夜羽 0.84。
- `_check_roster_art` 增加「20 人都有设计身高」断言。

## 2. 首页连续滚动

### 根因

上一版按整排吸附（`round(scroll/row)`），手指拖动像翻页，不是连续滚动；
部分露出的卡片只画空底板，观感也像卡住。

### 改动

- 网格卡片移到独立的 **裁剪画布**：父 Control `clip_contents=true`，
  子 CanvasItem 用 `position.y = -grid_scroll` 整体平移；滚动时只移动画布，
  不重画 20 张卡。视口外的卡片由裁剪层自然切掉。
- 删除整排吸附；拖动时 `grid_scroll` 连续跟手，同时记录速度。
  松手后 `_process` 里做指数减速（`scroll_velocity *= exp(-6δ)`），
  到顶/到底或速度 <10px/s 停止。
- 卡片名字改成画布内 `draw_string`，和卡片一起滚动，不再出现标签浮层。
- 右侧滚动条改成固定的 `ColorRect` 轨道/滑块，随滚动实时更新。
- 详情弹窗打开时隐藏裁剪画布与滚动条，背景不会穿透。
- 调试参数 `--grid-bottom` 仍可直接滚到底。

## 验收

- [x] `_check_roster_art`：20 人都有 88 的设计身高；`ROSTER_OK`
- [x] `flow_headless`：小幅拖动后 `grid_scroll` 不是整排倍数（连续滚动），大拖动可到底；`FLOW_OK`
- [x] 桌面截图：默认两排、`--grid-bottom` 四排底部、详情弹窗无穿帮
- [x] 模拟器滑动：连续跟手/惯性，部分卡片由裁剪层切边
- [x] APK 4.24.1 / code 67 校验、真机跑通
