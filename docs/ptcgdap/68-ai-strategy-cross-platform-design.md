# AI 策略中心跨平台设计与实施

日期：2026-09-09。本文是实施设计与验收索引，不是新平台发布批准。

## 目标和已确认决策

原 `.ptcgai` 文件保持字节、身份和签名不变，由游戏端适配已有数据契约；
规则与模型都在设备本地执行。原生运行库属于游戏，不属于作者策略包。

| 平台 | 本次 AI 能力范围 | 验收要求 |
| --- | --- | --- |
| Windows | 现有 x86_64 | 规则和原生模型回归 |
| macOS | 13.3+，Intel、Apple Silicon | 双架构原生模型、UI、完整对战 |
| Android | Android 10/API29+，ARM64 | 原生模型、触控、4KB/16KB环境 |
| iOS/Web | 不扩展运行能力 | 原有游戏入口不退化 |
| Linux专用服务器 | 保持原授权条件 | 不借玩家兼容层扩大权限 |

AI 系统下限不改变游戏本身的系统/ABI导出范围。旧设备可继续使用游戏，
本地策略执行在入口给出明确原因。模型正常路径必须真正调用 ORT；只有规则
回退不能证明模型支持。云端大模型设置、卡牌规则、策略算法和训练不在此项范围。

## 原实现与边界

- 策略中心已有四个工作区和横竖屏基础，但依赖全窗口/偏好、固定行宽及记录数
  高度估算；嵌入AI设置仍采用独立页面的窗口坐标。
- 安装器原来要求普通`.ptcgai`路径并整文件读取。Android原生选择器返回文档URI，
  Godot4.6.1的FileAccess已经支持SAF，无需新增Android插件。
- 多个执行门/宿主限制Windows；正式对战已有`worker_v1`，包括可选模型叶，
  可直接复用等待、思考提示、同窗口校验与故障回退。
- 原生后端原来只交付Windows二进制；macOS脚本逐架构覆盖同名ORT，扩展缺依赖
  声明和Android映射。模型包自身是平台无关的受限ORT数据。

允许修改：策略中心、设置页嵌入分支、包输入边界、玩家执行准入、原生模型
组件、构建与验收工具。对战准备页只替换误导性的Windows专用普通玩家文案。
BattleScene/HUD/交互/动画/效果/录像逻辑及公共窗口协议不修改。
旧ExecutionGate/Factory名称和方法继续作为兼容入口，不全项目重命名。

## 设计与接口

### 页面适配

依父容器的实际可用区域计算布局；竖屏单列，横屏不足双列最小宽度时也改单列。
屏幕安全区和键盘遮挡先转为页面坐标。标题、说明、操作行允许换行；页签可变
两行。单列由外层滚动，内容自然撑高；双列保留面板滚动。每次重排恢复对应尺寸，
不累计放大，保持工作区、选中项及滚动位置。

嵌入Settings仅使用父区域，保存/测试/模型选择逻辑复用原实现。独立Settings和
共享NonBattleLayoutController不受此分支影响。Android目录显示为由游戏管理。

### 文件导入

系统选择器 -> 有限字节捕获 -> 本地字节安装 -> 既有加载器/牌组校验 ->
临时写入/哈希复核/原子安装 -> 固定user策略目录。

- 普通路径保留后缀/链接检查；`content://`是授权选择得到的不透明定位符，
  不改成伪路径、不靠URI后缀判断格式、不记录URI。
- 文件上限16MiB；已知长度先检查，未知长度分块累计并检测超限及读取错误。
- `install_local_bytes(bytes)`保持本地信任身份；现有商城
  `install_from_bytes(bytes, expected_release)`仍要求精确发行身份。
- 工作任务仅捕获字节；安装/目录/卡牌校验仍在原所属线程。取消或离开页面后
  的迟到结果不得安装；应用后续只读取固定目录副本。

### 能力与原包兼容

`AuthorStrategyPlatformCapabilities.inspect()`读取当前系统/ABI/最低版本与实际
原生组件信息；`evaluate_device`为可独立测试的纯判定函数。Android用SDK_INT，
不解析定制ROM的名称。`AuthorStrategyPortability.evaluate()`仅处理已经验证并
经原信任门允许的包：v1/v2、既有本地卡牌域、既有规则执行器及受限模型契约。

兼容结果包含兼容档、原声明平台和当前有效平台，放在客户端临时视图中。
不重写包内Windows声明，不增加签名成员，不把平台兼容结果写入严格句柄或
策略观察。未知契约拒绝。普通本地包、精确开发样例、Control分发及设备验收
保留各自的信任边界。旧Windows批准不变成其他平台的批准。

