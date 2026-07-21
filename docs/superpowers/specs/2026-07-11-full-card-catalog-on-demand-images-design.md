# 全量卡牌目录与按需卡图架构设计

日期：2026-07-11
状态：核心设计草案
目标版本：下一个大版本

## 1. 背景

现在的卡牌接入方式更接近“用到一批卡，就把这批卡的数据和图片一起放进版本”。这带来三个问题：

1. 玩家为了某一张新卡、某一套卡组、某张缺图卡，必须等待客户端版本更新。
2. 如果把所有卡图都打包进游戏，安装包和 Web 首屏下载会快速膨胀。
3. 卡组中心的构筑能力被本地已有卡牌限制，玩家不能自然地搜索、预览和保存完整环境里的所有卡。

下一版要把“卡牌文字数据”和“卡牌图片资源”拆成两套生命周期：

1. 客户端一次性接入完整卡牌目录，使卡组中心能搜索、构筑、导入所有已知卡牌。
2. 客户端不打包完整卡图库。
3. 玩家在卡组中心实际构筑、导入、打开某套卡组时，才下载这套卡组需要的卡图到本地。
4. 卡图没有下载时，游戏显示文字版代卡，卡牌仍然可以被识别、保存和展示。

## 2. 目标

### 2.1 产品目标

1. 新版本内置完整的卡牌文字目录，玩家能在卡组中心搜索和构筑所有已接入目录的卡。
2. 卡图按需下载，只下载玩家卡组中实际出现的卡图，不因为浏览搜索结果而批量下载全库。
3. 离线、下载失败、Web 存储受限时，卡牌退化为文字版代卡，不阻塞构筑和卡组保存。
4. 已缓存卡图在 Windows、Android、Web 上复用，后续打开同一卡组不重复下载。
5. 战斗 UI 不在战斗中临时发起网络请求，避免网络抖动导致战斗卡住。
6. 卡组分享图、卡组详情、卡牌详情都能使用同一套“有图则显示卡图、无图则显示代卡”的能力。

### 2.2 技术目标

1. 把全量卡牌目录从 `data/bundled_user/cards/*.json` 的“散文件卡池”里拆出来，形成只读的全量索引。
2. 保持现有 deck entry 的核心身份 `{set_code, card_index}` 不变，避免破坏已有卡组、分享图和导入协议。
3. 扩展 `CardDatabase.get_card()`，让它可以从全量目录懒加载卡牌，而不是只查 `user://cards` 和 `res://data/bundled_user/cards`。
4. 用新的图片缓存服务替代“全库同步图片”的思路，支持按卡组、按优先级、可取消、可重试的下载队列。
5. 图片缓存状态放在 sidecar manifest 中，不依赖把每张目录卡都写成 `user://cards/*.json`。
6. 为 Android/Web 的存储和网络限制提供明确降级策略。

## 3. 非目标

1. 不在这个版本实现所有卡牌效果的规则脚本。全量目录解决“卡牌存在和可构筑”，不等于所有卡都已可规则对战。
2. 不把所有卡图打包进安装包。
3. 不允许卡组分享数据携带任意图片 URL 并让客户端下载。
4. 不让战斗 UI、卡牌视图组件、分享图渲染器直接访问网络。
5. 不用一次性下载全部图片作为“首次启动同步”。
6. 不改变现有卡组保存格式的基础结构，仍以 `set_code`、`card_index`、`count` 作为卡牌身份。

## 4. 关键概念

### 4.1 卡牌存在状态

卡牌要拆成三个独立状态，避免 UI 和规则层混淆：

1. 目录存在：全量卡牌目录里有这张卡的名称、类型、编号、文本和基础字段。
2. 图片存在：本地缓存里有可用卡图。
3. 规则可用：这张卡的 `effect_id` 已实现，或者可通过同效果别名复用已有实现。

因此：

1. 图片缺失时显示文字版代卡。
2. 规则缺失时显示“规则未实现”状态，并由对战入口决定阻止、警告或只允许自由模式。
3. 图片缺失不应该被当成卡牌缺失。
4. 规则缺失不应该被当成图片缺失。

### 4.2 卡牌身份

继续使用当前主身份：

```text
uid = "{set_code}_{card_index}"
```

对外协议仍使用：

```json
{
  "set_code": "CSV9C",
  "card_index": "123",
  "count": 4
}
```

Limitless、英文卡、别名卡继续保留 source 字段：

```json
{
  "source_provider": "limitless",
  "source_set_code": "SVI",
  "source_card_index": "123",
  "source_language": "en",
  "source_url": "..."
}
```

