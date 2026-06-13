# 导入卡组同名同效果卡牌兜底注册设计

## 背景

现在卡组导入的主链路在 `scripts/network/DeckImporter.gd`：

1. 从 `tcg.mik.moe` 获取卡组详情。
2. 对本地缺失的卡逐张请求卡牌详情。
3. 用 `CardData.from_api_json()` 构造卡牌数据。
4. 调用 `CardDatabase.cache_card(card_data)` 写入 `user://cards/`。
5. 后续对战通过 `CardDatabase.build_deck_instances()` 取卡并创建实例。

卡牌是否“已实现”并不是导入阶段判断的，而是运行时通过以下链路判断：

- `CardImplementationStatus.gd` 根据卡牌文本、`effect_id` 和 `EffectProcessor` 注册情况判断是否未实现。
- `EffectProcessor.gd` 负责注册和执行效果。
- `EffectRegistry.gd` 集中注册训练家、特殊能量、竞技场、宝可梦特性/招式效果。
- 宝可梦卡的注册依赖 `EffectRegistry.register_pokemon_card(processor, card)`，当前主要按招式名、特性名或少量硬编码 `effect_id` 别名匹配。

因此，当导入一张新编号卡牌时，即使它和游戏里已有同名卡牌效果完全一样，只要它自己的 `effect_id` 没有注册，也会被判定为未实现。

## 目标

当导入卡组时，如果导入卡牌未实现，系统自动尝试兜底：

1. 搜索游戏中所有已知卡牌，包括 `user://cards/` 和 `res://data/bundled_user/cards/`。
2. 找到同名卡牌。
3. 只在双方效果签名完全一致，并且候选卡牌已经实现时，建立效果别名。
4. 让导入卡牌保持自己的卡牌编号、图片、HP、弱点、撤退等原始数据，只复用已实现同名卡牌的效果逻辑。
5. 玩家导入卡组时不需要额外操作。

## 非目标

- 不做模糊语义判断，比如“文本看起来差不多”但不完全一致时不自动兜底。
- 不用同名直接替换卡牌数据。
- 不修改原始 `CardData.effect_id`，避免污染卡牌身份和审计结果。
- 不处理缺少 `effect_id` 的卡牌。第一版只处理“有 `effect_id` 但未注册”的情况。
- 不替代 `$card-audit`。该功能只是减少重复卡导致的未实现，不隐藏真正的新效果。

## 设计概览

新增一个独立服务：

`scripts/engine/CardEffectAliasResolver.gd`

职责：

- 为卡牌生成稳定的“效果签名”。
- 查找同名、同签名、已实现的候选卡。
- 建立 `imported_effect_id -> source_effect_id` 的别名。
- 向状态判断和运行时效果执行提供别名查询。

同时在 `CardDatabase.gd` 中增加别名存储和导入入口：

- `try_register_duplicate_effect_alias(card: CardData) -> Dictionary`
- `get_effect_alias(effect_id: String) -> String`
- `get_effect_alias_metadata(effect_id: String) -> Dictionary`

别名数据持久化到：

`user://cards/effect_aliases.json`

## 效果签名

效果签名用于判断“完全一样”。第一版采用严格匹配，宁可漏掉，也不要错配。

### 通用字段

- `card_type`
- `name` 或 `name_en` 的规范化同名判断
- 是否有规则文本

### 宝可梦卡

签名包含：

- `card_type`
- `stage`
- `mechanic`
- `abilities`，按顺序包含：
  - `name`
  - `text`
- `attacks`，按顺序包含：
  - `name`
  - `cost`
  - `damage`
  - `text`
  - `is_vstar_power`

不把 `hp`、弱点、抵抗、撤退费用放进效果签名，因为别名只复用效果实现，战斗数值仍然来自导入卡本身。不过 `stage` 和 `mechanic` 会保留，避免基础宝可梦、进化宝可梦、VSTAR 等不同结构被错误匹配。

### 训练家、特殊能量、竞技场

签名包含：

- `card_type`
- `description`
- 子类型信息，比如 `Item`、`Supporter`、`Tool`、`Stadium`
- 特殊能量额外包含能量提供信息，如果 `CardData` 中存在对应字段

