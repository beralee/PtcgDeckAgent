# Deck Share Poster Core Design

本文是“卡组分享图”功能的核心产品与技术设计文档，合并并取代以下两份草案：

- `2026-07-05-deck-share-poster-import-design.md`
- `2026-07-05-deck-share-poster-tech-research.md`

## 目标

把每套本地卡组变成一张可以传播、可以收藏、可以被游戏识别导入的竖屏图片。

第一版不做完整社区，不做账号系统，不做公开排行榜。核心只验证一条确定的传播闭环：

```text
玩家本地卡组
  -> 生成卡组分享图
  -> 图片带完整卡组编号数据
  -> 玩家把图片发到群聊/社交平台
  -> 另一个玩家在游戏里选择/扫描这张图
  -> 游戏还原卡组并保存到本地
```

产品标准：

> 卡组图片既是传播素材，也是可导入的卡组包。

## 产品原则

1. **先做传播图，不做社区**
   - 不引入账号、评论、审核、排行榜。
   - 让玩家先能把自己的卡组以图片形式发出去。

2. **图片必须可导入**
   - 分享图不是普通截图。
   - 图中必须包含完整、可校验、可恢复的卡组数据。

3. **数据不依赖服务器**
   - 第一版导出和导入都应离线可用。
   - 后续可以把短码、云端收录、热门卡组中心作为增强。

4. **导入必须安全**
   - 图片数据按不可信输入处理。
   - 不自动覆盖本地卡组。
   - 不从图片内任意 URL 下载外部资源。

5. **技术先稳定，视觉后增强**
   - 第一版模板可以简单，但布局、横向导入码、导入链路必须稳定。
   - 后续再做精美背景模板、多风格海报和运营素材。

## 非目标

第一版不包括：

- 玩家账号。
- 上传到云端卡组中心。
- 点赞、下载量、评论、举报、排行榜。
- 摄像头实时扫码。
- 复杂图片美术模板。
- AI 自动写卡组介绍。
- 从任意外部 URL 自动补全缺卡。
- 在分享图预览里编辑卡组。

## 现有工程背景

相关模块：

- `scripts/data/DeckData.gd`
  - 当前本地卡组数据结构。
  - 卡牌条目已有 `set_code`、`card_index`、`count`、`card_type`、`name`、`effect_id`，Limitless 导入卡有额外 source 字段。

- `scripts/autoload/CardDatabase.gd`
  - 保存玩家卡组到 `user://decks/`。
  - 保存/删除后发出 `decks_changed`。
  - 缓存卡牌数据和卡图。

- `scripts/network/DeckImporter.gd`
  - 当前 URL 导入入口。
  - 支持 tcg.mik.moe 和 Limitless。
  - 会处理远端卡牌详情、图片同步、部分导入错误。

- `scenes/deck_manager/DeckManager.gd`
  - 当前卡组导入、保存、重名改名、推荐导入、卡组列表入口。

- `scripts/ui/decks/DeckViewDialog.gd`
  - 当前卡组查看弹窗。
  - 已有卡牌图片展示和卡组条目渲染经验。

关键约束：

- 现有导入是 URL 导入，分享图导入是图片数据导入，不能硬塞进 `DeckImporter.parse_deck_id()`。
- 分享图导入最终应生成 `DeckData`，然后复用现有保存/重名流程。
- 分享图不能只依赖 PNG metadata，因为社交平台和截图经常清除 metadata。
- Windows、Android、Web 的选图/保存/扫码能力不同，核心 payload 协议必须平台无关。

## MVP 用户流程

### 导出分享图

入口：

- 卡组管理页：本地卡组操作中增加 `分享图`。
- 卡组查看弹窗：增加 `分享图`。
- 卡组编辑器：后续可增加 `分享图`。

流程：

1. 玩家选择一套本地卡组。
2. 点击 `生成分享图`。
3. 弹出分享图设置 HUD：
   - 作者名。
   - 一句话介绍。
4. 游戏生成基础海报预览。
5. 玩家点击 `保存图片`。
6. 平台适配器保存图片：
   - Windows：先保存到 `user://deck_share_exports/`，后续支持保存对话框。
   - Android：使用系统文档保存对话框，默认保存到玩家可从系统选择器取回的位置，例如 Downloads。
   - Web：触发浏览器下载。
