# AI 策略跨平台实施证据

日期：2026-09-09。设计依据：[68 号设计文档](../../docs/ptcgdap/68-ai-strategy-cross-platform-design.md)。

## 交付边界

- 策略中心及其嵌入设置采用父区域布局、换行和触控滚动。
- 原始 `.ptcgai` 字节不变；Android 文档 URI 只用于有限读取，随后安装到游戏管理目录。
- Windows x64、macOS 13.3+ Intel/Apple Silicon、Android 10+ ARM64 使用同一受限数据契约。
- 规则、模型均在设备执行；没有新增 Python、网络推理、动态下载或作者原生代码依赖。
- 新平台开关只限制新开对局，局内仍验证原固定信任信息和当前窗口。
- 未修改 BattleScene、HUD、交互、动画、录像或卡牌效果。对战准备页仅三处文字替换。
- 开始工作时已有 STATUS、Host 的效果选项投影、卡牌效果和 A3 测试等未提交改动；全部保留。
  本次对既有 Host 文件只增加玩家平台开局检查和模型加载失败检查。
- 未修改 `ptcgabc`、私有云、SOURCE_LOCK 或设备批准；没有提交、推送或发布。

## 当前验证等级

| 平台 | 本轮证据 | 尚未完成的门槛 |
| --- | --- | --- |
| Windows x64 | 原生构建、导出后真实 CPU 推理、模型包预检、UI 与导入回归 | 完整发布包的人工对战 UI 验收 |
| Android ARM64 | 固定来源 ORT 与扩展编译；完整项目诊断 APK 签名、依赖闭包及 16KB 对齐通过 | Android 10、现代 4KB/16KB 真机的模型和完整对局；完整发行清单仍缺历史档案 |
| macOS 双架构 | 构建、延迟加载、打包、签名验证脚本已实施并静态复核 | Mac 上实际编译、Intel/Apple Silicon 启动与完整对局 |

本机没有可用 Mac 或已连接 Android 设备。不能把源码测试、交叉编译或规则回退称为三端模型实机验收。

## 自动验证

日志均位于项目内 `.godot_test_user/logs/`；它们是本机运行产物，不要求提交整个测试缓存。

| 测试 | 结果 | 日志 |
| --- | --- | --- |
| 平台、ABI、系统下限、模型缺失、未知契约 | 4/4 | `focused-20260909-095550.log` |
| 有限导入、未知长度、超限、字节不变、信任边界 | 8/8 | `focused-20260909-093443.log` |
| 后台读取、取消、关闭页面、迟到完成、不被网络回调解锁 | 8/8 | `focused-20260909-093446.log` |
| 真实 SubViewport、安全区、手机宽度、百条记录、非鼠标触控 | 4/4，OpenGL 渲染 | `crossplatform-ui-final.log` |
| 原策略中心场景 | 19/19 | `focused-20260909-092704.log` |
| 原非对战布局与设置集合 | 63/65；设置子集 17/17 | `focused-20260909-092828.log` |
| 包目录、安装和黄金元数据 | 22/26 | `focused-20260909-093800.log` |
| 原玩家宿主集合 | 4/23；其余依赖缺失历史包/牌组 | `focused-20260909-092928.log` |
| 真实整数模型、可恢复坏模型、v2 原包与预检 | 3/3 | `focused-20260909-095552.log` |
| 关闭平台仅阻止新对局、现有宿主保持有效、篡改仍拒绝 | 1/1 | `focused-20260909-095542.log` |
| 双方席位规则/模型完整对局 | 1/1，含四场对局 | `focused-20260909-095454.log` |

UI 截图经目视复核：

- `.godot_test_user/ui-captures/strategy-hub-390-catalog.png`
- `.godot_test_user/ui-captures/strategy-hub-390-settings.png`

模型固定样本得到整数分数 29、12、0 和选择数量 1；真正调用 ORT 后，将允许集合内
的规则选择 `[1]` 改成 `[0]`。当 Base 只允许 `[1]` 时仍返回 `[1]`，模型不能越过 veto。
另用四个坏字节证明模型初始化返回错误而非终止进程。v2 包检查同时断言原档案字节不变、
既有句柄版本字段为 2、公开目录元数据没有增加字段。

四场对局使用真实 Factory、玩家宿主、`worker_v1`、HeadlessMatchBridge 和游戏引擎：

| 模式 | 策略席位 | 步数 | 正常策略决策 | 实际模型推理 | 旧窗口拒绝/同窗口回退 |
| --- | --- | --- | --- | --- | --- |
| 规则 | 0 | 66 | 27 | 0 | 4/4 |
| 规则 | 1 | 86 | 33 | 0 | 7/7 |
| 模型 | 0 | 67 | 27 | 20 | 4/4 |
| 模型 | 1 | 55 | 16 | 11 | 4/4 |

