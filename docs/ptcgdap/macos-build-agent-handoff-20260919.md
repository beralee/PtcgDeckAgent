# Mac 打包问题：交给 Mac agent 的排查与修复说明

核查日期：2026-09-19。来源：Windows 工作区 `D:\ai\code\PtcgDAP`。
分支 `main`，HEAD `b4608d2e2666de6b71d5ab36685650374e5c681e`，**工作区存在大量未提交修改和未跟踪文件，HEAD 不能代表当前代码**。

同步补充：用户随后已授权将公共项目的待提交源码、测试、运行库及本文提交到 GitHub。上面的 HEAD 和第 4 节清单描述的是排查时的提交前状态；接手时应拉取包含本文的最新提交，再检查实际文件与工作区状态，不必把历史“未跟踪”描述理解为仍需手工逐个传文件。Mac 动态库仍须在 Mac 构建，提交源码本身不等于已完成 Mac 验收。

## 1. 先看结论

之前完整模型版无法导出的明确阻塞，是项目声明了 macOS 原生模型组件，但缺少下面两份文件；本次检查它们仍不存在：

```text
bin/ptcgai_ort/libptcgai_ort.macos.template_release.universal.dylib
bin/ptcgai_ort/libonnxruntime.dylib
```

第一份是 Godot 的本地模型扩展，第二份是 ONNX Runtime。Windows 的 DLL、Android 的 SO 都不能代替它们。

但不能再笼统地说“Mac 版完全不能打包”：**2026-09-16 已按当时用户选择，排除模型组件，成功导出过保留普通游戏和规则策略的 Mac ZIP。当前配置仍沿用这个方案。** 恢复完整模型版，需要在 Mac 上构建两份 universal 动态库，并同步恢复导出配置、平台能力判断和对应测试。仅复制动态库不会自动恢复模型支持。

本轮未收到新的 Mac 报错，也没有 Mac 执行环境；没有重新导出今日代码或完成 Mac 真机测试。因此，上述结论区分为“历史完整模型版阻塞已记录、当前缺库已核实”和“当前规则版配置检查通过、历史导出成功”，不声称今日 Mac 全链路已验证。

## 2. 可直接交给 Mac agent 的任务说明

> 请接手 PtcgDAP 的 macOS 打包问题。先核对本说明对应的未提交工作区是否已同步到 Mac，再用 Godot 4.6.1 和配套模板复现当前 macOS preset 的规则版导出及启动。已有规则版导出成功记录，请不要把历史缺库错误直接当作当前规则版的新故障。如果目标是恢复完整模型版，请按本文构建锁定版本的 ONNX Runtime 和 Godot 扩展，产出 Intel + Apple Silicon universal 库，再成套恢复 Mac 模型能力及测试。交付可复现的构建步骤、安装包、日志、哈希和本机运行证据；明确未测试的架构或系统。保留其他平台行为和未关联改动，不提交、推送、上传或发布。开始修改代码前，遵守仓库 AGENTS.md 的阅读顺序与测试要求。

这是两条不同的处理路径：若只要求修好当前规则版，完成第 5 节即可，不必恢复模型功能；若要求完整模型版，继续第 6～8 节。本文没有替用户取消之前的规则版发布选择。

## 3. 已核实的依据

下列路径均相对于仓库根目录，方便在 Mac 上定位；行号是本次工作区快照位置。