7. 显示保存成功和文件名/路径提示。

导出不需要网络。

### 从图片导入

入口：

- 卡组管理页导入面板增加 `图片导入`。

流程：

1. 玩家点击 `图片导入`。
2. 平台适配器打开图片选择：
   - Windows：`FileDialog`。
   - Android：系统图片选择器。
   - Web：浏览器 file input。
3. 游戏读取图片。
4. 识别图中的分享数据码。
5. 解码并校验 payload。
6. 转成 `DeckData`。
7. 显示导入预览：
   - 卡组名。
   - 作者。
   - 简介。
   - 来源游戏版本。
   - 卡牌总数。
   - 缺失卡牌。
   - 未实现效果警告。
8. 玩家点击 `保存到我的卡组`。
9. 如果本地已有同名卡组，走现有强制改名流程。
10. 调用 `CardDatabase.save_deck(deck)` 保存。

失败提示：

- `没有识别到卡组数据`
- `图片里的卡组数据已损坏`
- `这张分享图来自更新版本，请更新游戏后再导入`
- `当前版本缺少 N 张卡，无法直接保存`

## 分享图内容

第一版只要求功能稳定，视觉可以朴素。

输出：

- PNG。
- 主宽度：`1080 px`，高度按 `16:9` 顶部 banner、实际卡牌行数、横向导入码和站点页脚动态计算。
- 安全边距：至少 `48 px`。
- 横向导入码不要贴底，避免社交软件裁切。

基础布局：

```text
+------------------------------------------------+
| 16:9 顶部 banner：居中艺术字卡组名 / 作者       |
|                                                |
| 5 列唯一卡牌网格，重复卡在卡图右下角标 XN     |
|                                                |
| 横向导入码                                      |
| ptcg.skillserver.cn                            |
+------------------------------------------------+
```

卡牌网格：

- 第一版渲染唯一卡牌条目，不逐张展开 60 个物理卡位。
- 手机分享图固定为 `5` 列，按唯一卡牌数量自动计算卡图尺寸，横向优先铺满，列间距保持很小。
- 同一 `(set_code, card_index)` 有多张时，只显示一张卡图，并在卡图右下角用黑底白字显示 `X2`、`X3`、`X4` 等数量标识。
- 卡组名和作者显示在 16:9 顶部 banner 中心，不占用卡牌网格或底部导入区。
- 使用本地卡图。
- 缺图时显示高对比占位块，包含 `set_code/card_index`。
- 缺图不阻止导出。

默认美术模板：

- 背景由两张图片组成：顶部 `16:9` banner，以及从 banner 下方开始可随海报高度延展的正文背景。
- 默认背景使用幽灵龙/高速能量主题，服务多龙巴鲁托类卡组示例，但不绑定具体卡组数据。
- 正文背景必须保证卡图可读，纹理和粒子主要放在边缘或低对比区域。

后续美术模板可以扩展：

- 竞技模板：信息密度高，唯一卡牌和重复数量清楚。
- 主视觉模板：突出 3-5 张核心卡，社交传播更强。
- 收藏册模板：更干净，适合保存到手机相册。

## 数据协议

### Envelope

机器可读数据使用版本化 envelope：

```json
{
  "magic": "PTCGTRAIN_DECK_SHARE",
  "schema": 1,
  "game_version": "0.5.0",
  "card_db_version": "2026-07-05",
  "created_at": 1783267200,
  "deck": {},
  "checksum": "..."
}
```

字段说明：

- `magic`：识别这是本游戏卡组分享数据。
- `schema`：协议版本。
- `game_version`：用于导入预览和版本提示。
- `card_db_version`：用于兼容性警告，不应单独作为硬拒绝条件。
- `checksum`：对去掉 checksum 后的规范化 payload 计算。

### Deck Payload

二维码内不放卡图，不放完整卡牌文本，只放恢复卡组所需的稳定身份信息。

```json
{
  "name": "NAIC2025 沙奈朵",
  "author": "玩家名",
  "note": "稳定进化和资源循环，适合喜欢长盘运营的玩家。",
  "source": {
    "type": "local",
    "source_provider": "",
    "source_id": ""
  },
  "cards": [
    ["CSV8C", "041", 4],
    ["CSV9.5C", "068", 2]
  ]
}
```