## 5. 当前实现基线

当前代码已经有一部分可复用基础：

1. `CardData.gd` 已有 `image_url`、`image_local_path`、`source_provider`、`source_*` 字段。
2. `CardData.build_local_image_path()` 默认把图片放到 `user://cards/images/{set_code}/{card_index}.png`。
3. `CardData.resolve_existing_image_path()` 已支持优先查 `user://`，再查 `res://data/bundled_user/cards/images`。
4. `CardDatabase.gd` 已有 `get_card()`、`get_all_cards()`、`cache_card()`、`save_card_image()`。
5. `DeckImporter.gd` 导入卡组后会调用 `CardImageDownloader.sync_cards(cards_to_sync)`。
6. `CardImageDownloader.gd` 能按卡下载图片并保存到本地。
7. `DeckViewDialog.gd` 和 `DeckPosterComposer.gd` 已经遵循“本地有图则加载，缺图则占位”的大方向。
8. `docs/battle_ui_redesign.md` 已明确战斗 UI 只读取本地卡图，不从网络下载。

这套设计会复用这些约定，但把“下载所有缓存卡图”的旧思路升级为“按卡组需求下载”。

## 6. 总体架构

```text
                 build-time / server-side

   tcg.mik.moe / Limitless / manual patches
                    |
                    v
        Card Catalog Builder / Validator
                    |
        +-----------+------------+
        |                        |
 bundled full card catalog   optional remote catalog patches
 res://data/card_catalog     ptcg.skillserver.cn/card_catalog


                    runtime client

       +---------------- CardCatalogIndex ----------------+
       | lightweight search index + lazy full-card loader  |
       +---------------------+----------------------------+
                             |
                             v
                       CardDatabase
          user cards / curated bundled cards / catalog fallback
                             |
        +--------------------+---------------------+
        |                                          |
   Deck Center / Importer                    Battle / Poster
        |                                          |
        v                                          v
 CardImageCacheService  <-------------- local image/proxy only
        |
        v
 user://cards/images + user://cards/image_cache_manifest.json
```

## 7. 数据分层设计

### 7.1 全量目录目录结构

新增目录：

```text
res://tools/card_catalog_sources/cards/
  CSV4C_015.json             # 可重建的文字/规则元数据源，不放卡图

res://data/card_catalog/
  catalog_manifest.json
  index.json
  sets/
    CSV1C.json
    CSV2C.json
    ...
```

可选远程补丁缓存：

```text
user://card_catalog/
  remote_manifest.json
  index.json
  sets/
    CSV9C.json
```

`res://data/bundled_user/cards/*.json` 继续保留，但职责改成“高优先级人工修正和规则实现卡”，不再承担全量卡池职责。

`res://tools/card_catalog_sources/cards/*.json` 是仅供构建工具读取、不会随 `data/**` 导出规则重复打包的
catalog-only 原始数据层。构建器先读该目录，再读
`bundled_user/cards`；同 UID 时由 curated bundled 数据覆盖。这样新卡可以进入全量目录而不被启动时种子逻辑
复制到 `user://cards`，也不要求存在对应的 `.png.bin`。

### 7.2 catalog_manifest.json

职责：

1. 描述目录版本。
2. 描述每个 set 文件的校验信息。
3. 声明目录生成来源和 schema 版本。
4. 支持未来远程补丁的版本比较。

示例：

```json
{
  "schema_version": 1,
  "catalog_version": "2026.07.11.1",
  "generated_at": "2026-07-11T00:00:00+08:00",
  "card_count": 18432,
  "index_file": {
    "path": "index.json",
    "sha256": "..."
  },
  "sets": [
    {
      "set_code": "CSV9C",
      "path": "sets/CSV9C.json",
      "card_count": 188,
      "sha256": "..."
    }
  ],
  "sources": [
    {
      "provider": "tcg_mik",
      "snapshot": "2026-07-11"
    },
    {
      "provider": "limitless",
      "snapshot": "2026-07-11"
    }
  ]
}
```

### 7.3 index.json

`index.json` 是卡组中心搜索用的轻量索引，不存完整文本，只存筛选和展示卡片格需要的字段。

示例：

