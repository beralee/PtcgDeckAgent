# Contributing

感谢你考虑为 `PTCG Deck Agent` 提交改动。

这个项目已经不只是一个本地 PTCG 模拟器：它同时包含规则引擎、本地练牌客户端、Agent runtime、策略包格式、公开信息边界、跨运行时一致性和 AI 天梯相关能力。

因此我们最看重三件事：

1. **规则与策略边界正确**；
2. **行为可复现、可回归**；
3. **改动能够说明自己证明了什么，也能说明没有证明什么。**

## 最推荐的贡献方式

如果你想最快参与项目，优先考虑下面几类贡献：

### Agent / Strategy

- 用 [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge) 开发新的规则策略或冻结模型；
- 把真实失败局转成公开场景与回归测试；
- 提交 benchmark、decision trace、策略可视化或评测工具；
- 改进 `.ptcgai` package、验证、安装与兼容体验。

### Rules / Engine

- 补充缺失卡牌效果；
- 修正规则结算、identity mapping、交互窗口或状态推进错误；
- 将旧的特殊分支迁移到统一 interaction / effect 框架；
- 为规则与卡效补充最小可复现测试。

### Runtime / Conformance

- 改进 public observation firewall；
- 修复 fresh-window / stale-index / legality 边界问题；
- 改进 Python ↔ GDScript conformance；
- 优化 deterministic build、trace、benchmark 与性能，但保持外部语义不变。

### Product / Developer Experience

- 改进 Strategy Center、对战 UI、卡牌查看、动画和可访问性；
- 改善 Windows / Android 兼容性；
- 改进 Quickstart、测试入口、错误信息和文档；
- 让第一次开发 Agent、第一次跑测试、第一次复现 bug 更简单。

## 提交前先读

- [README.md](README.md)
- [docs/README.md](docs/README.md)
- [docs/development_setup.md](docs/development_setup.md)
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)
- 涉及 Agent runtime 时：[docs/ptcgdap/README.md](docs/ptcgdap/README.md)

## 基本原则

- 所有文本文件统一使用 UTF-8；
- 不把终端乱码、错误解码文本、编辑器缓存或机器本地生成物写回仓库；
- 修改前先读当前实现与测试，不凭卡牌记忆或旧文档猜行为；
- 涉及规则、效果、交互、公开 observation、策略执行或 package 格式时，优先补测试；
- 不为了“先跑起来”绕开既有 BaseEffect、Host、Base authority 或 public-information 边界；
- 不把本地模拟成功描述成更高等级的 CABT parity、production approval 或设备兼容结论。

## 推荐开发流程

1. 明确问题与 owning layer；
2. 阅读相关代码、合同和历史验证记录；
3. 先写失败测试、固定场景，或至少定义可执行验收方式；
4. 做最小范围修改；
5. 运行 focused tests，再跑必要的 broader regression；
6. 对 Agent 行为变化，优先保留 first-divergence trace 或 paired benchmark；
7. 在 PR 中写清行为变化、证据、已知缺口与回滚方式。

## 测试要求

下面这些改动默认应该附带自动化或明确的可复现验证：

- 规则引擎与卡牌效果；
- BattleScene / interaction chain；
- public observation 与隐藏信息隔离；
- author strategy Host / executor；
- Python ↔ GDScript conformance；
- `.ptcgai` package loader、签名与兼容边界；
- 卡组导入、identity / UID 映射；
- 文本批量修改、编码与生成流程。

仓库中常用入口包括：

```powershell
# 请替换为你本机的 Godot console 路径
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FunctionalTestRunner.gd
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/AITrainingTestRunner.gd
```

涉及 PtcgDAP / author strategy 的改动，请同时阅读对应 `docs/ptcgdap/` 记录，优先运行该工作包声明的 focused tests 和 conformance vectors。

## PR 建议写法

一个好的 PR 不需要写得很长，但应该能回答：

- **改了什么？**
- **为什么这是正确的 owning layer？**
- **改动前怎样失败？改动后怎样证明通过？**
- **跑了哪些测试 / 场景 / benchmark？**
- **有没有改变公开接口、规则语义或 package 兼容性？**
- **哪些更高等级结论仍然不能由本 PR 声明？**
- **如果需要回滚，最小回滚单元是什么？**

对于策略强度改进，仅报告“赢了几局”通常不够。能提供固定 seed、seat swap、对手版本、第一处分歧和 policy audit 会更有价值。

## 不建议直接提交的内容

- `.godot/` 编辑器缓存；
- 本地日志、临时文件、isolated test roots；
- 可重新生成的大体积训练中间产物；
- 用户本地缓存的卡牌 JSON 与卡图；
- 私钥、API Key、数据库凭据、部署配置等秘密材料；
- 与仓库公开目标无关的 AI 助手个人配置。

如果某份 evidence 对验证非常重要，请优先保留最小、可解释、可复现的版本，而不是把整个实验工作目录提交进来。

## 关于策略与私有信息

第三方 Agent 只能依赖公开合同允许的信息。任何能够读取或推断对手隐藏手牌、牌库顺序、盖放奖赏、私有 RNG、内部 engine object 或其他非公开状态的实现，都不属于可接受的竞争策略贡献。

安全与公平边界不是为了限制策略创新，而是为了让不同策略的 benchmark 有意义。

## 关于许可证与素材

如果改动涉及外部资源、卡图、第三方文本、模型、数据集或模板，请在 PR 中明确来源与授权边界。对这类内容，宁可保守，也不要含糊。

Pokémon、Pokémon TCG 及相关名称、图像与知识产权归各自权利方所有；本项目为非官方学习与研究项目。