卡牌 tuple：

```text
[set_code, card_index, count]
```

规则：

- 按 `set_code`、`card_index`、`count` 规范排序。
- 合并重复 `(set_code, card_index)`。
- 拒绝 `count <= 0`。
- 默认拒绝总数不等于 60 的卡组。
- 以 `set_code/card_index` 作为主身份。
- 接收方展示卡名时，从本地 `CardDatabase` 解析。

### Limitless Source Hints

部分 Limitless 导入卡可能需要 source hint。为避免普通国服卡组 payload 膨胀，source hint 只在必要时写入。

扩展 tuple：

```json
["LEN_SV10", "182", 2, {"p": "limitless", "s": "JTG", "n": "182", "l": "en"}]
```

短字段：

- `p`：source provider。
- `s`：source set code。
- `n`：source card number。
- `l`：source language。

第一版只保证接收端已有对应生成卡或 canonical card 时可导入。自动联网补 Limitless 缺卡放后续。

## 编码方案

推荐 V1 编码：

```text
canonical JSON -> UTF-8 -> DEFLATE -> Base45 -> QR alphanumeric mode
```

外层文本：

```text
PTCGD1.<base45-compressed-payload>.<crc32>
```

原因：

- Godot 自带 `PackedByteArray`/`FileAccess.CompressionMode` 压缩能力。
- Base45 适合 QR alphanumeric mode。
- `PTCGD1` 前缀方便扫码结果路由。
- 外层 CRC 能在解压前发现截断/损坏。
- 内层 checksum 防止结构化数据损坏。

注意：

- 如果 QR 生成库不能显式使用 alphanumeric mode，Base64url 可能更短，应通过实际扫描测试决定。
- V1 保持 JSON，便于调试；只有当真实卡组超过单 QR 容量时再考虑 CBOR/自定义二进制。

## Payload 体积评估

对当前 `data/bundled_user/decks` 下 60 套卡组做过紧凑 JSON 估算：

| Metric | Raw JSON bytes | zlib bytes | Base45 chars | Base64url chars |
| --- | ---: | ---: | ---: | ---: |
| min | 387 | 191 | 287 | 255 |
| median | 583 | 235 | 353 | 314 |
| p90 | 657 | 258 | 387 | 344 |
| max | 678 | 267 | 401 | 356 |

合成压力样本：

| Scenario | Raw JSON bytes | zlib bytes | Base45 chars |
| --- | ---: | ---: | ---: |
| 60 unique `CSV9.5C` rows | 1330 | 275 | 413 |
| 33 unique `LEN_*` rows with Limitless hints | 2365 | 347 | 521 |
| 60 unique `LEN_*` rows with Limitless hints | 4201 | 481 | 722 |

实现校准：

- 实际 envelope 还包含 `magic/schema/game_version/card_db_version/created_at/checksum/deck source` 等字段，完整编码后会比上表估算更长。
- 2026-07-06 对当前全部内置卡组重新跑容量回归，最大完整 QR 文本为 `907` 字符。
- MVP 实现保留 QR Code Model 2 `Version 26-Q` 作为小尺寸兜底码，alphanumeric 容量为 `1046` 字符，当前渲染为 `129 x 129 px`。
- 海报主机器码改为横向数据条，尺寸 `860 x 156 px`，用于降低二维码对视觉中心的占用。

结论：

- 完整卡牌编号信息可以放入横向数据条，新版分享图不再生成二维码。
- MVP 不需要服务器短链。
- MVP 不需要多二维码分片。
- MVP 不需要服务器端高容量视觉码。

## 机器码技术选型

### 横向数据条

手机传播图以横向数据条作为第一版可见数据码。scanner 保留旧版 QR 读取能力，只用于兼容已经导出的旧分享图。

配置：

- 横向数据条原始编码图为 `860 x 156 px`，海报显示时压缩为 `860 x 78 px`。
- 新版海报只渲染横向数据条，不再渲染二维码。
- 导入时优先识别横向数据条，仍兼容旧版大 QR。

选择原因：