```json
{
  "schema_version": 1,
  "catalog_version": "2026.07.11.1",
  "cards": [
    {
      "uid": "CSV9C_123",
      "set_code": "CSV9C",
      "card_index": "123",
      "name": "太晶甲贺忍蛙ex",
      "name_en": "Greninja ex",
      "name_zh": "太晶甲贺忍蛙ex",
      "card_type": "Pokemon",
      "mechanic": "ex",
      "stage": "Stage 2",
      "energy_type": "W",
      "regulation_mark": "H",
      "rarity": "RR",
      "effect_id": "....",
      "implementation_status": "implemented",
      "set_file": "sets/CSV9C.json",
      "image_key": "CSV9C/123",
      "image_url": "https://..."
    }
  ]
}
```

### 7.4 sets/{set_code}.json

每个 set 文件保存完整 `CardData.to_dict()` 兼容记录。这样可以：

1. 搜索时只加载轻量索引。
2. 玩家点进详情、加入卡组、开始对战时，再懒加载完整卡牌。
3. 避免启动时把全量卡牌全部实例化成 `CardData`。

示例：

```json
{
  "schema_version": 1,
  "set_code": "CSV9C",
  "cards": [
    {
      "name": "太晶甲贺忍蛙ex",
      "name_en": "Greninja ex",
      "name_zh": "太晶甲贺忍蛙ex",
      "card_type": "Pokemon",
      "mechanic": "ex",
      "set_code": "CSV9C",
      "card_index": "123",
      "effect_id": "...",
      "image_url": "https://...",
      "image_local_path": "user://cards/images/CSV9C/123.png",
      "attacks": [],
      "abilities": []
    }
  ]
}
```

## 8. 运行时模块设计

### 8.1 CardCatalogIndex.gd

新增：

```text
scripts/card_catalog/CardCatalogIndex.gd
```

职责：

1. 加载 bundled catalog manifest 和 index。
2. 如果远程 catalog 补丁存在且版本更新，优先使用远程补丁。
3. 提供卡组中心搜索 API。
4. 根据 `{set_code, card_index}` 懒加载完整卡牌记录。
5. 为 `CardDatabase` 提供 catalog fallback。

建议 API：

```gdscript
func is_ready() -> bool
func get_catalog_version() -> String
func has_card(set_code: String, card_index: String) -> bool
func get_entry(set_code: String, card_index: String) -> Dictionary
func get_card_data(set_code: String, card_index: String) -> CardData
func search_cards(query: String, filters: Dictionary, limit: int, offset: int) -> Array[Dictionary]
func get_cards_by_uids(uids: PackedStringArray) -> Array[Dictionary]
```

搜索返回 `Dictionary` 索引行，不直接返回 `CardData`，避免 UI 翻页时实例化大量资源。

### 8.2 CardDatabase.gd 集成

`CardDatabase` 的解析顺序调整为：

1. `user://cards/{uid}.json`：用户导入、编辑、历史缓存卡。
2. `res://data/bundled_user/cards/{uid}.json`：人工修正、规则实现、翻译修正、高优先级覆盖。
3. `CardCatalogIndex.get_card_data(set_code, card_index)`：全量目录 fallback。

`has_card()` 调整为：

```text
user card exists
or bundled curated card exists
or catalog index has card
```

`get_all_cards()` 不应该默认返回全量目录的全部完整 `CardData`。否则现有调用点可能无意中把全库读进内存。建议拆成两个 API：

```gdscript
func get_all_cards() -> Array[CardData]
func get_all_materialized_cards() -> Array[CardData]
func search_catalog_cards(query: String, filters: Dictionary, limit: int, offset: int) -> Array[Dictionary]
```

迁移策略：

1. 保持 `get_all_cards()` 初期语义不变，只返回已物化卡和 bundled curated 卡。
2. 卡组中心改用 `search_catalog_cards()`。
3. 需要全库查找的工具脚本显式调用 catalog API。

### 8.3 CardImageCacheService.gd

新增：

```text
scripts/card_images/CardImageCacheService.gd
```

它替代 UI 直接使用 `CardImageDownloader` 的方式。`CardImageDownloader` 可以被重构为该服务内部的单请求执行器，或保留为兼容包装。

职责：

1. 根据 `CardData` 或 `{set_code, card_index}` 计算本地图片路径。
2. 判断图片状态：missing、queued、downloading、ready、failed、stale。
3. 维护下载队列和优先级。
4. 下载完成后原子写入本地缓存。
5. 更新 sidecar manifest。
6. 提供信号给 UI 热更新卡图。
7. 管理缓存大小和 LRU 清理。

建议 API：

