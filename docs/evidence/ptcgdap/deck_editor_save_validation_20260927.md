# 编辑卡组保存校验（2026-09-27）

## 范围与责任层

保存按钮先重算实际总数，再调用 `CardDatabase.validate_deck()`。
该方法复用 `DeckData.validate()` 的 60 张、同名最多 4 张检查，基本能量豁免，
特殊能量不豁免。不同印刷的同名卡合并计数。
ACE SPEC 使用完整 `CardData.is_ace_spec()`（mechanic、rarity、is_tags）判断，
跨所有名称和类型合计最多 1 张；缺失卡牌数据时拒绝无法完整校验的保存。

失败时显示具体原因，保留编辑草稿和 dirty 状态，不调用持久化。
编辑器载入和成功保存时均深拷贝牌组条目，避免保存前或继续编辑时修改数据库缓存。
底层 `save_deck()` 继续保留原有导入等调用语义；本次未修改内置牌组或策略运行时。

## 验证

Godot 4.6.1，自动发现的真实编辑器场景测试，使用隔离 user://。
修改前的新用例复现了超限仍保存、缺少错误提示、编辑污染已保存缓存等问题。
新增用例的合法保存分支随后修正了测试夹具的条目下标和 JSON 数值类型比较，
最终直接检查持久化文件全文。

- `DeckData`：8/8；`DeckEditor`：46/46。
  报告：`.godot_test_user/deck_save_validation_green/0001-DeckData/result.json`
  和 `.godot_test_user/deck_save_validation_green/0002-DeckEditor/result.json`。
- `DeckEditorSaveValidation`：4/4，0 失败、0 跳过。
  报告：`.godot_test_user/deck_save_validation_verified/report.json`。
- 新套件覆盖：同名不同印刷第 5 张；不同 ACE、同一 ACE 两张、ACE 特殊能量；
  普通特殊能量 5 张；过期总数缓存；缺失卡牌数据；合法四张边界、51 张基本能量和单张 ACE；
  保存失败的原文件/缓存保护；修正后再保存；成功保存后继续编辑的副本隔离。
- `git diff --check` 通过。

复现命令：

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner all -Suite 'DeckEditorSaveValidation,DeckEditor,DeckData'
```

这是本地数据与 UI 保存流程的回归证据，不涉及 CABT 对齐、引擎对齐或设备发布验收。

## 回滚

仅移除 `CardDatabase.validate_deck()`、编辑器保存校验和两处深拷贝、
`SaveErrorDialog` 以及新增测试。保留 CardDatabase 原有的内置牌组注册、排序和种子修改，
不要整文件恢复。回滚不需要迁移卡组文件。