- 横向数据条更适合竖屏海报底部，不会抢卡图视觉中心。
- 旧版大 QR 兼容路径方便后续接入 ML Kit、ZXing-C++、Web BarcodeDetector 或 zxing-wasm。
- 旧版大 QR 继续可读，避免已导出的分享图失效。

### 不选的方案

Data Matrix：

- 紧凑且成熟，但 Android ML Kit 对 Data Matrix 有中心点识别限制。
- 用户不熟悉，不适合作为第一传播媒介。

Aztec：

- 可行，但用户认知弱于 QR。
- 作为未来备选，不作为 MVP 主方案。

PDF417：

- 容量高但占用大，长条形不适合竖屏海报。

PNG metadata：

- 原图可无损读取，但社交转发和截图经常丢失。
- 只能作为后续快速通道，不能作为唯一数据载体。

隐写/不可见水印：

- 高容量且抗压缩的成熟方案成本高。
- 开源简单隐写在社交压缩下不可靠。
- 导入失败难以向玩家解释。

自定义视觉码：

- 需要自己解决定位、透视、纠错、压缩损坏。
- 不值得在 MVP 承担。

## 生成与识别技术选型

### 图片生成

推荐：

- 使用 Godot `SubViewport` + `Control` 模板场景离屏渲染。
- 模板为项目资源，后续可替换背景、布局、字体、边框。
- 导出时捕获 viewport texture 并保存 PNG。

渲染流程：

```text
实例化 DeckPosterTemplate.tscn
  -> 填充卡图/横向导入码/卡组名/作者/站点
  -> 等待 RenderingServer.frame_post_draw
  -> viewport.get_texture().get_image()
  -> save_png
```

原因：

- 复用项目已有字体和 UI 渲染。
- 跨 Windows/Android/Web。
- 预览和最终导出一致。
- 后续做漂亮模板时，不需要改 payload 协议。

风险：

- 需要导出锁，避免同时生成多张图。
- 需要固定输出尺寸，不受当前游戏窗口影响。
- 当前项目使用 `gl_compatibility` 渲染路径，要做平台实测。
- 保存前应铺纯色或图片背景，避免透明区域在相册中显示异常。

### 机器码生成

推荐：

- 横向数据条由本项目 GDScript 生成，承载 encoded payload 文本。
- QR Code 生成模块只保留给旧图兼容和独立测试，不参与新版海报输出。

原因：

- 只负责生成，不需要 native 依赖。
- 代码小，许可证友好。
- 支持明确选择纠错等级和编码段。
- 可单元测试。

备选：

- ZXing-C++ Writer：能力强，但 native 依赖重，不适合第一版生成端。
- Zint：生成能力成熟，但更适合工具链，不适合运行时内置。

### Android 识别

MVP 决策：

- 通过 Godot 原生文件对话框打开系统图片/文件选择器。
- 游戏内先用 GDScript 识别本功能生成的横向导入码，再兼容识别旧版大 QR。
- 第一版只做“从相册/文件选择图片识别”，不做摄像头实时扫码。

优点：

- 不引入 Android plugin 和 Gradle 依赖，能先验证离线分享闭环。
- 系统选择器返回 `content://` URI，符合 Android 存储权限模型。
- 后续接入 ML Kit 后，仍可复用同一 `DeckShareImageScanner` API。

成本：

- 当前 GDScript 识别器只承诺识别本功能生成的横向导入码和 QR 布局，不替代完整通用 QR/条码 SDK。
- 社交平台大幅压缩、裁切、旋转后的图片，应通过后续 ML Kit 增强覆盖。

### Windows/macOS 识别

MVP 决策：

- 使用内置 GDScript scanner 识别本功能生成的横向导入码和旧版大 QR。
- 后续使用 ZXing-C++ 增强通用识别能力。
- 理想形态是 GDExtension，暴露一个很小的接口：

```gdscript
decode_qr_from_rgba(width, height, bytes) -> PackedStringArray
```

早期原型可以先用 helper exe：

- Godot 把图片路径传给 helper。
- helper 用 ZXing-C++ 解码并输出文本。
- 只用于桌面端早期验证。

### Web 识别

推荐：

- MVP 先通过浏览器 file input 读取图片，交给游戏内 GDScript 识别本功能生成的横向导入码和旧版大 QR。
- 后续先探测浏览器 `BarcodeDetector`。
- 不可用时用 `zxing-wasm` fallback。
- 通过 Godot `JavaScriptBridge` 与浏览器交互。