```gdscript
signal image_ready(uid: String, local_path: String)
signal image_failed(uid: String, reason: String)
signal image_progress(job_id: String, completed: int, total: int)

func get_status(set_code: String, card_index: String) -> String
func get_local_path_if_ready(set_code: String, card_index: String) -> String
func ensure_image(card: CardData, priority: int = 0, reason: String = "") -> String
func ensure_deck_images(deck: DeckData, options: Dictionary = {}) -> String
func cancel_job(job_id: String) -> void
func retry_failed(set_code: String, card_index: String) -> void
func enforce_cache_budget() -> void
```

### 8.4 image_cache_manifest.json

新增：

```text
user://cards/image_cache_manifest.json
```

示例：

```json
{
  "schema_version": 1,
  "updated_at": 1780000000,
  "entries": {
    "CSV9C_123": {
      "set_code": "CSV9C",
      "card_index": "123",
      "local_path": "user://cards/images/CSV9C/123.png",
      "source_url": "https://...",
      "bytes": 438213,
      "sha256": "...",
      "content_type": "image/png",
      "last_accessed_at": 1780000000,
      "downloaded_at": 1780000000,
      "fail_count": 0,
      "last_error": ""
    }
  }
}
```

图片缓存状态不再要求把完整卡牌 JSON 写入 `user://cards`。这样远程目录修正和 bundled curated 修正不会被旧的 user card JSON 长期遮蔽。

### 8.5 CardImageOrProxyView

新增共享 UI 组件：

```text
scripts/ui/cards/CardImageOrProxyView.gd
```

职责：

1. 输入 `CardData` 或 catalog entry。
2. 优先显示本地卡图。
3. 如果卡图缺失，显示文字版代卡。
4. 如果下载中，显示小型进度状态。
5. 监听 `CardImageCacheService.image_ready`，图片到达后自动替换。

文字版代卡应包含：

1. 卡名。
2. 类型、机制、HP、属性。
3. set code 和 card index。
4. 第一段招式/特性摘要，移动端字号必须可读。
5. 明确的“代卡”视觉标识，但不能抢占主要信息。

所有卡牌展示入口都应逐步迁移到这个组件：

1. 卡组中心搜索结果。
2. 卡组详情。
3. 卡牌详情。
4. 战斗卡牌视图。
5. 选择 HUD。
6. 卡组分享图渲染器。

## 9. 按需下载触发规则

### 9.1 必须触发下载的场景

1. 玩家在卡组中心打开一套已保存卡组。
2. 玩家导入一套卡组。
3. 玩家从搜索结果把卡加入当前构筑。
4. 玩家点击“生成分享图”前。
5. 玩家点击“下载本卡组卡图”。

这些场景只下载当前卡组的 unique cards，不按 60 张重复下载。

### 9.2 不自动下载的场景

1. 仅打开卡组中心首页。
2. 仅搜索卡牌。
3. 仅滚动搜索结果。
4. 仅打开全量卡牌列表。

搜索结果默认显示文字版代卡或已有缓存图片，不能因为用户滚动搜索结果而批量下载全库。

### 9.3 可选下载的场景

1. 卡组中心的每张缺图代卡显示独立“下载卡图”按钮，只提交该卡的 UID，并将其视为玩家显式允许的网络请求。
2. 玩家在设置里开启“查看卡牌详情时自动下载卡图”。
3. Wi-Fi 环境下，可以允许“预下载我所有卡组的卡图”，但必须是显式操作。

默认策略应保守：只为卡组下载。

玩家把搜索结果加入或替换进当前构筑时，属于明确的前台构筑动作。该动作允许立即下载这一张卡图，
包括 Web 运行时；单纯搜索、滚动和查看全库仍不得触发下载。

## 10. Deck Center 产品体验

### 10.1 搜索与构筑

搜索结果卡片显示：

1. 有缓存图：显示卡图。
2. 无缓存图：显示文字版代卡。
3. 规则未实现：右上角显示“规则未实现”或禁用标识。
4. 下载失败：显示小型重试标识。

加入卡组后：

1. 当前卡进入 foreground 下载队列。
2. 不阻塞继续构筑。
3. 如果下载成功，卡图自动替换。
4. 如果下载失败，保留代卡，并在卡组图片状态里提示。

### 10.2 卡组详情

打开卡组详情时：

1. 立即渲染已有缓存图和代卡。
2. 后台开始下载缺失卡图。
3. 顶部显示轻量状态：“卡图 12/34，下载中”。
4. 失败后显示“5 张卡图未下载，点此重试”。

### 10.3 分享图

生成分享图前：

1. 调用 `ensure_deck_images(deck, {"blocking_timeout_ms": 8000})`。
2. 在超时时间内尽量补齐卡图。
3. 超时或失败的卡用分享图专用的高清文字代卡渲染。
4. 分享图生成不能因为单张图片失败而整体失败。