### 文本规范化

文本只做安全规范化：

- 去掉首尾空白。
- 统一 `\r\n`、`\r` 为 `\n`。
- 连续空白折叠。
- 全角和半角不做复杂转换。
- 不做同义词、标点模糊匹配。

这样可以确保自动兜底只命中真正重复的卡。

## 别名数据结构

`user://cards/effect_aliases.json`：

```json
{
  "version": 1,
  "aliases": {
    "imported_effect_id": {
      "source_effect_id": "implemented_effect_id",
      "source_set_code": "SV...",
      "source_card_index": 123,
      "alias_set_code": "CSV...",
      "alias_card_index": 456,
      "signature_hash": "sha256...",
      "reason": "same_name_same_effect_signature",
      "created_at": 1780000000000
    }
  }
}
```

加载别名时会重新校验：

- 导入卡还存在。
- 来源卡还存在。
- 双方签名仍然一致。
- 来源卡仍然已实现。

校验失败则本次忽略该别名，不删除文件，避免版本升级时产生不可逆数据损坏。

## 导入流程改造

在 `DeckImporter.gd` 成功拉取并缓存卡牌后增加一步：

```gdscript
CardDatabase.cache_card(card_data)
var alias_result = CardDatabase.try_register_duplicate_effect_alias(card_data)
```

返回值示例：

```gdscript
{
  "applied": true,
  "source_name": "大地容器",
  "source_set_code": "SV...",
  "source_card_index": 123,
  "source_effect_id": "...",
  "alias_effect_id": "..."
}
```

如果 `applied == true`，导入流程可以记录一条非阻塞提示：

`已为「大地容器」套用同名同效果卡牌的实现`

如果没有命中，不影响导入，不额外弹窗。

## 运行时改造

### EffectProcessor

`EffectProcessor` 增加内部解析：

```gdscript
func _resolve_effect_id(effect_id: String) -> String:
    var alias := CardDatabase.get_effect_alias(effect_id)
    return alias if alias != "" else effect_id
```

以下接口都需要走解析后的 id：

- `has_effect(effect_id)`
- `get_effect(effect_id)`
- `has_attack_effect(effect_id)`
- 通过 `effect_id` 获取招式交互步骤的接口
- 通过 `effect_id` 执行招式效果的接口

### 宝可梦效果注册

宝可梦卡比训练家更复杂，因为宝可梦效果通常不是 `register_all()` 时统一注册，而是在 `register_pokemon_card(card)` 时按卡注册。

当 `register_pokemon_card(imported_card)` 发现 `imported_card.effect_id` 有别名时：

1. 从别名元数据找到来源卡。
2. 用 `CardDatabase.get_card(source_set_code, source_card_index)` 读取来源卡。
3. 先注册来源卡。
4. 后续执行导入卡效果时，`_resolve_effect_id()` 会映射到来源 `effect_id`。

这样导入卡不会改自己的 `effect_id`，但运行时能复用来源卡的实际效果。

### CardImplementationStatus

`CardImplementationStatus` 需要感知别名，否则 UI 仍会显示未实现。

调整方式：

- 判断未实现前先检查 `CardDatabase.get_effect_alias(card.effect_id)`。
- 如果别名存在并且来源卡已实现，则当前卡视为已实现。
- 可选增加状态字段：
  - `aliased: true`
  - `alias_source: "SV... 123"`

UI 第一版不需要展示这个字段，但审计和调试日志可以使用。

## 候选选择规则

候选卡来自 `CardDatabase.get_all_cards()`。

必须满足：

1. 与导入卡不是同一张卡。
2. 同名：
   - 优先 `name` 完全一致。
   - 如果 `name` 为空，则比较 `name_en`。
3. 候选卡不是未实现卡。
4. 候选卡有非空 `effect_id`。
5. 效果签名完全一致。

歧义处理：

- 如果没有候选，跳过。
- 如果只有一个候选，建立别名。
- 如果多个候选签名一致且来源 `effect_id` 一致，可以建立别名。
- 如果多个候选签名一致但来源 `effect_id` 不一致，跳过并记录日志。
- 如果同名但签名不同，跳过。