原因：

- `BarcodeDetector` 浏览器覆盖不完整。
- `zxing-wasm` 能提供稳定兜底。

## 数据恢复策略

第一版必须依赖可见机器码，当前使用横向导入码。

后续可以增加 PNG metadata 快速通道：

1. 游戏保存原始 PNG 时写入同一份 encoded payload。
2. 导入时先尝试 metadata。
3. metadata 不存在或校验失败时，再识别横向导入码。

真实场景预期：

- 游戏原始导出图：metadata 和横向导入码都可用。
- 社交平台转发图：metadata 大概率丢失，横向导入码应可用。
- 裁掉底部机器码的图：无法导入，这是可接受失败。

## 模块设计

### `scripts/deck_share/DeckSharePayloadCodec.gd`

职责：

- 从 `DeckData` 构造 payload。
- 规范化卡牌条目。
- 校验作者/简介/卡组名长度。
- 编码 payload 文本。
- 解码 payload 文本。
- 校验 CRC/checksum/schema。

接口草案：

```gdscript
static func build_payload(deck: DeckData, author: String, note: String, app_version: String, card_db_version: String) -> Dictionary
static func encode_payload(payload: Dictionary) -> Dictionary
static func decode_text(text: String) -> Dictionary
static func validate_payload(payload: Dictionary) -> PackedStringArray
```

返回结构：

```gdscript
{
  "ok": true,
  "text": "PTCGD1....",
  "payload": {},
  "errors": PackedStringArray()
}
```

### `scripts/deck_share/DeckShareQrEncoder.gd`

职责：

- 把 encoded payload 文本转为小尺寸兜底 QR `Image`/`ImageTexture`。
- 控制纠错等级、quiet zone、颜色和输出尺寸。
- 报告 payload 过大错误。

### `scripts/deck_share/DeckShareDataStrip.gd`

职责：

- 把 encoded payload 文本转为横向导入码 `Image`/`ImageTexture`。
- 控制数据条尺寸、保护边距、长度字段和校验。
- 提供与 scanner 共用的横向码解码入口。

### `scripts/deck_share/DeckPosterComposer.gd`

职责：

- 渲染 `1080 px` 宽、动态高度分享图。
- 填充两段式背景、顶部 16:9 banner 艺术标题/作者、5 列唯一卡牌网格、横向导入码和站点页脚。
- 缺图时生成占位卡。
- 返回 PNG bytes 或保存结果。

### `scripts/deck_share/DeckShareImageScanner.gd`

职责：

- 统一图片扫描入口。
- MVP 内置可识别本功能生成横向导入码和旧版大 QR 的 GDScript scanner。
- 后续可根据平台调用 Android plugin、ZXing-C++、Web JS。
- 返回一个或多个 encoded payload text。

接口草案：

```gdscript
signal scan_completed(texts: PackedStringArray)
signal scan_failed(message: String)

func scan_image_bytes(bytes: PackedByteArray, source_name: String = "") -> void
```

### `scripts/deck_share/DeckShareImporter.gd`

职责：

- 把已解码 payload 转成 `DeckData`。
- 用 `CardDatabase` 解析卡牌。
- 生成缺卡/未实现效果警告。
- 生成不冲突的本地 deck id。

导入卡组元数据建议：

```gdscript
deck.source_provider = "ptcg_share_image"
deck.source_id = payload_checksum
deck.source_url = "ptcg-share://deck/%s" % payload_checksum
deck.variant_name = payload.deck.name
deck.deck_name = payload.deck.name
deck.strategy = payload.deck.note
```

本地 id：

- 不复用 tcg.mik.moe deck id。
- 如果当前持久化假设正整数，使用高位本地命名空间，例如 `900000000 + hash_mod`。
- 如果冲突，递增直到空位。

### `scripts/deck_share/DeckSharePlatformAdapter.gd`

职责：

- 保存分享图。
- 打开图片选择器。
- 隐藏 Windows/Android/Web 平台差异。

接口草案：