### 10.4 对战入口

开始对战前检查两类状态：

1. 图片状态：缺图不阻止对战。
2. 规则状态：未实现卡按当前产品策略处理。

建议默认：

1. 标准规则对战阻止未实现卡进入。
2. 自由测试模式允许未实现卡，但明确提示“该卡仅按文字代卡展示，效果不会自动处理”。

## 11. 下载与缓存策略

### 11.1 下载队列

队列优先级：

1. foreground：当前正在编辑/打开的卡组。
2. poster：分享图生成前的补图。
3. background：玩家显式选择的“下载我所有卡组卡图”。

并发建议：

1. Windows：3 个并发。
2. Android：2 个并发。
3. Web：默认不自动下载，只有 CORS 和持久化验证通过后才启用 1 个并发。

失败策略：

1. 4xx：记录失败，不立即重试。
2. 5xx、timeout、connection error：指数退避重试，最多 3 次。
3. TLS 或 CORS 错误：提示来源不可用，保留代卡。

### 11.2 原子写入

图片保存流程：

```text
download bytes
validate signature and size
write user://cards/images/{set}/{index}.tmp
flush and close
rename to final path
update image_cache_manifest.json
emit image_ready
```

避免半张图片被 UI 读到。

### 11.3 校验

必须校验：

1. HTTPS URL。
2. 域名白名单。
3. 文件大小上限。
4. PNG/JPG/WebP 文件签名。
5. 图片解码成功。

建议默认上限：

1. 单张原始图片最大 3 MB。
2. 解码尺寸最大 2048 x 3072。
3. 缩略图缓存可在未来加入，但 MVP 先缓存原图。

### 11.4 缓存预算

建议默认：

1. Windows：500 MB。
2. Android：250 MB。
3. Web：100 MB 或浏览器可用空间的保守值。

LRU 清理规则：

1. 当前正在编辑的卡组不清理。
2. 玩家已保存卡组中使用的卡图优先保留。
3. 最近访问过的卡图优先保留。
4. 失败记录可保留，但不计入图片大小。

## 12. 图片来源策略

优先推荐使用项目自有 CDN 镜像：

```text
https://ptcg.skillserver.cn/card-images/{set_code}/{card_index}.png
```

原因：

1. 可以统一 CORS，支持 Web。
2. 可以稳定控制图片格式、尺寸和缓存头。
3. 可以避免第三方站点结构变更导致客户端失效。
4. 可以在 manifest 中提供 sha256。

兼容来源：

1. `https://tcg.mik.moe/static/img/...`
2. Limitless CDN。

客户端不应该信任分享图、外部卡组文件或用户输入里的图片 URL。所有 URL 必须来自本地 catalog 或项目远程 catalog manifest，并通过白名单。

## 13. 远程目录补丁

虽然下一版会内置完整目录快照，但未来新扩展包和文本修正仍可能需要更新。为减少版本发布，增加可选远程目录补丁。

### 13.1 远程 manifest

地址示例：

```text
https://ptcg.skillserver.cn/card-catalog/catalog_manifest.json
```

流程：

1. 启动后或进入卡组中心时检查远程 manifest。
2. 如果远程 `catalog_version` 高于 bundled version，下载 index 和变更 set 文件。
3. 校验 sha256。
4. 写入 `user://card_catalog`。
5. 下一次搜索使用远程目录。

### 13.2 回滚

如果远程目录损坏：

1. 删除或禁用 `user://card_catalog/remote_manifest.json`。
2. 回退 bundled catalog。
3. 记录错误，但不影响游戏启动。

### 13.3 版本边界

远程目录只能更新：

1. 卡牌文本。
2. 名称和翻译。
3. 基础字段。
4. 图片 URL。
5. 规则实现状态标记。
6. effect alias 数据。

远程目录不能更新 GDScript 规则代码。需要新规则逻辑的卡仍然需要客户端版本更新，除非未来另做安全的规则 DSL。

## 14. 平台差异

### 14.1 Windows

1. 使用 `user://cards/images` 保存图片。
2. 默认允许后台下载当前卡组卡图。
3. 支持较大的缓存预算。
4. 网络失败不弹阻塞窗口，只在卡组中心状态栏提示。

### 14.2 Android

1. 使用应用私有 `user://`，不需要外部存储权限。
2. 默认只在玩家进入卡组中心、导入卡组、打开卡组时下载。
3. 如果能检测网络类型，移动网络下应提示或遵循设置项。
4. 下载队列并发较低，避免卡顿和耗电。
5. 竖屏卡牌代卡必须使用大字号，不能沿用桌面小字布局。