四场均正常终局，无非法输出、工作线程启动失败或引擎拒绝。模型旁路仅为强制窗口或
规则空结果，不计入实际推理成功。旧窗口保护代码与 HEAD 相同；本次触发了该保护，
没有重跑原工作树来证明这些回退次数是基线固定值。最初把“策略错误数必须为零”当作
冒烟条件的测试因此失败，最终明确只允许 `stale_policy_response`，且必须与同窗口
回退数吻合；本次旧工作结果数也一致，其他失败仍拒绝。此结果证明执行链可完成对局，不代表
零回退策略认证、胜率验收、卡牌引擎对齐或完整 UI 自动化验收。

测试数据 SHA256：

- `platform_actor.ort`: `707F27662C963916279BC00D3B836EEB9FDC62C7336FAA52AABC787825591FE0`
- `platform_model.ptcgai`: `17B6DFE95383C65A067283BB16FC09FE83128C0D6E73E13B7D969ADC016DF704`

Windows 扩展 SHA256 为 `CEDD6675CE8E5BF683710B2F1A4A6E35E80EEBED8F7711E862032093A6B74720`；
随包 ORT 为 `B2BA7CA16E0E4FE71AD5148744AB885A2F5809E52A0C3DE4D9BA3853A03977F9`。
原生构建记录位于 `native/ptcgai_ort_actor/build/windows-x86_64/runtime-build.json`。

### 原生交付与打包

独立 Windows 导出可执行程序加载新扩展及应用内 ORT 1.26.0/API26，先测试坏模型
的可恢复错误，再成功推理 1024 分数与选择数量 1。日志：
`native/ptcgai_ort_actor/build/runtime-smoke/exported-model.log`。

Android 构建采用 NDK r28c、完整 CPU ORT 源码与四个编译任务。扩展壳以 API24
构建，ORT 以 API29 构建；扩展没有对 ORT 的强链接，只有到达运行系统下限后才加载。

| 文件 | SHA256 |
| --- | --- |
| ARM64 扩展 | `24F8D32E2DDCF383E345C6D9F82D8A30B9EF760AD364595B94F6E1C730D61682` |
| ARM64 ORT | `6FC395FF6469ED92CBFA05516632428C370708D767ED7DB8D28D73E7CC1461DB` |
| 标准 APK 的 ARM64 C++ 运行库 | `AD74BF43EB1FD576518168F664AD16A74E00EEDA9595875C33DD87F6DD197869` |

实际导出发现标准模板已包含 `libc++_shared.so`，重复声明会生成重复 ZIP 条目并导致
签名失败。描述文件改为复用模板中的唯一运行库，APK 验证器额外检查其导出符号满足
ORT 与扩展所需。源构建使用的 C++ 库副本与模板库哈希不同，不能以源目录检查替代
最终 APK 检查。最小 APK 已签名，并对全部 ARM64 ELF、ZIP16KB、依赖闭包与 C++
符号兼容进行验证；记录为 `native/ptcgai_ort_actor/build/runtime-smoke/android-apk-native-inventory.json`，
其中 `accepted=true`、`cpp_symbol_compatibility=true`、`device_tested=false`。
保留原 x86 游戏 ABI；它仍不提供本次 ARM64 AI 组件，不能将其未找到 AI 扩展的
导出警告解读为已经实现 x86 模型支持。

完整项目的 `export_ptcgdap_device_release.ps1 -AndroidOnly` 已实际尝试。原发行清单
检查要求 23 个文件，当前只有 22 个，缺少上述历史
`data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai`，
因此返回 `export_inventory_missing`。检查未被删改。证据：
`.tmp/ptcgdap_device_release/native-crossplatform-20260909/android-inventory.json`。
这阻止宣称完整发行门通过；另行生成的诊断 APK 只用于核查原生打包，不替代发行批准。

完整项目诊断 APK 已实际导出和签名，路径为
`.tmp/ptcgdap_device_release/native-crossplatform-20260909/PtcgDeckAgent-native-validation.apk`，
大小 238,261,368 字节，SHA256 为
`A43D027DB531AC8E398E6D9A78A8597A25EE903432064C63B18637EE65C74F37`。
同目录 `android-project-native-inventory.json` 确认四个 ARM64 库全部通过上述检查，
`accepted=true`、`cpp_symbol_compatibility=true`、`device_tested=false`。
导出日志为 `native/ptcgai_ort_actor/build/android-project-apk.log`。没有连接设备，
不宣称安装、启动、推理或低系统运行通过。

### 已识别的既有回归限制

目录测试剩余四项依赖当前仓库不存在的历史 Marnie 文件：

