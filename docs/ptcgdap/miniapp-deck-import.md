# 官方小程序卡组导入与卡组中心交互

日期：2026-09-18。范围：卡组导入、用户本地持久化、Godot 导入面板及公开 Web 转发适配器。

## 玩家操作

卡组中心 → 导入卡组 → 官方小程序 → 粘贴 18 位卡组 ID → 导入卡组。
从「链接 / 编号」入口直接粘贴有效小程序代码也会自动切换来源。

三种来源共用一个面板：网站链接 / 数字编号、官方小程序、游戏生成的卡组图片。
每种来源显示对应说明和操作；网站与小程序草稿分别保留。请求中锁定来源和提交，
失败后保留可编辑输入并提供重试；成功后提供「查看卡组」「继续导入」「完成」。
结果和警告不再 1.4 秒后自动消失。长内容和小窗口使用真实滚动容器。
图片沿用原有的预览确认流程，普通卡组截图不被宣传为可识别。

## 接口与身份

接口根据 [tcg.mik.moe 的小程序导出工具](https://tcg.mik.moe/tools/miniapp)
页面实际请求核实，属于第三方提供的读取服务：

```text
POST https://tcg.mik.moe/api/v3/deck/export-miniapp
Content-Type: application/json
{"deckCode":"dFJ1jZgeo_xEbSTvjj"}
```

响应为 `code/data/msg`，`data` 包含 `deckCode/cards/variant`。
支持裸代码和 `https://tcg.mik.moe/tools/miniapp?code=...` 链接；保留大小写、下划线、短横线。
不把官方小程序代码转换为网站 deckId，不以卡名替代具体印刷身份。

`MiniappDeckSource.gd` 负责输入、响应和本地身份。`source_provider=miniapp`，
`source_id=deck_code=原代码`；本地 ID 使用独立的 49 位以内整数区间和 SHA-256 前缀，
可被浏览器 JSON 精确保存。分配时检查本地碰撞；同一来源重复导入复用 ID，保留用户重命名。
逐卡保留系列、卡号、数量，接受 `CSVH1aC`、`CSVE1C_GRA`、`CS6.5C` 等实际格式。

无效响应、空牌表、来源不一致、无效数量/路径和重复条目会失败。
卡牌详情继续经过原 `DeckImporter` → `CardDatabase` → 卡图同步链路；详情响应必须匹配请求的系列与卡号。
小程序卡组缺少任何卡牌详情时不发出完成信号，不保存不完整卡组；卡图同步警告可在成功后查看。

`DeckImportPanel.gd` 独立负责来源、草稿、显示状态和布局；网络及保存仍由既有 owner 负责。
`DeckData` 持久化格式未改，对战、策略、CABT 窗口和私有服务未改。

## Web 接入

浏览器使用同源 `POST /api/deck-import/tcg-mik/deck/export-miniapp`，请求体只含 `deckCode`。
`web/deck_import_gateway.mjs` 增加精确操作白名单与 18 位字符串校验；不会转发浏览器 Cookie、
Origin 或任意 URL。现有 card-detail 路由补齐合法的带小数点系列编号。

线上 Web 发布需要同时更新该转发适配器和客户端。静态导出不能自行安装服务端路由；
缺少路由时界面会给出明确提示。本次仅修改公开适配器并做本地导出验收，未部署线上站点、
未修改相邻私有服务。原生 Windows/Android 直接请求公开接口。

## 验证与复现

固定公开响应：`tests/fixtures/deck_import/miniapp_raging_bolt.json`。
真实接口返回「猛雷鼓 厄诡椪」，60 张、31 种卡牌：猛雷鼓ex 3、普通猛雷鼓 1、
碧草面具厄诡椪ex 3、猫头夜鹰 3。Windows 原生完整流程在隔离的用户目录中读取服务、
完成卡牌/卡图链路、经过原有重名对话框、保存并重新读取，60/31 精确保持，零导入警告。
仓库已有同名网站卡组，验收通过正常重名对话框命名为「小程序 · 猛雷鼓 厄诡椪」。

新增 provider/网关测试先失败，再实现通过。Godot 定向回归：

| 套件 | 通过 |
| --- | ---: |
| DeckImporter | 15 |
| MiniappDeckImport | 8 |
| DeckImportPanel | 5 |
| DeckManager | 112 |
| DeckData | 8 |
| LimitlessImporter | 15 |
| DeckShareImporter | 5 |
| DeckDeleteFeedbackRegressions | 6 |

共 174 项；Node 网关 7 项通过，既有可选联网项默认跳过。
UI 布局断言覆盖 1280×720、390×844、844×390；原生截图检查桌面、竖屏和完成页。
浏览器矩阵 11 项通过，既有手机横屏网站用例按原有规则跳过；覆盖 Safari 桌面、iPad、
iPhone 竖/横屏与 Chrome 桌面、手机。测试包含一次模拟 503 后重试、60 卡保存、
刷新恢复与原有网站导入/重名兼容。
浏览器使用固定公开响应，不冒充浏览器直连线上网关证据；真实服务由原生完整流程验证。
部分现有 Godot UI 套件退出仍会输出 ObjectDB 泄漏诊断，本结果不声明资源生命周期验收。

```powershell
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_miniapp_deck_import.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_import_panel.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_manager.gd
node --test tests/web_e2e/deck-import-gateway.test.mjs
./scripts/tools/run_web_ui_e2e.ps1 -SkipBrowserInstall -TestFilter 'miniapp import|Safari deck import accepts'
```

真实联网 smoke：先把当前进程的 `APPDATA` 指向隔离测试目录，再启动 Godot：

```text
Godot --headless --path . --script res://scripts/tools/run_miniapp_import_smoke.gd -- --live
```

使用渲染模式加 `--capture` 可生成 `tmp/miniapp-import/miniapp-*.png`。
开发日志保存在 `tmp/miniapp-import/`，不作为发布包依赖。

## 回滚与对齐声明

仅撤回本次新增的 MiniappDeckSource、DeckImportPanel 和 smoke/测试/文档，
并恢复 DeckImporter、DeckManager 场景/脚本和公开 Web 网关的本次差异。
必须保留本轮之前已有的同源 Web 导入、浏览器持久化及其它未提交修改，不能整文件恢复到 HEAD。
已导入的用户卡组保持原 DeckData 格式；关闭新入口不应删除这些用户数据。

本次达到卡组导入及 UI/本地保存集成验证，不涉及或提升 CABT interface、cross-runtime policy、
engine parity、设备 A5、卡效覆盖或正式发布等级。
