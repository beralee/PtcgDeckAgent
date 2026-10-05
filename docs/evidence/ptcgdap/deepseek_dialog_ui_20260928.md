# DeepSeek 对话 UI 审核与修复（2026-09-28）

## 范围与结果

审核卡组探讨、对局探讨、战斗中探讨的共用对话框，以及设置页连接测试、卡组 AI 分析等待框、战斗建议和复盘的文本展示。沿用工作区已有的 `GameModalDialog` 迁移，不把该迁移或其他并行修改计为本次成果。

本次完成可复现问题的测试驱动修复。19 个相关 suite **207/207** 通过；浏览器 6 个项目 **6/6** 通过；Windows 原生渲染生成 12 张截图。机器可读记录见 [证据 JSON](../../../evidence/ptcgdap/deepseek_dialog_ui_20260928.json)。这属于 UI、输入和请求生命周期验证，不声明策略、CABT 合同或引擎一致性等级提升。

## 问题、归属与修复

| 已确认问题 | 修复归属与行为 |
| --- | --- |
| 桌面、竖屏、战斗的多套布局互相覆盖；按钮挤出屏幕，手机状态提示被隐藏 | `DiscussionDialogLayout` 统一已挂载场景的布局；输入区和操作按钮固定在底部，仅消息区滚动；状态独立显示，长名称截断并保留提示。 |
| 浏览器高分屏横屏按钮实际只有约 16.62 CSS px 高 | 布局从画布的 CSS 宽度计算显示单位，浏览器测试直接核对发送、清空、关闭按钮的实际点击高度约 44 CSS px。 |
| 键盘高度混用屏幕像素和视口单位 | 在布局边界只转换一次，避让后输入和操作区仍可用；关闭键盘恢复布局。 |
| 桌面浏览器中文未同步；WebKit 第二次点击无法输入 | 复用 DOM 文本桥，同时处理首次焦点和保留 Godot 焦点时的重新点击。 |
| 发送或清空之后，延迟失焦把旧文字写回 | 同步更新 Godot 文本与浏览器编辑器；发送成功保持空白，失败保留问题。 |
| 回车重复发送、输入法确认误触风险 | 请求与文字展示阶段都禁止重复提交；桌面 Enter 发送、Shift+Enter 换行，输入法组合事件不提交；触摸端使用发送按钮。 |
| 关闭、清空、切换上下文后旧请求仍占用或回写 | 对话服务使旧回调失效，同时取消实际 HTTP/备用传输；关闭时保留未完成问题，切换其他卡组清除旧草稿。 |
| 同步回调残留“请求中”气泡 | 发起请求前建立完整 UI 状态；失败、同步成功和流式展示都有明确收尾。 |
| 历史追问丢失、清空残留、阅读历史被强制拉到底部 | 从持久历史恢复追问，立即移除旧控件；仅用户处于底部时跟随新消息。 |
| 原文方括号被当作 BBCode，模型输出破坏样式或链接 | 探讨、建议、复盘统一保留字面文本；Markdown 转换一次后按字符展示，正文可选择复制。 |
| 连接测试期间修改密钥却被旧请求标成已验证 | 将测试绑定到开始时的配置签名和请求代次；防止并发点击，设置变化要求重测。 |
| 取消卡组分析仅关闭等待框，迟到结果仍展示 | 等待框所有取消入口使请求代次失效并取消传输；退出编辑器同样取消。 |
| 关闭建议后迟到回答重新弹窗，或覆盖复盘 | 保留结果缓存，只更新仍处于建议模式的可见窗口。 |

## 测试驱动过程

先增加真实 SubViewport、鼠标/触摸输入和可见控件断言，再修复对应层。初始对话 suite 6 项中 5 项失败，设置连接竞态 1 项失败，传输取消 1 项失败；之后补充关闭草稿用例，9 项中 1 项失败。浏览器第一轮发现两个桌面输入问题，第二轮定位 WebKit 二次输入，最终全部修复。额外显示尺寸断言先复现横屏按钮只有 16.62 CSS px，再修正缩放。未降低断言或把失败标为跳过。

