# Pulse Dock App Store Readiness Checklist

> Updated 2026-06-25. This is an internal engineering checklist for App Store readiness and should not be surfaced verbatim in the product UI.

## Fixed In This Pass

- [x] 统一产品名为 Pulse Dock
- [x] 补标准 AppKit 主菜单、About 和设置快捷键
- [x] 声明中文本地化与 Utilities 分类
- [x] Widget 只刷新自己的 timeline kind
- [x] 暂停时停止刷新定时器
- [x] 修正电源状态颜色与进程启动日期显示
- [x] 修正 lsregister 本地注册命令参数
- [x] 将 Widget timeline kind 统一为 PulseDockWidget 共享常量
- [x] 暂停恢复时重置网络速率基线并忽略陈旧 refresh 结果
- [x] About 面板补版权信息并在退出时清理菜单栏状态项
- [x] About 版权改由 Info.plist 的 NSHumanReadableCopyright 提供
- [x] 统一 LICENSE 与 About 面板版权归属
- [x] 为主窗口启用 frame autosave 记住用户窗口位置
- [x] 将内存分段条从固定宽度改为自适应可用宽度
- [x] 为核心自绘仪表、趋势图和状态点补基础 accessibility 语义
- [x] 将小组件刷新设置改为只读视觉样式
- [x] 移除未使用的菜单栏 popover helper
- [x] 补 Widget extension attributes 元数据
- [x] 将内部 Xcode project/target/scheme/archive 统一为 PulseDock
- [x] 在应用菜单和设置页补隐私政策与支持入口
- [x] 为 Mac App Store 截图资产补校验脚本和固定目录
- [x] App Store screenshots prepared and validated
- [x] Core custom UI accessibility labels completed
- [x] Widget reads shared latest app snapshot through App Group with self-sampling fallback
- [x] App Group provisioning prerequisite documented for production signing
- [x] Threshold copy says "阈值判断" / "状态判断" for v1 and does not imply system notifications.
- [x] Local notifications are deferred to a future opt-in feature.
- [x] v1 localization decision: zh-Hans only unless full localization audit passes.
- [x] Window minimum size lowered and compact layouts verified
- [x] Disk fallback no longer uses NSHomeDirectory string path
- [x] Running app naming replaces top-process wording at user-facing boundaries
- [x] Source folders were renamed to `Sources/PulseDockApp` and `Sources/PulseDockWidget`.

## Still Open

- [ ] Future: design opt-in local threshold notifications in a separate v1.1 feature plan.
- [ ] If shipping v1 globally, complete a separate full localization sprint before App Store submission.
- [ ] If shipping v1 without full localization, limit App Store Connect availability to Chinese-language storefronts.
- [ ] External: publish GitHub Pages privacy/support URLs and verify both return HTTP 200 before App Store submission.
- [ ] External: verify App Group sharing with production provisioning, TestFlight, or an App Store-signed archive.

## Notes

- Widget 优先读取 App Group 中的最近一次主 app 采样快照，若共享数据不可用或过期则回退到 Widget 扩展内公开 API 自采样。
- `scripts/archive-app-store.sh` 是上架归档入口；它使用 `PulseDock.xcodeproj` / `PulseDock` scheme。SwiftPM 只验证主可执行和共享逻辑，不会构建 Widget Extension。
- 根目录 README 和 MIT LICENSE 已补齐，方便开源仓库首页和许可证识别。
- Source layout now uses `Sources/PulseDockApp` and `Sources/PulseDockWidget`; old `Sources/SystemDashboard*` source-folder names should not return in release-critical build metadata.
