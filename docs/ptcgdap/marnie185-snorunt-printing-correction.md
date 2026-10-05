# 675700 雪童子印刷更正（2026-09-20）

用户最终指定 `CSV9.5C/043`。内置 `675700`「18.5 玛俐的长毛巨魔 雪妖女」中原有 3 张 `CSV6C/032` 全部更换为该印刷；其余 57 张、60 张总数、24 种印刷和原始导入时间保持不变。先前提及的 `CSV7C/057` 已由用户撤回，没有应用。

牌表行同步绑定 `f6baf0c4c60ff47c7f836c1271f40cb3` 效果身份。卡库已包含完整的 60 HP、撤退费用 1、惊吓 `WC` 招式及图片，本次没有修改卡牌效果或攻击规则。

`CardDatabase.BUNDLED_DECK_CARD_REPLACEMENTS` 增加针对 `675700` 的精确 UID 迁移。启动时更新旧内置牌表的玩家副本；AI 目录直接读取修正后的内置牌表。沿用已有时间戳保护，较新的玩家自定义牌表不覆盖；不通过中文同名替换其他雪童子印刷。保留原始 `import_date` 和 `updated_at`，避免改变列表排序或将较新的玩家选择误判为旧种子。

使用现有生成器刷新 `_seed_content_sha256.txt`。Manifest 已包含此牌及图片，没有新增或删除卡组，也没有改变 AI 注册或 LLM 适配声明。

验证：

- 专项 RED：7 项中的 4 项失败，分别证明错误牌表、缺少旧存档迁移、重排后的迁移缺口、实际玩家/AI 目录仍为旧印刷。
- 修正后自动发现的 `BundledDeckCatalog`、`CardDatabaseSeed`、`Marnie185SnoruntSeed` 共 101/101 通过。
- `python -m unittest tests.ptcgdap.test_bundled_seed_revision -v` 1/1 通过。
- 新专项覆盖精确印刷/60 张、原导入时间、重复执行、顺序重排、较新玩家编辑、错误卡组、其他印刷、缺失目标及两个目录的 60 张实际战斗实例构建。

复现：

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner functional -Suite 'BundledDeckCatalog,CardDatabaseSeed,Marnie185SnoruntSeed' -UserDataRoot .godot_test_user\marnie185-sn043-check
python -m unittest tests.ptcgdap.test_bundled_seed_revision -v
```

仅证明本地内置牌表、种子迁移和目录/实例构建正确；不声明完整对战、平台资格或官方 CABT 规则一致。游戏需要重新启动才能刷新已经缓存在内存的目录。本次没有打包或发布游戏更新。

回滚仅撤销 `675700.json` 的该牌行和 `BUNDLED_DECK_CARD_REPLACEMENTS` 的 675700 条目，再运行种子摘要生成器；不要回退同文件中其他任务的已有修改。