新增 `DeepseekDiscussionUI` 9 项、`DeepseekSettingsUI` 1 项、`DeepseekAuxiliaryUI` 3 项及服务传输取消回归。桌面与手机真实控件覆盖缺少配置、超时恢复、同步回调、重复提交、关闭取消、上下文切换、长消息、追问、滚动阅读与键盘避让。最终运行还包含现有连接客户端、对话上下文/持久化、战斗建议/复盘、通用弹窗、非战斗布局和 Web 输入回归。

浏览器测试通过真实点击/触摸、DOM 中文输入和按键驱动界面，拦截合成域名 `deepseek-ui.invalid` 返回成功或 HTTP 503；不调用真实 DeepSeek，不使用玩家密钥。测试探针仅通过已有 `web_ui_e2e` 特性入口启用。输入法检查覆盖组合事件标志，不能替代所有系统输入法的真机验证。

## 平台覆盖与限制

| 环境 | 完成的验证 |
| --- | --- |
| Windows Godot 4.6.1 | 207 项自动检查；真实 OpenGL 渲染 1360×860、390×844、844×390，卡组/对局/战斗/键盘情景共 12 张截图。 |
| Chromium 桌面 / Pixel 7 触摸配置 | 完整中文问答、回车与换行、错误恢复、清空、关闭和三种上下文入口。 |
| WebKit 桌面 / iPad Mini / iPhone 14 / iPhone 14 横屏配置 | 相同浏览器 E2E，包括实际 CSS 点击尺寸和中文输入桥。 |
| 场景尺寸矩阵 | 320×568、390×844、844×390、1080×2400、820×1180、1366×768、1440×900、640×480。 |
| Android/iOS 真机、macOS/Linux 原生发行包 | 本轮未运行这些设备/发行包，不宣称实机验收通过。浏览器设备配置是模拟环境。 |

截图工具：`scripts/tools/capture_deepseek_dialogs.gd`。画面检查修正了头像文字过大、标题/正文比例、横屏点击区缩小等问题。最终原生截图进程退出码 0，错误日志为空。

浏览器导出资源预算通过：PCK 约 216.53 MiB（限 225），WASM 34.08 MiB（限 40）。D 盘触发既有磁盘余量保护后，测试用户数据及报告移至 `%LOCALAPPDATA%/Temp/ptcg_deepseek_ui_review/`，未绕过保护。实际证据目录包含 `final_regression`、`final_discussion`、`web_verified`、`native`；公开证据仅保存合成 UI 截图、测试汇总与源码摘要。

## 复验与回滚

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner all -Suite 'BattleAdviceCoordinator,BattleAdviceFormatter,BattleAdviceService,BattleReviewFormatter,BattleReviewService,BattleSetupLayout,DeckDiscussionContextBuilder,DeckDiscussionDialog,DeckDiscussionService,DeckDiscussionSessionStore,GameModalDialog,NonBattlePortraitLayout,WebUIE2eBridge,ZenMuxClient,DeepseekAuxiliaryUI,DeepseekDiscussionUI,DeepseekSettingsUI,NonBattleWebInputV2,WebInputAdapter' -ReportDirectory <新的报告目录> -UserDataRoot <隔离用户数据目录>
.\scripts\tools\run_web_ui_e2e.ps1 -SkipBrowserInstall -TestFilter 'DeepSeek discussion' -ExportDirectory <导出目录> -ArtifactDirectory <新的浏览器报告目录>
```

浏览器需预先安装项目使用的 Playwright 浏览器。截图工具应使用隔离 APPDATA，并传入 `--output=<目录>`；不发起模型请求。

回滚只撤销本次对话布局、请求代次/取消、文本桥提交及展示转义相关代码段，并移除本次新增辅助类、测试和探针。工作区有大量其他未提交修改，特别是编辑器、设置页、通用弹窗和 Web 测试文件，不能整文件恢复。未提交、推送或发布；未修改 `ptcgabc`、私有云服务、牌组数据或策略运行边界。
