# 抛硬币皮肤变体设计

## 背景

战斗抛硬币动画当前固定使用 `assets/ui/coin_heads.png` 和 `assets/ui/coin_tails.png`。这和 VSTAR 标记的多图随机体验不一致，也让开场抛硬币和卡牌效果抛硬币缺少变化。

本设计目标是增加多套硬币外观，但不改变任何游戏规则、随机结果、replay 或 AI 行为。

## 设计原则

- 抛硬币结果仍由 `CoinFlipper` 产生，UI 皮肤随机不能影响正反面概率。
- 每个 `CoinFlipAnimator` 实例只随机选择一次硬币皮肤，一局战斗内保持稳定。
- 每套皮肤必须同时提供正面和反面资源。
- 资源采用显式注册，不运行时扫描目录，避免导出包漏资源。
- 默认旧硬币保留为 fallback，任何变体加载失败时都能继续显示。
- 现有竖屏尺寸自适应和最高图层逻辑不变。

## 资源规范

硬币资源放在 `assets/ui/coins/`：

- `coin_neon_heads.png`
- `coin_neon_tails.png`
- `coin_starlight_heads.png`
- `coin_starlight_tails.png`
- `coin_terra_heads.png`
- `coin_terra_tails.png`

推荐图片规格：

- 正方形 PNG。
- 透明背景。
- 主体居中，边缘留少量安全边距。
- 正反面尺寸一致或接近一致。

## 运行机制

`CoinFlipAnimator` 持有一个显式皮肤注册表。默认旧硬币使用现有 preload，新增硬币使用显式路径懒加载，避免新增 PNG 尚未导入时让脚本编译失败：

```gdscript
const COIN_SKIN_VARIANTS := [
	{"id": "default", "heads": preload(...), "tails": preload(...)},
	{"id": "neon", "heads_path": "res://...", "tails_path": "res://..."},
]
```

初始化流程：

1. `_ready()` 调用 `_select_coin_skin_once()`。
2. 如果外部测试已经设置了皮肤索引，则使用测试指定值。
3. 否则随机选择一个皮肤。
4. 若选中皮肤缺少正反面贴图，则回退默认硬币。

播放流程：

1. `play(result)` 不重新随机皮肤。
2. 动画压扁硬币时只在当前皮肤的正反面贴图之间切换。
3. 最后根据 `result` 停在正面或反面。

## 测试计划

- 验证皮肤注册表内每套硬币都包含正反面贴图。
- 验证同一个 animator 多次播放不会重新随机换皮肤。
- 验证指定皮肤索引后，正反面切换仍使用该皮肤的贴图。
- 保留竖屏尺寸测试，确保资源变体不影响布局。
- 保留最高图层测试，确保开场抛硬币不被遮挡。
