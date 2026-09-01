# PTCG Deck Agent

<p align="center">
  <a href="https://ptcg.skillserver.cn/">
    <img src="https://ptcg.skillserver.cn/dist/assets/dojo-home-design.png" alt="PTCG Deck Agent - PTCG AI Agent 策略平台" width="100%" />
  </a>
</p>

<p align="center">
  <strong>开放的 PTCG AI Agent 策略平台：开发策略、验证对局、参与 AI 天梯，并把优秀策略带到每一位玩家的本地客户端。</strong>
</p>

<p align="center">
  <a href="https://ptcg.skillserver.cn/">游戏官网</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/competition.html">AI 策略天梯</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/developers.html">开发者中心</a>
  ·
  <a href="https://github.com/beralee/ptcg-strategy-forge">PTCG Strategy Forge</a>
  ·
  <a href="README_EN.md">English</a>
  ·
  <a href="docs/README.md">项目文档</a>
</p>

## PTCG AI Agent 策略平台

`PTCG Deck Agent` 已经从本地练牌器成长为面向开发者与玩家的 PTCG AI Agent 策略平台。

- **对开发者**：使用 [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge) 创建规则策略或导入冻结模型，在公开信息边界内完成场景测试、确定性构建和本地验证，再通过[开发者中心](https://ptcg.skillserver.cn/dist/developers.html)签名上传，参与持续运行的 AI 策略天梯。
- **对玩家**：下载客户端和兼容的 `.ptcgai` 策略包，在统一的 AI 对手选择器中选择内置或社区策略，本地完成 AI 对战、练牌和复盘，并通过[策略排名](https://ptcg.skillserver.cn/dist/competition.html)寻找当前表现最强、最适合自己练习的 AI。
- **对研究者与贡献者**：围绕同一个公开策略边界、可复现对局、决策轨迹和回归测试，研究规则策略、模仿学习、强化学习、有限搜索与多回合规划。

平台的公共策略接口保持简单：

```text
agent(raw_observation) -> list[int]
```

策略只能返回当前合法选择窗口中的索引。每次选择后都必须重新观察和绑定；对手隐藏手牌、牌库顺序、盖放奖赏、私有随机状态和引擎对象不会进入策略输入。

## 从策略创意到 AI 天梯

```text
注册开发者账号并取得开发者 ID
  -> 使用 PTCG Strategy Forge 创建策略工作区
  -> 编写规则策略或导入冻结模型
  -> 场景测试、严格校验与确定性构建
  -> 在本机使用私钥签名 .ptcgai
  -> 上传开发者中心并完成资格验证
  -> 进入 AI 天梯，与内置和社区策略持续对战
  -> 玩家下载策略、本地挑战、复盘并反馈
```

开发、资格验证、天梯表现和玩家端执行是相互独立的门。一个包通过本地开发检查，并不自动代表已获得平台资格、官方 CABT 引擎一致性或所有设备的发布许可。

## 开发者：打造你的 PTCG AI

### 为什么参与

- **统一策略合同**：所有策略面对同一公开观察和当前合法选项，不直接操纵规则引擎。
- **Forge 完整工具链**：提供工作区脚手架、规则/模型模式、支持卡牌快照、场景检查、确定性构建、校验和本地模拟。
- **可复现的对局证据**：使用决策 trace、录像、固定场景和 benchmark 定位第一处错误决策，而不是只看最终胜率。
- **持续 AI 天梯**：策略与内置 AI、其他开发者策略持续比赛，按稳定 release 身份展示排名和对局表现。
- **玩家真实反馈**：玩家可以加载兼容策略进行本地对战，优秀策略不只停留在离线实验中。
- **安全的数据包格式**：`.ptcgai` 是经过校验的数据包，不允许携带任意 Python、GDScript、原生库或网络执行能力。

### 快速开始

当前作者工具链以 Windows、PowerShell 7 和 Python 3.13 为主。先访问[开发者中心](https://ptcg.skillserver.cn/dist/developers.html)注册账号并取得完整开发者 ID，然后安装 Forge：

```powershell
git clone https://github.com/beralee/ptcg-strategy-forge.git
cd ptcg-strategy-forge
.\setup.ps1
.\forge.ps1 doctor
```

接下来按公开指南完成工作区创建、策略编写、支持卡牌核对、场景验收、构建、公钥登记、本机签名和上传：

- [从注册到上传：完整开发者指南](https://ptcg.skillserver.cn/dist/developer-guide.html)
- [开发者中心：账号、密钥与策略上传](https://ptcg.skillserver.cn/dist/developers.html)
- [PTCG Strategy Forge 源码与文档](https://github.com/beralee/ptcg-strategy-forge)
- [本仓库作者策略开发指南](docs/ptcgdap/10-author-strategy-developer-guide.md)

私钥始终只保存在开发者自己的电脑上；开发者中心只登记公钥。不要把私钥、API Key 或其他凭据提交到 Git、粘贴到网页或放进策略包。

## 玩家：挑战社区 AI

1. 从[游戏官网下载区](https://ptcg.skillserver.cn/dist/index.html#download)获取客户端。
2. 在[AI 策略天梯](https://ptcg.skillserver.cn/dist/competition.html)比较策略排名、近期表现和作者信息。
3. 在客户端选择内置 AI，或通过“AI 策略中心”加载兼容的 `.ptcgai` 策略包。
4. 在统一的“AI 卡组”选择器中挑选对手，开始设备本地对战。
5. 结合对局日志、录像和复盘结果，寻找最强策略，也帮助作者继续迭代。

策略对战的 aligned 决策链在玩家设备本地运行，不要求运营方托管推理服务。AI 卡组教练、对局问答等可选 LLM 功能与本地策略对战是隔离能力；使用这些可选功能时可能需要单独配置在线模型服务。

## 平台能力

- **作者策略包**：发现、校验、安装并按稳定身份加载 `.ptcgai`；作者、策略、牌组、版本和内容哈希共同确定一个 release。
- **AI 策略天梯**：展示内置与开发者策略的持续联赛排名、对局数量、近期表现和作者榜。
- **设备本地执行**：受限策略 IR 和本地执行器在 Godot 客户端内运行，策略不能直接调用引擎方法。
- **公开信息防火墙**：策略只消费 allow-list 公开观察；隐藏牌、私有 RNG、搜索凭据和可变引擎对象被隔离。
- **当前窗口安全**：输出只能是当前 `select.option` 索引；选择后旧窗口、旧索引和旧 authority 立即失效。
- **Base Graph 保护**：合法性、强制/终局处理、交易安全、veto 和确定性 fallback 由平台基础层统一负责。
- **双运行时一致性**：Python 用于开发与参考验证，GDScript 是玩家设备上的便携执行基线；两端使用共享合同和向量核对。
- **录像与策略迭代**：对局日志、公开录像、决策 trace、场景快照和 benchmark 支持定位策略分歧并构建回归测试。
- **练牌与比赛模式**：普通 AI 对战、本地双人、卡组管理、AI 卡组教练、瑞士轮赛事和复盘能力继续保留。

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
contracts/   CABT、公开观察、策略包、执行器和跨运行时一致性合同
data/        内置卡组、卡牌、卡图和作者策略包
docs/        架构、开发者指南、策略迭代与验证记录
scenes/      Godot 场景、策略中心、对战设置和回放界面
scripts/     规则引擎、Host、AI 策略、本地执行器和比赛系统
tests/       合同、卡效、策略、场景、UI 和回归测试
tools/       策略包、验证、证据与开发辅助工具
```

关键边界：

1. `scripts/engine/` 负责规则推进、选择窗口、状态转换和效果调度。
2. `scripts/ai/ptcgdap/` 负责公开观察、策略包、Host、本地执行、conformance 和 trace。
3. `scripts/effects/` 负责卡牌、攻击、特性、训练家、工具和竞技场效果。
4. `scenes/battle_setup/` 与策略中心负责玩家选择经典 AI 或作者策略，但两类 runtime owner 保持分离。
5. `scripts/tournament/` 负责本地瑞士轮赛事组织。

## 本地运行

### 环境

- Godot `4.6.x`
- Windows 是当前重点验证平台
- Android 设备验收仍在继续推进
- 策略对战不需要系统 Python 或远程推理
- AI 对话等可选 LLM 功能需要单独配置兼容服务

### 启动

1. 用 Godot 打开仓库根目录下的 `project.godot`。
2. 运行主场景 `res://scenes/main_menu/MainMenu.tscn`。
3. 进入“AI 对战”选择内置或已加载策略，或进入卡组管理、比赛模式开始练习。

### 常用测试

```powershell
# 在仓库根目录执行；请替换为本机 Godot 路径
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FunctionalTestRunner.gd
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/AITrainingTestRunner.gd
```

## 当前状态与边界

这是一个高速迭代中的开源 PTCG AI Agent 策略平台，不是官方完整裁判程序，也不代表 Pokemon、PTCG 或任何相关权利方的授权与背书。

- 当前版本已经具备作者策略包、Forge 开发工作流、公开策略合同、Godot 本地执行、统一 AI 对手选择器、策略排名与持续验证基础设施。
- Windows 是当前主要产品与开发平台；Android 的完整设备验收仍是开放工作。
- 接口一致、Python/GDScript conformance、Godot 规则结果、官方 CABT 引擎一致和产品发布资格是不同的验收等级，项目只对有明确证据的范围作声明。
- 第三方策略必须经过包完整性、兼容性、签名、资格和设备门；“本地开发通过”不自动等于“已进入天梯”或“所有玩家均可执行”。

详细状态见 [PtcgDAP 状态记录](docs/ptcgdap/STATUS.md) 与 [实现检查表](docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md)。

## 参与贡献

最直接的参与方式是：开发一套策略，让它进入天梯，并用真实失败对局继续迭代。

也欢迎提交 Issue 和 Pull Request，尤其欢迎：

- 新的规则策略、模型策略、公开场景和 `.ptcgai` 包
- 卡牌效果、规则 bug 和身份映射修复
- AI 对战中的错误决策与可复现录像
- 策略评估、benchmark、回放和可视化工具
- 策略中心、对战 UI、无障碍和多平台体验改进
- Windows / Android 打包与设备兼容性反馈

提交前建议阅读：

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)
- [docs/README.md](docs/README.md)
- [PtcgDAP 公共架构记录](docs/ptcgdap/README.md)

## 免责声明

本项目是非官方、非商业的学习与研究项目。Pokemon、宝可梦、PTCG 及相关卡牌名称、图片、规则文本和知识产权归各自权利人所有。本项目不提供任何官方授权背书，也不用于替代官方产品或商业化发行。

如果你 fork、发布策略或进行二次开发，也请保留这一边界。

## License

[Apache License 2.0](LICENSE)