### 14.3 Web

1. Web 版本默认不做大规模自动下载。
2. 如果启用图片下载，必须使用支持 CORS 的项目 CDN。
3. `user://` 持久化依赖浏览器存储，可能被清理。
4. 缓存预算更小，LRU 更激进。
5. Web 失败时不能影响搜索、构筑和对战入口。

## 15. 安全与稳定性

1. 所有图片下载必须走 HTTPS。
2. URL 来源必须是 catalog manifest 中受信来源，不能来自 deck payload。
3. 限制单张图片大小和解码尺寸。
4. 下载失败不能阻塞主线程或 UI 操作。
5. 战斗内禁止新建 HTTPRequest 下载卡图。
6. manifest 写入要使用临时文件和替换，避免崩溃后 JSON 损坏。
7. 下载器必须支持取消，玩家离开卡组中心后低优先级任务可以暂停。
8. 日志中不要输出过长 URL 和用户本地路径。

## 16. 与现有功能的关系

### 16.1 DeckImporter

现状：

1. 导入 tcg.mik 或 Limitless 卡组。
2. 缺卡时拉取卡牌详情并 `CardDatabase.cache_card()`。
3. 导入结束后调用 `CardImageDownloader.sync_cards(cards_to_sync)`。

改造后：

1. 导入时先用 `CardCatalogIndex` 解析本地目录卡。
2. 如果目录已有卡，不再逐张请求 card detail。
3. 只有目录缺失或远程 source 需要补齐时才请求外部卡详情。
4. 导入完成后调用 `CardImageCacheService.ensure_deck_images(deck)`。
5. 导入失败的图片只进入图片错误列表，不影响 deck 保存。

### 16.2 DeckPosterComposer

现状：

1. 读本地图片。
2. 缺图时生成 placeholder。

改造后：

1. 分享图生成前请求当前 deck 的图片下载。
2. 渲染器仍然只读本地，不直接联网。
3. 文字代卡渲染质量要提升到可传播级别，不能只是空白 placeholder。

### 16.3 Battle UI

保持现有原则：

1. 战斗 UI 只读本地缓存。
2. 缺图显示代卡。
3. 不在战斗中下载。

战斗前可以预热：

```gdscript
CardImageCacheService.ensure_deck_images(player_deck, {"priority": "background"})
```

但不能等待图片下载完成才允许战斗开始。

### 16.4 CardImplementationStatus

全量目录会扩大“卡存在”的范围，所以规则实现状态必须更显眼。

建议状态：

```text
implemented
implemented_by_alias
generic_supported
text_only
blocked
unknown
```

卡组中心默认筛选：

1. “可对战”：只显示 implemented、implemented_by_alias、generic_supported。
2. “全部”：显示完整目录。

## 17. 迁移计划

### Phase 0：盘点与测试保护

1. 增加当前 `CardDatabase`、`CardData`、`CardImageDownloader` 的回归测试。
2. 固化“缺图不阻塞”的现有行为。
3. 固化战斗 UI 不发网络请求的约束。

### Phase 1：全量目录只读接入

1. 新增 `data/card_catalog` 生成物。
2. 新增 `CardCatalogIndex.gd`。
3. `CardDatabase.has_card()` 和 `get_card()` 支持 catalog fallback。
4. 卡组中心搜索改为使用 catalog index。
5. 不改图片下载策略，先确保无图可构筑。

验收：

1. fresh install 下能搜索目录中任意卡。
2. 不存在 `user://cards/*.json` 的卡也能加入卡组。
3. 保存再打开卡组可以通过 catalog fallback 找回卡牌。

### Phase 2：文字版代卡统一组件

1. 新增 `CardImageOrProxyView`。
2. 卡组中心搜索、卡组详情先迁移。
3. 分享图渲染器使用同一套代卡数据布局，但用离屏绘制版本。

验收：

1. 删除本地图片缓存后，卡组中心仍完整可用。
2. 竖屏 Android 上代卡文字可读。
3. 分享图缺图时不出现空白卡。

### Phase 3：图片缓存服务

1. 新增 `CardImageCacheService.gd`。
2. 新增 `image_cache_manifest.json`。
3. `CardImageDownloader` 改为内部 worker 或兼容 wrapper。
4. 原子写入、失败重试、缓存预算、LRU 清理。

验收：

1. 打开卡组只下载该卡组 unique cards。
2. 搜索全量卡牌不会触发图片下载。
3. 网络失败后仍显示代卡。
4. 再次打开同一卡组不重复下载已缓存图片。

