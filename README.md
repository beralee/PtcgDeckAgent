# PTCG Deck Agent

<p align="center">
  <a href="https://ptcg.skillserver.cn/">
    <img src="https://ptcg.skillserver.cn/dist/assets/dojo-home-design.png" alt="PTCG Deck Agent - Open PTCG Agent Arena" width="100%" />
  </a>
</p>

<p align="center">
  <strong>Build a PTCG AI. Battle other AIs. Benchmark every decision. Share it with players.</strong>
</p>

<p align="center">
  一个开放的 PTCG Agent 竞技场与本地练牌客户端：<strong>开发策略 → 对战验证 → 进入天梯 → 被真实玩家挑战</strong>。
</p>

<p align="center">
  <a href="https://ptcg.skillserver.cn/">玩家客户端</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/competition.html">AI 天梯</a>
  ·
  <a href="https://github.com/beralee/ptcg-strategy-forge">Strategy Forge</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/developers.html">开发者中心</a>
  ·
  <a href="README_EN.md">English</a>
  ·
  <a href="docs/README.md">文档</a>
</p>

## Build. Battle. Benchmark. Share.

`PTCG Deck Agent` 最初是一个本地 PTCG 练牌器，现在正在演化成一个面向开发者、研究者与玩家的 **Open PTCG Agent Arena**。

它不是“给游戏接一个聊天机器人”。项目真正想解决的是另一类问题：

> **如何让不同方法写出的 PTCG AI，在同一个公开信息边界、同一个合法动作合同和可复现的对局环境里竞争，并把优秀策略安全地分发给玩家。**

| 你是谁 | 你可以做什么 |
| --- | --- |
| **Agent 开发者** | 用 [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge) 编写规则策略或导入冻结模型，验证、构建并发布 `.ptcgai` |
| **Game AI / RL 研究者** | 在统一公开 observation、决策 trace、固定场景和 paired benchmark 上比较 rules / BC / RL / search / planning |
| **PTCG 玩家** | 在本地客户端挑战内置或社区 AI，用真实失败局练牌、复盘并反馈策略作者 |
| **规则与引擎贡献者** | 改进规则正确性、卡牌效果、跨运行时一致性、回归测试和多平台体验 |

## 一个很小的 Agent 接口

平台对策略暴露的核心边界刻意保持简单：

```text
agent(raw_observation) -> list[int]
```

Agent 只能在**当前合法选择窗口**中返回索引。一次选择被接受后，旧窗口立即失效，策略必须重新观察、重新绑定再做下一次决定。

这条边界背后有几个重要约束：

- **Public information only**：对手隐藏手牌、牌库顺序、盖放奖赏、私有 RNG 和可变引擎对象不会进入策略输入。
- **Fresh-window decisions**：动作不是长期持有的 engine handle；每一次交互都重新观察当前合法选项。
- **Data-only distribution**：`.ptcgai` 不允许携带任意 Python、GDScript、原生库或网络执行能力。
- **Device-local execution**：玩家挑战社区策略时，策略决策链可以直接在 Godot 客户端本地运行，不要求运营方托管推理服务。
- **Reproducible evidence**：固定场景、decision trace、录像、跨运行时 conformance 和 benchmark 用来定位“第一处错误决策”，而不只看最后一场输赢。

这让规则策略、模仿学习、强化学习、有限搜索和多回合规划可以在同一竞技边界里被比较，而不是各自搭一套不可复现的 demo。

## 从一个牌组想法到 AI 天梯

```text
理解牌组与胜利路线
  → 用 PTCG Strategy Forge 创建策略工作区
  → 写规则策略，或导入冻结模型
  → 用场景和公开窗口做 RED → GREEN 迭代
  → check / build 得到确定性 .ptcgai
  → 本机签名并上传开发者中心
  → 通过独立资格验证后进入 AI 天梯
  → 从真实对局、录像与玩家反馈继续迭代
```