## 和现有 CSV9C 别名的关系

`EffectRegistry.CSV9C_EFFECT_ID_ALIASES` 是硬编码的特定补丁。

新的 `CardEffectAliasResolver` 是数据驱动的通用兜底：

- 先保留现有硬编码别名，不做迁移。
- 新兜底只处理导入时发现的重复卡。
- 如果一张卡已经被硬编码别名覆盖，不再重复写入用户别名文件。

## 测试计划

使用 TDD 落地，建议新增或扩展以下测试。

### 1. 签名匹配测试

新增：

`tests/test_card_effect_alias_resolver.gd`

覆盖：

- 同名、同描述、来源已实现的道具卡可以生成别名。
- 同名但描述不同的道具卡不能生成别名。
- 同名、同特性/招式的宝可梦可以生成别名。
- 招式顺序不同不能生成别名。
- 来源卡未实现时不能生成别名。
- 多个候选来源 `effect_id` 不一致时不能生成别名。

### 2. 状态判断测试

扩展：

`tests/test_card_implementation_status.gd`

覆盖：

- 未注册 `effect_id` 的导入卡在建立别名后不再显示未实现。
- 没有别名或别名校验失败时仍显示未实现。

### 3. 运行时效果测试

新增：

`tests/test_effect_processor_alias.gd`

覆盖：

- `has_effect(alias_id)` 能通过来源 `effect_id` 返回 true。
- `get_effect(alias_id)` 返回来源效果对象。
- 宝可梦导入卡调用 `register_pokemon_card()` 时能先注册来源卡。
- 攻击效果通过导入卡 `effect_id` 可以执行到来源实现。

### 4. 导入链路测试

扩展：

`tests/test_deck_importer.gd`

不需要真实网络，构造卡牌数据后直接模拟：

- `CardDatabase.cache_card(source_card)`
- `CardDatabase.cache_card(imported_card)`
- `CardDatabase.try_register_duplicate_effect_alias(imported_card)`

验证别名文件和返回结果。

### 5. 审计回归

运行：

- `tests/test_card_catalog_audit.gd`
- 现有脚本加载回归测试
- 关键导入卡组编辑和对战构建测试

## 风险与控制

### 风险：误把相似卡当成同效果卡

控制：

- 第一版只做严格签名匹配。
- 不做语义模糊。
- 多候选冲突直接跳过。

### 风险：别名来源卡升级后效果变化

控制：

- 别名加载时重新计算 `signature_hash`。
- 校验失败时忽略别名。

### 风险：宝可梦来源卡没有被注册

控制：

- `register_pokemon_card(imported_card)` 通过别名元数据先注册来源卡。
- 如果来源卡找不到，当前卡仍按未实现处理。

### 风险：审计被兜底掩盖问题

控制：

- `CardImplementationStatus` 可以记录 `aliased` 状态。
- `$card-audit` 后续可以把别名卡单独列出，方便人工确认。

## 落地顺序

1. 新增 `CardEffectAliasResolver.gd`，先完成签名生成和纯函数测试。
2. 在 `CardDatabase.gd` 增加别名文件加载、保存和查询。
3. 在 `CardDatabase.cache_card()` 或导入后新增 `try_register_duplicate_effect_alias()`。
4. 在 `EffectProcessor.gd` 增加 `effect_id` 解析，并覆盖普通效果接口。
5. 补齐宝可梦 `register_pokemon_card()` 的来源卡注册逻辑。
6. 更新 `CardImplementationStatus.gd`，让 UI 状态正确。
7. 接入 `DeckImporter.gd`，导入时自动尝试兜底。
8. 跑完整卡牌状态和导入回归测试。

## 验收标准

- 导入一张未注册但同名同效果的卡牌后，系统自动建立别名。
- 该卡在卡组编辑和对战设置中不显示未实现。
- 进入对战后，该卡效果能按来源同名卡正常执行。
- 同名但效果文本不同的卡不会被自动注册。
- 多候选冲突时不会自动注册。
- 旧有卡牌实现、CSV9C 硬编码别名和卡组导入功能不受影响。