- `test_local_package_remove_hides_built_in_and_reimport_restores_exact_strategy`
- `test_invalid_removal_store_fails_delete_without_hiding_or_mutating_built_in_package`
- `test_metadata_only_candidate_cannot_request_ready_match_handle`
- `test_ready_catalog_and_match_handle_require_the_same_fixed_release_decision`

前三项要求 `ptcgdap.marnie.windows-local`，最后一项要求
`ptcgdap-author-strategy-release-candidate.ptcgai`。当前跟踪的内置包只有
`marnies-gift-box-turn-program-round05-5.21.0.ptcgai`，身份为
`dev.bodao-yongzhe.marnies-gift-box@5.21.0`，不能替代历史测试文件。
原玩家宿主集合也依赖缺失的旧 Marnie/Cynthia 档案及对应编号牌组；现有 Control
测试档案的真实宿主绑定通过。本轮没有伪造历史包、放宽校验或删除失败测试。

非对战集合的两项失败来自 BattleSetup 原宽度断言：一项仅更改场景尺寸但根视口仍为
桌面，旧布局按横屏将选择器限制为 940；另一项竖屏宽 1080，现有边距计算后为
997.92，小于断言 1000。已核对 HEAD 中原选择器与共享布局逻辑，本轮没有修改这些计算。

项目测试进程存在启动时 `Unexpected NUL character` 和部分退出时资源引用诊断；
这些日志不等于干净的资源生命周期验收。独立原生最小工程没有这些项目启动警告。

## 可重复执行

在项目根目录按顺序运行，避免多个 Godot 测试共享用户目录：

```powershell
powershell -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_platform_compatibility.gd -UserDataRoot .godot_test_user/crossplatform-root
powershell -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_portable_import.gd -UserDataRoot .godot_test_user/crossplatform-root
powershell -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_strategy_hub_import_lifecycle.gd -UserDataRoot .godot_test_user/crossplatform-root
powershell -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ai/ptcgdap/test_platform_model_inference.gd -UserDataRoot .godot_test_user/crossplatform-root
powershell -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_platform_rollback.gd -UserDataRoot .godot_test_user/crossplatform-root
powershell -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ai/ptcgdap/test_platform_player_matches.gd -UserDataRoot .godot_test_user/crossplatform-root
```

合成模型可用 `tests/ai/ptcgdap/generate_platform_actor_fixture.py` 再生成；开发依赖
固定为 ONNX 1.20.1、ORT 1.26.0、cryptography 46.0.3。使用已公开的测试密钥，
不代表发行签名或玩家准入；该测试档案不放进内置目录或生产导出。

原生构建和包内依赖验证命令见 [原生组件说明](../../native/ptcgai_ort_actor/README.md)。
macOS 双架构分目录构建后合并，Android 使用固定 NDK r28c。不能只复用旧来源记录：
脚本会核对实际 ORT 哈希、ELF/Mach-O 依赖、架构、最低系统版本及签名/页对齐。

真实渲染 UI 验收的等价执行方式如下；不加 `--headless`。测试使用实际 SubViewport，
并将 390×844 的目录页和设置页截图保存到上列位置：

```powershell
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = "$PWD/.godot_test_user/crossplatform-ui"
    $uiProcess = Start-Process -FilePath 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' -WindowStyle Hidden -PassThru -ArgumentList @('--path','D:/ai/code/PtcgDAP','--rendering-method','gl_compatibility','--resolution','430x932','--position','10000,10000','--log-file','D:/ai/code/PtcgDAP/.godot_test_user/logs/crossplatform-ui-final.log','-s','res://tests/FocusedSuiteRunner.gd','--','--suite-script=res://tests/ptcgdap/godot/test_strategy_hub_responsive.gd','--capture-ui')
    if (-not $uiProcess.WaitForExit(20000)) { throw 'UI verification still running; inspect the recorded process before continuing.' }
} finally {
    $env:APPDATA = $previousAppData
}
```

## 回滚与后续设备验收

设置 `ptcgdap/author_strategy/platforms/<windows|macos|android>_enabled=false` 后，
新对局获取句柄和构造宿主均拒绝，已开始的宿主不受开关影响。用户档案、录像和普通
游戏保留。Windows 原扩展 DLL 保留，新描述文件使用 `.v2.dll`；二进制回退应与应用
组件一并回退，不修改作者包或发行身份。

下一次目标设备验收需覆盖：安装同一原始包并比对 SHA256、原生实际信息、固定模型
整数分数、双方席位完整对局、局内失效结果拒绝、策略中心触控和导入取消。Android
分别验证 4KB/16KB 环境及最低 API；macOS 分别验证 Intel/Apple Silicon，以及不满足
AI 最低系统时普通游戏仍能启动。没有这些证据前不升级任何发布批准。