### Phase 4：导入、分享、战斗预热集成

1. `DeckImporter` 改为优先使用 catalog。
2. 导入后只下载导入卡组图片。
3. `DeckPosterComposer` 生成前请求补图，有 timeout。
4. 对战前后台预热，但战斗内不联网。

验收：

1. 导入卡组不因单张卡图失败而失败。
2. 分享图可以混合真实卡图和文字代卡。
3. 对战中断网不影响已有 UI 操作。

### Phase 5：远程目录补丁

1. 新增远程 manifest 检查。
2. 下载并校验远程 index 和 set 文件。
3. 支持回滚到 bundled catalog。

验收：

1. 不发客户端版本的情况下，可以新增一张 catalog-only 卡供卡组中心搜索和构筑。
2. 远程 manifest 损坏时客户端回退本地目录。

### Phase 6：安装包瘦身

1. 停止打包完整卡图。
2. 只保留必要 UI 图片、默认代卡模板、可选少量首屏推荐卡图。
3. 清理旧的 `res://data/bundled_user/cards/images` 大批量图片。
4. 保留对旧安装用户 `user://cards/images` 的兼容。

验收：

1. 安装包不随全量卡图增长。
2. 老用户已有本地缓存继续可用。
3. fresh install 缺图状态可用。

## 18. 测试方案

### 18.1 单元测试

新增：

```text
tests/test_card_catalog_index.gd
tests/test_card_database_catalog_fallback.gd
tests/test_card_image_cache_service.gd
tests/test_card_proxy_renderer.gd
```

覆盖：

1. catalog manifest 加载。
2. index 搜索。
3. set 文件懒加载。
4. `CardDatabase.get_card()` 从 catalog fallback。
5. user card 覆盖 catalog card。
6. bundled curated card 覆盖 catalog card。
7. 图片 ready/missing/failed 状态。
8. 原子写入和坏图拒绝。
9. LRU 清理不删除当前卡组图片。

### 18.2 集成测试

1. fresh user data，无任何图片缓存，打开卡组中心。
2. 搜索一张只有 catalog 的卡。
3. 加入卡组并保存。
4. 重新打开游戏，卡组仍能解析该卡。
5. 使用 fake HTTP 下载卡图，确认只请求当前卡组 unique cards。
6. 模拟一张图片 404，卡组仍可保存和打开。
7. 生成分享图，缺图位置显示文字代卡。

### 18.3 平台模拟测试

Windows：

1. 清空 `user://cards/images` 后构筑卡组。
2. 检查下载、缓存、二次打开不重复下载。

Android：

1. 竖屏打开卡组中心。
2. 搜索、加入、打开卡组详情。
3. 验证代卡字号、下载进度、失败重试按钮可触摸。

Web：

1. CORS 允许时下载单套卡组图片。
2. CORS 失败时退回代卡。
3. 刷新页面后验证已缓存图片是否仍可读；如果浏览器清理缓存，仍能显示代卡。

### 18.4 防回归约束

必须加测试保证：

1. `CardImageCacheService.ensure_deck_images()` 不会调用全量 `CardDatabase.get_all_cards()` 下载所有卡。
2. 卡组中心搜索不会发图片下载请求。
3. 战斗 UI 不实例化 `HTTPRequest`。
4. 图片下载失败不会导致 `CardDatabase.get_card()` 返回 null。

## 19. 生成工具链

新增构建脚本建议：

```text
scripts/card_catalog/build_card_catalog.gd
scripts/card_catalog/validate_card_catalog.gd
scripts/card_catalog/diff_card_catalog.gd
```

职责：

1. 从 tcg.mik、Limitless、人工修正数据生成统一 card catalog。
2. 补齐 `image_url`、`image_key`、`image_local_path`。
3. 标记 `implementation_status`。
4. 验证所有 `{set_code, card_index}` 唯一。
5. 验证进化链、同名中英字段、基础字段完整性。
6. 输出 catalog manifest、index、set files。
7. 输出差异报告，供版本审核。

构建产物必须是确定性的：同一输入生成同一 JSON 排序和 hash。

## 20. 兼容策略

### 20.1 老用户数据

1. 不删除 `user://cards/images`。
2. 不删除 `user://cards/*.json`。
3. 如果 user card 与 catalog 同 uid，继续优先使用 user card。
4. 后续可提供“重置卡牌数据为官方目录”的维护入口，但不能自动覆盖玩家数据。

### 20.2 旧分享图和卡组码