| 位置 | 已确认事实 | 排查意义 |
| --- | --- | --- |
| `docs/ptcgdap/macos-export-missing-runtime-20260915.md` | 历史诊断记录：缺少上述两份 dylib；另有 ad-hoc 签名 entitlement 修正 | 缺库与签名提示是两个问题，改 entitlement 不会生成库 |
| `docs/ptcgdap/macos-rules-only-release-20260916.md` | 规则版成功导出、结构检查和 78 项历史测试记录 | 9 月 16 日的结果更新了 9 月 15 日“仍阻塞”的范围 |
| `export_presets.cfg:73`、`:82` | `macOS` preset 当前排除了扩展描述文件及 `bin/ptcgai_ort/**` | 规则版有意不带模型组件 |
| `scripts/ai/ptcgdap/native/ptcgai_ort_actor.gdextension:11`、`:18` | 仍保留 Mac 扩展及 ORT 依赖声明 | 完整模型版需要真实文件；不应随意删除跨平台声明 |
| `scripts/ai/ptcgdap/host/godot/AuthorStrategyPlatformCapabilities.gd:32` | Mac 跳过 native runtime 探测 | 补库后还要恢复此处探测 |
| 同文件 `:60`、`:68` | 即使 runtime 可用，也把 Mac 的 `model_available` 固定为 false；返回 `model_macos_temporarily_unavailable` | 补库后仍会被策略入口拒绝 |
| `scripts/ai/ptcgdap/host/godot/AuthorStrategyPortability.gd:24` | `rules_with_model` 必须满足模型能力条件 | 不允许把模型包偷偷当规则包运行 |
| `native/ptcgai_ort_actor/build_macos.sh`、`build_onnxruntime_macos.sh` | 两个脚本均要求 Darwin，分别构建 ORT 和扩展的两个架构 | 仓库当前提供的是 Mac 本机构建路线 |
| `native/ptcgai_ort_actor/verify_macos_bundle.sh` | 检查导出 `.app` 中两份库、架构、依赖、最低系统和签名 | 这是完整模型包检查器，不适用于故意不带库的规则版 |
| `scripts/tools/export_ptcgdap_device_release.ps1` | 目前只编排 Windows 和 Android，没有 Mac 导出分支 | 不要把它当作现成的 Mac 一键发布脚本 |

当前签名配置是 built-in ad-hoc，`disable_library_validation=true`，notarization 关闭。ad-hoc 签名不等于正式公证；导出成功与下载后 Gatekeeper 是否放行必须分别检查。[Godot 4.6 macOS 导出说明](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html)

### 历史规则版产物

```text
.tmp/macos-rules-release-20260916/PtcgDeckAgent-macOS-0.6.0-rules.zip
大小：253962941 bytes
SHA-256：a19e91eb9e96669efc777fe1577cf9c10526d310560c909980b5e19b49d102fc
版本：0.6.0 / build 60
架构：x86_64 + arm64
```

本轮重新计算了该 ZIP 的 SHA-256，与记录一致。原始 `export.log` 以签名、制作 ZIP、`[ DONE ] export` 结束；`bundle-inspection.json` 记录 ZIP CRC、资源、双架构和模型组件缺席检查通过，同时明确 `mac_native_execution_tested=false`、`published=false`。它是历史可比对产物，不是今日代码的新构建。

### 本轮实际执行的检查

Windows / Godot `4.6.1.stable.official.14d19694e`，独立测试数据目录，串行运行：

| 测试文件 | 结果 |
| --- | --- |
| `tests/test_export_presets.gd` | 24 / 24 |
| `tests/ptcgdap/godot/test_author_strategy_platform_compatibility.gd` | 7 / 7 |
| `tests/ptcgdap/godot/test_author_strategy_battle_setup.gd` | 13 / 13 |

合计 44 项通过，三个进程均退出 0，日志没有匹配到 ERROR、WARNING 或 FAIL。日志位于 `.tmp/macos-agent-handoff-20260919/`。这些验证了当前规则版配置、能力判断和界面拒绝原因，不构成 Mac 编译、签名或执行证据。

## 4. 开工前先解决工作区同步

**不要只凭相同 HEAD 就认为 Mac 与 Windows 内容相同。** 本次发现以下关键文件尚未跟踪，单纯 `git pull` 或导出已跟踪文件的 diff 都不能带过去：

