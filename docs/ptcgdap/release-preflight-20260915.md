# 0.6.0 发布前检查（2026-09-15）

结论：AI天梯展示和浏览器交互回归通过，但当前不能将 Web 与 macOS 一并判定为发布就绪。

## 通过的检查

- 本地 Godot 回归 **202 项通过，0 失败**：UI 兼容性 137 项，以及导出配置、更新版本、桌面下载/开战、响应布局、平台准入和卡组分享适配 65 项。
- 浏览器原有 **29 项实际执行用例通过**，覆盖 WebKit 桌面、iPhone、iPad，Chromium 桌面/手机，以及 WebKit 横屏对战。包括完整卡组导入、刷新持久化、搜索/编辑、模型设置输入与原生粘贴、设置滚动、弹窗隔离、失焦取消，以及连续 20 轮手牌操作。
- 新增天梯浏览器用例在 5 个适用配置全部通过：真实 HTTP 榜单响应、前三名文本与作者署名、卡片详情打开关闭。与原有用例合计 **34 项通过**；矩阵中不适用的 44 项是显式跳过，不算通过。
- 正式 Web Release 0.6.0 在 Chromium、WebKit 都能启动到主菜单，无捕获到的脚本运行错误，且没有测试桥。PCK 197.92 MiB、WASM 35.94 MiB，均在现有预算内。
- macOS 在磁盘空间恢复后导出 ZIP 完整、CRC 正常，主程序包含 x86_64 与 arm64 两个架构。

## 发布阻断与证据边界

1. **线上 Web 卡组导入接口仍返回 HTTP 405。** 对 `https://ptcg.skillserver.cn/api/deck-import/tcg-mik/deck/detail` 发送只读取牌组数据的 `POST {"deckId":574793}`，未得到牌组 JSON。客户端依赖同域导入接口，只上传静态 Web 产物不能解决线上导入。需要接通公开模块 `web/deck_import_gateway.mjs` 对应的同域路由。浏览器导入用例使用受控 HTTP 响应，不能冒充线上服务已就绪。检查时线上 Web 清单仍为 0.5.6.0 / build 560。
2. **macOS 包缺少模型运行库。** 当前文件树和最终 ZIP 均没有 `libptcgai_ort.macos.template_release.universal.dylib` 与 `libonnxruntime.dylib`；Godot 日志明确报缺少前者，但进程仍返回 0。不能把导出退出码当作依赖完整性证明。需在 Mac 构建并放入 universal 原生库，再执行 `native/ptcgai_ort_actor/verify_macos_bundle.sh` 和实际启动/模型策略对战验收。

本轮在 Windows 主机执行。WebKit 自动化并非实体 iPhone/iPad 或 Mac Safari 的最终验收；macOS 原生启动、签名/公证接受与实机对战没有在本轮验证。没有修改私有服务、发布网页或上传安装包。

## 环境问题与测试修正

初轮 D 盘耗尽导致一次浏览器 ENOSPC 和不完整的 Mac ZIP，不能归为客户端回归。用户自行释放空间后停止清理，后续检查产物已放回 D 盘。最终有效结果来自空间恢复后的重跑。

新天梯用例补齐了异步榜单等待、接口要求的六位小数字符串及递归排序的 canonical JSON，并按重复卡片的实际节点路径定位排名；没有为测试放宽客户端验证。新用例已接入 `run_ui_compatibility.ps1 -IncludeWeb`。

## 证据与回滚

证据根目录为 `.tmp/pre-release-20260915/`：`acceptance.json`、`ladder-verified.log`、`ladder-verified/`、`release-smoke.json`、`web-release-budget.json`，以及 `session-data/` 内的完整浏览器、macOS 导出和额外回归日志。

本轮持久代码改动只有浏览器测试与兼容性测试入口。回滚该测试增量时只移除 `AI ladder shows…` 用例及入口过滤项，保留同文件此前已有的修改。AI天梯 UI 本身未在此次检查中改变。