1. 只要 payload 里有 `{set_code, card_index, count}`，新版本就能通过 catalog 找到卡。
2. 如果 catalog 仍缺卡，导入失败要明确提示具体 uid。
3. 图片缺失不影响导入。

### 20.3 旧 bundled 图片

`CardData.get_image_candidate_paths()` 可继续支持：

1. `user://cards/images/{set}/{index}.png`
2. `res://data/bundled_user/cards/images/{set}/{index}.png.bin`

这样旧版本已打包或少量保留的图片仍然可读。

## 21. 风险与处理

### 21.1 全量目录导致 UI 搜索变慢

处理：

1. 搜索只读 `index.json`。
2. 索引行保持轻量。
3. 支持分页和过滤。
4. 不在搜索列表里实例化完整 `CardData`。

### 21.2 规则未实现卡大量暴露给玩家

处理：

1. 默认筛选“可对战”。
2. “全部”模式明确显示规则状态。
3. 开始规则对战前做 deck validation。

### 21.3 图片源不可用

处理：

1. 优先项目 CDN。
2. 失败退回代卡。
3. manifest 可切换 source_url。
4. 缓存已下载图片。

### 21.4 Web 存储不稳定

处理：

1. Web 默认保守下载。
2. 缓存预算低。
3. 缓存丢失时显示代卡。

### 21.5 user card JSON 遮蔽 catalog 修正

处理：

1. 图片缓存状态不再通过保存 card JSON 实现。
2. 后续提供维护工具识别“仅因图片下载生成的 user card JSON”，并迁移到 sidecar manifest。
3. bundled curated 修正仍保持最高优先级之一。

## 22. MVP 验收标准

MVP 完成时必须满足：

1. fresh install 没有任何卡图缓存，也能在卡组中心搜索全量目录。
2. 玩家能用目录卡构筑并保存卡组。
3. 打开这套卡组时，只下载这套卡组的 unique card images。
4. 下载失败或离线时，卡组仍显示文字版代卡。
5. 重新打开游戏，卡组仍能从 catalog fallback 解析卡牌。
6. 搜索和滚动全量卡牌不会触发全库图片下载。
7. 战斗 UI 不在战斗中发起图片网络请求。
8. 分享图能混合真实卡图和文字版代卡生成。
9. Android 竖屏下文字代卡和下载状态可读、可点。
10. Web 在无持久图片缓存时仍能构筑和展示文字代卡。

### 22.1 端到端验收样本：CSV4C/015 九尾

1. `CSV4C_015` 只存在于 `card_catalog_sources` 和生成后的 `card_catalog`，不进入 `bundled_user/cards`。
2. 仓库中不存在 `CSV4C/015.png` 或 `CSV4C/015.png.bin`。
3. 卡组中心能搜索并显示九尾的文字代卡，代卡上有单卡下载按钮。
4. 单卡按钮只请求 `CSV4C_015`，下载成功后写入 `user://cards/images/CSV4C/015.png`。
5. 将九尾加入构筑时自动提交前台单卡图片任务，不阻塞卡组编辑。
6. “九尾之舞”可以选择对手战斗区或备战区的 1 只宝可梦放置 9 个伤害指示物，并在下一个自己的回合锁定九尾的全部招式。
7. 全量 card-audit 必须显式遍历 catalog-only 卡，状态矩阵中该卡为 `ok | ok | present | covered`。

## 23. 推荐落地顺序

最小可控路径：

1. 先做 `CardCatalogIndex` 和 `CardDatabase` fallback。
2. 再做统一文字代卡组件。
3. 再做 `CardImageCacheService`。
4. 最后接远程目录补丁和安装包瘦身。

不要先做图片下载 UI。否则仍然会被“卡牌数据不存在”卡住，无法验证全量目录价值。

## 24. 待定产品决策

1. 默认是否允许“全部卡”模式构筑规则未实现卡。
2. Android 移动网络下是否默认自动下载当前卡组卡图。
3. 是否保留少量推荐卡组卡图作为首装体验资源。
4. 项目 CDN 是否作为唯一图片来源，还是保留第三方 URL fallback。
5. 远程目录补丁是否在 MVP 启用，还是先只内置 bundled catalog。

建议默认：

1. 卡组中心默认“可对战”，提供“全部卡”开关。
2. Android 移动网络默认不自动下载，只显示一键下载。
3. 不保留大批量首装卡图，只保留代卡模板和 UI 资源。
4. 图片下载优先项目 CDN。
5. MVP 先完成 bundled catalog，远程目录补丁作为第二阶段上线。