```text
native/ptcgai_ort_actor/.gitattributes
native/ptcgai_ort_actor/dependencies.lock.json
native/ptcgai_ort_actor/build_onnxruntime_macos.sh
native/ptcgai_ort_actor/verify_macos_bundle.sh
native/ptcgai_ort_actor/src/ort_runtime.cpp
native/ptcgai_ort_actor/src/ort_runtime.hpp
native/ptcgai_ort_actor/src/inference_worker.hpp
native/ptcgai_ort_actor/tests/
scripts/ai/ptcgdap/host/godot/AuthorStrategyPlatformCapabilities.gd
scripts/ai/ptcgdap/host/godot/AuthorStrategyPortability.gd
tests/ptcgdap/godot/test_author_strategy_platform_compatibility.gd
tests/ai/ptcgdap/test_ptcgai_ort_runtime_info.gd
tests/ai/ptcgdap/test_platform_model_inference.gd
tests/ai/ptcgdap/fixtures/
docs/ptcgdap/macos-export-missing-runtime-20260915.md
docs/ptcgdap/macos-rules-only-release-20260916.md
```

这只是重点清单，不能视为完整补丁依赖清单。同时需要已修改的 `export_presets.cfg`、`CMakeLists.txt`、`build_macos.sh`、C++ Actor 源文件、GDExtension 描述文件、相关 GDScript/测试及资源。应接收完整的公共项目工作区快照，或一套已核对依赖的 tracked diff + untracked 文件集合；本轮没有生成或发送源码同步包。

保留 Mac 端已有修改，先比较再合并。Windows 的 `.godot` 缓存和 native `build` 目录不是可移植源码；Mac 端使用自己的导入缓存和构建目录。不要复制私有云仓库、凭据、用户策略数据或机器配置。`.tmp` 日志与历史 ZIP 是本机证据，通常不会随 Git 同步，可按需要单独转交。

还有一个版本差异：9 月 19 日的 C++ Actor 已加入 `128/32` semantic profile，并保留原 `24/16` profile；仅 Windows v4 已有相应验证。见 `docs/ptcgdap/70-local-semantic-neural-actor.md`。Mac 必须按收到的当前源码重建，不能拿旧库配新源码就宣称模型兼容。

## 5. 先在 Mac 建立规则版基线

安装/准备 Godot **4.6.1** 及同版本 export templates。记录 macOS 版本、CPU 架构、Godot 版本、HEAD 和工作区状态。以下是建议在 Mac 执行的命令，本轮未执行；修改示例路径后，在同一个 Bash 会话中使用：

```bash
set -euo pipefail
cd /实际路径/PtcgDAP
PROJECT_ROOT="$PWD"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
mkdir -p "$PROJECT_ROOT/.tmp"
OUT="$(mktemp -d "$PROJECT_ROOT/.tmp/macos-handoff-XXXXXXXX")"

sw_vers
uname -m
"$GODOT" --version
git rev-parse HEAD
git status --short

"$GODOT" --headless --path "$PROJECT_ROOT" --import \
  > "$OUT/import.log" 2>&1
"$GODOT" --headless --path "$PROJECT_ROOT" \
  --export-release "macOS" "$OUT/PtcgDeckAgent-macOS-rules.zip" \
  > "$OUT/export-rules.log" 2>&1
shasum -a 256 "$OUT/PtcgDeckAgent-macOS-rules.zip"
```

若命令失败，保留完整日志与退出码，以首个有效错误为依据。特别注意：preset 的排除过滤器控制导出包，不代表源码编辑器不会尝试加载扩展；若导入阶段提示缺 dylib，要区分编辑器加载报错与实际导出失败。不要通过删除其他平台的扩展配置来掩盖问题。