执行门先完成原身份准入，再检查平台和包兼容。开局仍重新读取包、验证并创建
句柄；模型额外预检。玩家宿主只扩展允许的设备平台，外部研究入口和Linux
专用服务器条件保留。公开输出仍只有当前窗口的`list[int]`，Base负责合法性、
终局保护、veto和确定性回退；旧窗口结果无权执行。

### 原生模型和交付

固定Godot4.6.1、godot-cpp `58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74`、
ORT来源 `8c546c37b43caaca1fa25db430dab94b901cf277`。记录每个平台真实构建参数
和二进制哈希，不能仅以版本名称推定一致。模型张量契约、整数输出、CPU EP、
线程设置、算子约束及8MiB模型上限不变。

- macOS分架构构建并合成universal扩展/ORT，依赖放Contents/Frameworks且无
  开发机绝对路径，按依赖到应用的顺序签名。
- Android为ARM64构建C/C++ ORT和扩展，按GDExtension原生依赖随APK交付。
  保留游戏x86配置。全部新增SO及C++依赖验证16KiB ELF和APK页对齐。
  标准Godot模板已提供C++运行库，不重复导出；检查最终模板库满足新增组件所需符号。
- 新平台扩展壳保持游戏原系统范围，延迟初始化ORT API和Env，在最低系统判断
  后只加载随应用交付的库；壳不强链接高系统要求的ORT，避免拖累旧设备启动。
- `get_runtime_info()`提供真实组件可用性、版本和CPU后端；`load_actor/run`
  保持原张量接口。错误应返回稳定结果，不能通过禁用C++异常导致进程abort。
- 开局预检失败拒绝该模型包。局内复用现有工作线程与同窗口回退；25ms为推理
  预算，取消清理时间单独报告，不能宣称已经证明总返回时间的硬上限。

## 执行顺序及验收

1. 记录工作树基线，先增加所属层失败测试；保留所有原有未提交工作。
2. 完成有限导入、能力判定及旧包兼容；同一包不改字节、不扩大信任。
3. 完成策略中心及嵌入设置布局，用真实SubViewport而非仅传入尺寸验证。
4. 构建原生扩展、验证原生信息/真实推理/错误路径，检查导出依赖闭包。
5. 三端分别完成场景与完整对战验证，独立记录源码、构建、设备证据。

| 验收层 | 场景 |
| --- | --- |
| 导入 | 中文/空格路径、无后缀URI、已知/未知长度、超限、取消、迟到回调、重复/冲突、空间不足 |
| 兼容 | OS/ABI/最低版本、缺失后端、不同信任身份、未知契约、原哈希和牌组不变 |
| UI | 390x844等手机竖屏、横屏、窄桌面、720p/900p、高DPI、安全区、键盘、长文本、0/1/100条列表 |
| 模型 | 固定公开样本的整数分数与最终选择一致，模型成功计数>0；强制旁路与故障回退分开 |
| 对战 | 各运行时双方席位完整对战、旧窗口拒绝、局内故障回退，Windows原UI/触控/录像回归 |
| 导出 | 无系统Python/网络依赖，移除模型库后仍能进入普通游戏，Mac双架构、Android4KB/16KB |

有独立系统的构建/实机证据前，状态只能是“实现/构建待验证”。模拟或跨架构
翻译结果不替代目标架构设备证据。已有Unicode警告和既有资源释放诊断应单列，
不能以此掩盖新增脚本错误或虚报全套测试通过。

### 回滚

`ptcgdap/author_strategy/platforms/macos_enabled=false`或
`ptcgdap/author_strategy/platforms/android_enabled=false`关闭对应新对战入口；
Windows有独立同类开关。保留用户包、录像与普通游戏，不热切换当前对战。
需要二进制回退时使用原应用版本/对应组件整套回退，不修改作者档案。
不改旧SOURCE_LOCK、设备批准或私有云记录来表示新的验证结果。

## 参考依据

- [Godot4.6 FileDialog](https://docs.godotengine.org/en/4.6/classes/class_filedialog.html)：Android10+原生文件选择。
- [Godot4.6.1 Android FilePicker](https://github.com/godotengine/godot/blob/4.6.1-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/io/FilePicker.kt)：文档URI返回值。
- [GDExtension导出](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdextension/gdextension_file.html)：平台库与依赖声明。
- [ORT构建](https://onnxruntime.ai/docs/build/inferencing.html)：macOS最低目标及universal构建。
- [Android16KB页](https://developer.android.com/guide/practices/page-sizes)：ELF及安装包验证。

实施结果和可复核日志见 `evidence/ptcgdap/cross_platform_20260909.md`。