```gdscript
signal image_saved(path: String)
signal image_save_failed(message: String)
signal image_picked(bytes: PackedByteArray, source_name: String)
signal image_pick_failed(message: String)

func save_png(image: Image, suggested_name: String) -> void
func pick_image() -> void
```

## UI 集成

### 卡组管理页

本地卡组操作增加：

- `查看`
- `编辑`
- `分享图`
- `删除`

竖屏空间紧张时，不要在列表行塞小按钮，应放入现有卡组操作 HUD。

导入面板改为两个入口：

- `链接导入`
- `图片导入`

现有 URL 导入必须保留。

### 分享图 HUD

字段：

- 作者名。
- 一句话介绍。

按钮：

- `预览`
- `保存图片`
- `关闭`

规则：

- 作者名默认使用上次输入。
- 作者名为空时显示 `匿名玩家`。
- 简介可空。
- 卡组必须是 60 张，否则禁用保存并显示错误。

### 图片导入预览 HUD

展示：

- 卡组名。
- 作者。
- 简介。
- 来源游戏版本。
- 卡牌总数。
- 缺失卡牌。
- 未实现效果警告。

按钮：

- `保存到我的卡组`
- `取消`

规则：

- payload 无效时不能保存。
- 缺卡无法解析时第一版阻止保存。
- 同名卡组走现有强制改名流程。

## 兼容规则

MVP 支持：

- 接收端已有全部卡牌数据的卡组。
- tcg.mik.moe canonical `set_code/card_index`。
- 本地导入卡组，只要 canonical card id 存在。
- 导出端缺卡图。

允许但提示：

- 来源游戏版本较旧。
- 来源 card_db_version 较旧。
- 有未实现效果的卡，但本地存在卡牌数据。
- 缺少可选 source hint。

拒绝：

- `magic` 错误。
- `schema` 不支持。
- CRC/checksum 错误。
- 解压失败。
- JSON 格式错误。
- 总卡数不是 60。
- 卡牌数量 <= 0。
- 卡牌身份无法解析。
- 缺卡且无法通过本地或支持的 source hint 解决。

## 安全限制

图片导入数据必须当成不可信输入：

- encoded text 最大 4096 字符。
- 解压后 JSON 最大 16384 bytes。
- cards rows 合并前最大 120。
- deck name 最大 40 个可见字符。
- author 最大 20 个可见字符。
- note 最大 80 个可见字符。
- 忽略未知字段。
- 不执行 payload 内任何 URL。
- 不按 payload 指定路径写文件。
- 不自动覆盖本地卡组。
- 不从任意外部 URL 下载卡图。

## 测试计划

### 单元测试

新增 `tests/test_deck_share_payload_codec.gd`：

- 有效卡组 encode/decode round-trip。
- 卡牌条目排序和合并。
- CRC 错误拒绝。
- magic 错误拒绝。
- schema 不支持拒绝。
- 超长 name/author/note 按最终规则截断或拒绝。
- 总数不是 60 拒绝。
- 基本能量数量 round-trip。
- Limitless source hints round-trip。
- 当前 bundled decks 的 payload 均不超出二维码预算。

新增 `tests/test_deck_share_importer.gd`：

- payload 可转成 `DeckData`。
- 本地 deck id 不冲突。
- `source_provider == "ptcg_share_image"`。
- 缺本地卡产生 blocking warning。
- 未实现效果产生 non-blocking warning。

新增 `tests/test_deck_poster_composer.gd`：

- 输出 `1080 px` 宽、动态高度。
- 横向导入码 rect 在安全区内。
- 缺卡图时生成占位块。
- 导出的 PNG 可被 Godot 重新加载。

新增 `tests/test_deck_share_image_scanner.gd`：

- 能识别 composer 生成的原图。
- 能识别合理缩放/重编码后的图。
- 裁掉底部机器码后失败且报错清楚。

### UI 测试

扩展 `tests/test_deck_manager.gd` 和竖屏测试：

- 卡组操作 HUD 有 `分享图`。
- 导入面板有 `图片导入`。
- 竖屏按钮尺寸符合触摸习惯。
- 图片导入预览 HUD 阻断背景触摸。
- 取消导入不改变现有卡组。
- 保存图片导入卡组后发出 `decks_changed`。

### 手动平台测试

Windows：

- 导出一张分享图。
- 从同一张 PNG 导入。
- 从被图片查看器重存过的 PNG 导入。