显式输出到新的 `.tmp` 目录，避免使用 preset 默认的 `../ptcgdojopage/downloads/ptcgdeckagent-mac.zip` 覆盖网站下载文件。Godot 支持按 preset 从命令行导出。[官方命令行导出说明](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html#exporting-from-the-command-line)

成功后解压到新目录，检查 `.app` 的 `Info.plist`、`Contents/MacOS` 可执行文件和签名，并打开应用完成主菜单、策略中心、规则策略对局检查。规则版应没有模型库或指向它们的启动加载记录，并明确拒绝模型策略。

从 Windows 转交历史产物时保留 ZIP；Windows 直接导出的裸 `.app` 可能缺少可执行位，ZIP 路径不受该问题影响。不要把权限问题归因于模型库。[Godot macOS 导出注意事项](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html)

## 6. 完整模型版：先构建真实动态库

仅在目标包含恢复 Mac 模型策略时执行。依赖以 `native/ptcgai_ort_actor/dependencies.lock.json` 为准：

| 项目 | 锁定值 |
| --- | --- |
| Godot | 4.6.1 |
| godot-cpp commit | `58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74` |
| ONNX Runtime source commit | `8c546c37b43caaca1fa25db430dab94b901cf277` |
| ORT C API | 26 |
| 模型系统门槛 | macOS 13.3 |
| 小型扩展构建目标 | Intel 10.12；Apple Silicon 11.0 |
| 构建并发 | 最多 4 jobs，两个架构串行 |

依仓库 README 准备 Xcode 命令行工具、Python 3.10+、CMake 3.28+、Ninja，以及上述固定提交的完整依赖源码。不要无说明替换成 Homebrew 的任意 ORT 版本；扩展构建会验证来源元数据和运行库哈希。构建开始前检查现有高内存任务、可用内存及内存压力，不能与训练/评估池并行。Python 只是开发构建工具，玩家运行游戏不需要它。

以下依赖路径是待替换示例，源码应放在独立目录；使用全新构建输出，避免混用旧缓存：

```bash
export GODOT_CPP_ROOT="/实际依赖路径/godot-cpp"
export ONNXRUNTIME_SOURCE_ROOT="/实际依赖路径/onnxruntime"
export ONNXRUNTIME_BUILD_ROOT="$OUT/ort-build"
export ONNXRUNTIME_OUTPUT_ROOT="$OUT/ort-stage"

git -C "$GODOT_CPP_ROOT" rev-parse HEAD
git -C "$ONNXRUNTIME_SOURCE_ROOT" rev-parse HEAD

bash "$PROJECT_ROOT/native/ptcgai_ort_actor/build_onnxruntime_macos.sh" \
  > "$OUT/build-ort.log" 2>&1

export ONNXRUNTIME_X86_64_ROOT="$ONNXRUNTIME_OUTPUT_ROOT/x86_64"
export ONNXRUNTIME_ARM64_ROOT="$ONNXRUNTIME_OUTPUT_ROOT/arm64"
bash "$PROJECT_ROOT/native/ptcgai_ort_actor/build_macos.sh" \
  > "$OUT/build-extension.log" 2>&1

lipo -info "$PROJECT_ROOT/bin/ptcgai_ort/libonnxruntime.dylib"
lipo -info "$PROJECT_ROOT/bin/ptcgai_ort/libptcgai_ort.macos.template_release.universal.dylib"
shasum -a 256 "$PROJECT_ROOT/bin/ptcgai_ort/"*.dylib
```

第一步生成每个架构的 headers、ORT、LICENSE、`runtime-build.json`。第二步验证 ORT 来源和架构，构建两个扩展 slice，再分别合并扩展和 ORT，修正 install name 并执行 ad-hoc 签名。`build_macos.sh` 的扩展缓存固定在 `native/ptcgai_ort_actor/build/macos-*`；在新 Mac 工作副本运行最容易避免旧缓存干扰。

脚本存在不等于已在 Mac 编译通过；本轮没有对应编译日志。若出现 CMake、SDK、编译或链接错误，应记录实际首错再修正脚本，不能预设“只缺文件，脚本一定没问题”。

运行时设计要求扩展通过自身绝对路径加载**相邻的** ORT，且不得强链接 ORT；见 `src/ort_runtime.cpp`。不要改成加载开发机 `/opt/homebrew`、当前目录或策略包内的库。保留两个架构各自的构建结果，不可互相覆盖。

## 7. 完整模型版：成套恢复软件开关

本轮仅排查并写文档，尚未做下列修改。应先添加/调整能复现目标行为的测试，再做最小修改：

1. **导出配置**：只从 macOS preset 的 `exclude_filter` 删除 `scripts/ai/ptcgdap/native/ptcgai_ort_actor.gdextension` 和 `bin/ptcgai_ort/**` 两项；保留其余资源过滤和 Windows/Android/Web 设置。
2. **平台能力**：在 `AuthorStrategyPlatformCapabilities.gd` 恢复 Mac native runtime 探测和有条件的模型能力；保留架构、macOS 13.3、CPUExecutionProvider、ORT 版本及平台回滚开关检查。不能直接把 `model_available` 写成 true，也不要连带启用 Web 模型。
3. **错误与入口**：模型后端存在且可用时允许模型包通过；缺失或不兼容时给出真实原因。保留 `AuthorStrategyPortability`、包信任和模型 preflight，普通游戏不应因可选模型后端缺失而崩溃。
4. **同步测试和文案**：更新 `tests/test_export_presets.gd` 中规则版排除断言、`test_author_strategy_platform_compatibility.gd` 中“Mac 即使有 runtime 也拒绝”的断言，以及 `test_author_strategy_battle_setup.gd` 中对应原因测试。策略中心展示也要实测。

不要混淆系统门槛：App/小型扩展的构建目标是 Intel 10.12、arm64 11.0；当前 `AuthorStrategyPlatformCapabilities.evaluate_device()` 对作者本地策略（包括 rules_available）本身仍要求 Mac 13.3。保留旧系统游戏启动目标，不代表旧系统已通过作者策略准入。不要为了本次打包擅自改变这一范围。

## 8. 完整模型版验收

### 源码侧：真实加载与推理

构建库并重新导入后运行。第三个命令是测试套件，不能当作 SceneTree 脚本直接运行：

```bash
"$GODOT" --headless --path "$PROJECT_ROOT" --import \
  > "$OUT/import-with-model.log" 2>&1
"$GODOT" --headless --path "$PROJECT_ROOT" \
  -s res://tests/ai/ptcgdap/test_ptcgai_ort_runtime_info.gd \
  > "$OUT/runtime-info.log" 2>&1
"$GODOT" --headless --path "$PROJECT_ROOT" \
  -s res://tests/ai/ptcgdap/test_ptcgai_ort_inference_smoke.gd -- \
  --actor=res://tests/ai/ptcgdap/fixtures/platform_actor.ort \
  > "$OUT/inference-smoke.log" 2>&1
"$GODOT" --headless --path "$PROJECT_ROOT" \
  -s res://tests/FocusedSuiteRunner.gd -- \
  --suite-script=res://tests/ai/ptcgdap/test_platform_model_inference.gd \
  > "$OUT/model-suite.log" 2>&1
```

同样使用 `FocusedSuiteRunner.gd -- --suite-script=...` 重跑第 3 节三组测试，以及策略中心相关测试。涉及用户数据的套件在隔离测试账户/数据环境运行。

需要真实 `available=true`、CPU provider、成功模型加载和推理输出，不能以 fallback 或 `--expect-unavailable` 当成功证据。缺库/旧系统的不可用测试另做。上面的通用 fixture 使用旧 `24/16` 输入；若交付声称支持新 `128/32` profile，还必须增加对应真实模型验证，不能由旧 fixture 推导。

### 实际导出包：依赖与启动

```bash
"$GODOT" --headless --path "$PROJECT_ROOT" \
  --export-release "macOS" "$OUT/PtcgDeckAgent-macOS-model.zip" \
  > "$OUT/export-model.log" 2>&1
mkdir -p "$OUT/unpacked-model"
ditto -x -k "$OUT/PtcgDeckAgent-macOS-model.zip" "$OUT/unpacked-model"
# 用解压后实际的 .app 路径替换下一行，不假定名称。
APP="$OUT/unpacked-model/实际名称.app"
bash "$PROJECT_ROOT/native/ptcgai_ort_actor/verify_macos_bundle.sh" "$APP" \
  > "$OUT/verify-bundle.log" 2>&1
shasum -a 256 "$OUT/PtcgDeckAgent-macOS-model.zip"
```

验收清单：

- `.app/Contents/Frameworks` 中存在两份库，均含 x86_64、arm64；实际位置满足相邻加载要求。
- `verify_macos_bundle.sh` 通过。若实际目录与脚本假设不同，检查导出器行为、描述文件及运行时路径，一并修正；不只改检查器放行。
- 在 Mac 上从实际导出包启动，进入主菜单、策略中心、对战准备并完成普通规则对局。
- 通过真实策略包入口运行模型对局，记录大于零的 native 推理调用；源码测试不能替代导出包证据。Release preset 排除 `tests/**`，需要诊断导出时使用独立配置，不将测试长期塞入正式包。
- 记录 Apple Silicon / Intel 各自的运行结果；只有单架构实机时明确另一架构未验证。Universal 文件存在不证明两种机器都运行成功。
- 分开记录代码签名验证、Gatekeeper 判断、实际启动。当前 ad-hoc/无公证的包不能描述成已公证分发版本；如需正式签名、公证或上传，另按用户授权处理。

## 9. 失败时按层定位

| 实际现象 | 先检查什么 |
| --- | --- |
| `Missing ... dylib`、复制动态库失败 | 缺真实文件、同步不完整、还原模型导出早于构建、路径/文件名不匹配 |
| export templates 找不到或版本不符 | Mac 本机是否安装 4.6.1 对应模板；不要只改版本号绕过 |
| CMake 拒绝 godot-cpp 或 ORT provenance | 锁定 commit、`runtime-build.json`、ORT SHA-256、依赖源码完整性 |
| 编译/链接失败 | 首个编译器错误、Xcode/SDK、固定依赖、架构及旧构建缓存；尚无本轮 Mac 复现结论 |
| 导出成功，但 `.app` 无法打开 | 可执行位、签名、Gatekeeper、最低系统、dyld；保存终端启动输出 |
| 模型仍显示“Mac 版暂不支持” | 能力代码中的 Mac 固定拒绝、是否运行旧导出包 |
| `model_runtime_library_missing` | 实际包内相邻 ORT 是否存在、依赖能否解析；该错误也可能代表 `dlopen` 失败，并非只指文件不存在 |
| `model_runtime_api_incompatible` | ORT C API/符号/版本是否与锁定源码一致 |
| `model_platform_not_supported` 或 `author_strategy_system_version_unsupported` | native OS 检查与 GDScript 平台准入；不要误判成导出失败 |
| `model_tensor_profile_invalid` 等模型输入错误 | 模型与当前 Actor 的 24/16、128/32 profile 是否一致；不应靠关闭 shape 检查解决 |

## 10. 最终交付与回滚

Mac agent 请交付：根因和复现条件、仅涉及本问题的修改清单、可复现构建命令、ZIP 与 SHA-256、依赖来源及两架构 build metadata、导入/构建/导出/签名/推理/对局日志，以及明确的已测/未测矩阵。

若只完成规则版，请直接说明模型支持仍暂停；若完成模型版，请区分编译成功、包结构通过、真实推理通过、完整对局通过和发布验证，不能合并成一个“全平台已支持”。

回滚完整模型恢复时，只还原本任务改动的 Mac 导出排除项、能力判断及关联测试/文案，回到已有规则版方案；保留其他 agent 的修改。禁止对整个 dirty 工作区执行硬重置。不要修改 `D:\ai\code\ptcgabc` 或私有云服务，不引入远程推理或玩家端 Python 依赖。最初排查轮次没有提交、推送或发布；后续 GitHub 源码同步由用户另行授权，见文首补充，仍不代表发布安装包。