开发验证、平台资格、天梯表现、Godot 规则见证、官方 CABT engine parity 和正式发布许可是不同的证据等级。项目只对已有明确证据的范围作声明。

## 开发你的第一个 PTCG Agent

策略开发集中在独立仓库 [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge)，不需要先成为 Godot 或规则引擎开发者。

当前作者工具链主要验证于 **Windows + PowerShell 7 + Python 3.13**：

```powershell
git clone https://github.com/beralee/ptcg-strategy-forge.git
cd ptcg-strategy-forge
.\setup.ps1
.\forge.ps1 doctor
```

正式创建作者工作区目前仍需要在[开发者中心](https://ptcg.skillserver.cn/dist/developers.html)取得开发者 ID，用于稳定的作者与 package 身份。私钥只在发布签名时保留在开发者自己的电脑上，平台只登记公钥。

Forge 的日常迭代循环是：

```text
inspect → scenario → check → build → local battle → trace → improve
```

你主要关心三类东西：

1. **Strategy Blueprint**：这套牌怎么赢、攻击节奏是什么、资源给谁、什么条件下必须重新规划；
2. **Data-only policy / frozen actor**：把当前合同能够执行的策略编译成受限规则或冻结模型；
3. **Scenarios & traces**：用正例、负例、option 重排和真实失败局固定策略行为。

完整入口：

- [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge)
- [Forge Quickstart](https://github.com/beralee/ptcg-strategy-forge/blob/main/docs/01-QUICKSTART.md)
- [从注册到上传：开发者指南](https://ptcg.skillserver.cn/dist/developer-guide.html)
- [本仓库作者策略开发指南](docs/ptcgdap/10-author-strategy-developer-guide.md)

## 为什么它不只是另一个 PTCG 模拟器

### 1. Agent 与规则引擎之间有明确边界

策略不直接操作 BattleScene、节点、对象引用或隐藏状态。规则引擎拥有合法性和状态推进，Agent 只对当前公开窗口提出选择。

### 2. Base layer 守住安全底线

合法性、强制/终局处理、cardinality、veto、transaction safety、fresh rebind 和确定性 fallback 由平台基础层负责。策略可以变聪明，但不能因为“更聪明”就越过规则边界。

### 3. Python 开发路径与 GDScript 玩家运行时需要对齐

Python 用于 Forge / reference validation，GDScript 是设备本地执行基线。共享合同、向量和 differential tests 用来发现两端语义漂移。

### 4. Benchmark 不是只报一个胜率

项目鼓励保留：

- 固定 seed 与 seat swap
- 第一处分歧 decision trace
- 场景回归与 option reorder
- policy success / rejection / fallback audit
- known gaps 与 rollback identity

策略改进应该能回答：**哪一个公开事实改变了哪一个决策，为什么，以及新版本是否真的更好。**

公开实现状态、验证记录与已知缺口见：

- [PtcgDAP public status](docs/ptcgdap/STATUS.md)
- [Competitive Author Policy v2](docs/ptcgdap/30-competitive-author-policy-v2.md)
- [Validation / promotion / rollback](docs/ptcgdap/05-validation-promotion-and-rollback.md)

## 玩家：挑战社区 AI

1. 从[下载页](https://ptcg.skillserver.cn/dist/index.html#download)获取客户端。
2. 在 [AI 策略天梯](https://ptcg.skillserver.cn/dist/competition.html)查看策略排名、近期表现和作者。
3. 在客户端选择内置 AI，或通过“AI 策略中心”加载兼容 `.ptcgai`。
4. 在统一 AI 对手选择器中开始设备本地对战。
5. 用日志、录像和复盘找到真正值得练习的 AI，也把失败样本反馈给策略作者。

AI 卡组教练、对局问答等可选 LLM 能力与本地策略执行是隔离的；这些附加能力可能需要单独配置在线模型服务。

## 画面预览

<p align="center">
  <img src="https://ptcg.skillserver.cn/dist/assets/demo_menu.png" alt="Main menu" width="49%" />
  <img src="https://ptcg.skillserver.cn/dist/assets/demo_ai_card.webp" alt="AI deck discussion" width="49%" />
</p>

<p align="center">
  <img src="https://ptcg.skillserver.cn/dist/assets/demo4.webp" alt="Battle scene" width="49%" />
  <img src="https://ptcg.skillserver.cn/dist/assets/demo3.webp" alt="Battle overview" width="49%" />
</p>

## 技术结构

```text
contracts/   CABT、公开 observation、策略包、执行器和跨运行时合同
data/        内置卡组、卡牌、卡图和作者策略包
docs/        架构、开发者指南、策略迭代和验证记录
scenes/      Godot 场景、策略中心、对战设置和回放 UI
scripts/     规则引擎、Host、AI 策略、本地执行器和赛事系统
tests/       合同、卡效、策略、场景、UI 和回归测试
tools/       策略包、验证、证据和开发辅助工具
```

关键边界：

1. `scripts/engine/`：规则推进、选择窗口、状态转换和效果调度。
2. `scripts/ai/ptcgdap/`：公开 observation、策略包、Host、本地执行、conformance 和 trace。
3. `scripts/effects/`：卡牌、攻击、特性、训练家、工具和竞技场效果。
4. `scenes/battle_setup/` 与策略中心：统一玩家入口，同时保持经典 AI 与作者策略 runtime owner 分离。
5. `scripts/tournament/`：本地瑞士轮赛事流程。

## 本地运行游戏客户端

### 环境

- Godot `4.6.x`
- Windows 是当前重点验证平台
- Android 完整设备验收仍在推进
- 本地策略对战不需要系统 Python 或远程推理

### 启动

1. 用 Godot 打开仓库根目录 `project.godot`。
2. 运行 `res://scenes/main_menu/MainMenu.tscn`。
3. 从“AI 对战”选择内置或已加载策略，或进入卡组管理与赛事模式。

### 常用测试

```powershell
# 在仓库根目录执行；替换为你本机 Godot 路径
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FunctionalTestRunner.gd
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/AITrainingTestRunner.gd
```

## 当前状态与边界

这是一个高速迭代中的开源 PTCG Agent 平台，同时保留完整的本地练牌与规则模拟能力。

- 已具备作者策略包、Forge 开发工作流、公开策略合同、Godot 本地执行、统一 AI 对手选择器、策略排名和验证基础设施。
- Windows 是当前主要产品与开发目标；Android 完整设备验收仍是开放工作。
- 当前公开仓库不代表完整官方裁判程序；official CABT engine parity 只在明确记录的范围内声明。
- 第三方策略要分别经过包完整性、兼容性、签名、资格和设备门；“本地开发通过”不等于“已进入天梯”或“所有设备均批准”。

详细状态见 [STATUS.md](docs/ptcgdap/STATUS.md) 和 [IMPLEMENTATION_CHECKLIST.md](docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md)。

## 参与贡献

最直接的参与方式不是先改引擎，而是：**做一个 Agent，让它真正打起来。**

我们尤其欢迎：

- 新的规则策略、冻结模型、公开场景和 `.ptcgai` package
- 可复现的错误决策、benchmark、trace 和可视化工具
- 卡牌效果、规则、identity mapping 与交互链路修复
- Python ↔ GDScript conformance 和 deterministic build 改进
- Strategy Center、战斗 UI、可访问性和多平台体验
- 文档、Quickstart、测试入口和开发者体验改进

提交前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## Disclaimer

这是一个非官方、非商业的学习与研究项目。Pokémon、Pokémon TCG、卡牌名称、图片、规则文本及相关知识产权归各自权利方所有。本项目不受官方权利方背书或关联，也不替代官方产品。

如果你 fork 本项目、发布策略或基于它继续开发，请保留这一边界。

## License

[Apache License 2.0](LICENSE)