Android：

- 导出分享图。
- 确认图片能从目标位置取回。
- 从系统图片选择器导入。
- 检查竖屏 HUD 尺寸和触摸。

Web：

- 导出触发浏览器下载。
- 导入通过浏览器文件选择。
- 确认没有使用被浏览器禁止的本地文件/剪贴板 API。

## 实现阶段

### Phase 1: Payload Codec

- 实现 `DeckSharePayloadCodec`。
- 实现 Base45/CRC/压缩。
- 用真实 bundled decks 做体积测试。

验收：

- 任意本地 60 卡 `DeckData` 可 encode/decode round-trip。

### Phase 2: 机器码生成

- 实现横向数据条 generator。
- 输出机器码 `ImageTexture`。
- 测试尺寸、quiet zone/保护边距和校验。

验收：

- payload 可稳定生成横向导入码图块。

### Phase 3: Poster Composer

- 实现 Godot SubViewport 海报模板。
- 输出 `1080 px` 宽、动态高度 PNG。
- 卡图缺失时显示占位。

验收：

- 本地卡组可以生成可查看 PNG。

### Phase 4: Desktop Decode

- MVP 使用内置 GDScript scanner 识别本功能生成的横向导入码和旧版大 QR。
- 后续可接入 ZXing-C++ GDExtension 或 helper，提高任意裁切/旋转/压缩图片的识别率。
- 支持 Windows 选图识别。

验收：

- Windows 可从生成图导入卡组。

### Phase 5: Android Decode

- 使用 Godot 原生文件对话框支持系统图片选择。
- MVP 使用内置 GDScript scanner 识别本功能生成的横向导入码和旧版大 QR。
- 后续可接入 Android ML Kit plugin，提高鲁棒性并支持实时扫码。

验收：

- Android 可从相册/选择器导入卡组。

### Phase 6: UI Integration

- 卡组管理页增加 `分享图`。
- 导入面板增加 `图片导入`。
- 增加导出 HUD 和导入预览 HUD。
- 复用现有重名保存流程。

验收：

- 玩家可从 UI 完成导出和导入闭环。

### Phase 7: Web Support

- Web 下载分享图。
- Web 文件选择导入。
- MVP 使用 JavaScriptBridge 下载和 file input，识别仍走内置 GDScript scanner。
- 后续增加 BarcodeDetector + zxing-wasm fallback。

验收：

- Web 平台完成同一闭环。

## 开放决策

实现前需要确认：

1. Android 第一版保存方式：已选择系统文档保存对话框，避免 app 私有目录无法被系统选择器取回。
2. 第一公开版是否需要摄像头实时扫码。本文建议不需要，先做选图导入。
3. 导入后的卡组列表是否显式展示原作者，还是只保存在 source/strategy 里。
4. 缺卡时是否允许保存占位卡组。本文建议第一版阻止保存。

## 验收标准

功能 MVP 完成的定义：

- 一套正常 60 卡本地卡组可以导出 `1080 px` 宽、动态高度 PNG。
- PNG 中有可见机器码，包含完整卡牌编号信息。
- 游戏可以选择该 PNG 并恢复卡组。
- 恢复后的卡组通过 `CardDatabase.save_deck` 保存。
- 同名卡组仍走现有重命名流程。
- 缺卡图不阻止导出。
- 缺卡牌数据时阻止导入并给出明确提示。
- codec、poster、importer 有聚焦单元测试。
- Windows 和 Android 完成手动 round-trip 测试。

## 参考资料

- QR Code version/capacity: https://www.qrcode.com/en/about/version.html
- QR Code error correction: https://www.qrcode.com/en/about/error_correction.html
- Base45 RFC: https://datatracker.ietf.org/doc/html/rfc9285
- Nayuki QR Code Generator: https://github.com/nayuki/QR-Code-generator
- ZXing-C++: https://github.com/zxing-cpp/zxing-cpp
- Android ML Kit Barcode Scanning: https://developers.google.com/ml-kit/vision/barcode-scanning/android
- Godot Android Plugin: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
- Godot JavaScriptBridge: https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html
- Godot Viewport capture: https://docs.godotengine.org/en/stable/classes/class_viewport.html
