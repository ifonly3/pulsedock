# Pulse Dock App Store Readiness Checklist

> Updated 2026-06-19. This is an internal engineering checklist for App Store readiness and should not be surfaced verbatim in the product UI.

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

## Still Open

- [ ] 评估 App Group 共享最近一次样本
- [ ] 评估是否将内部 Xcode target/scheme 从 SystemDashboard 迁移为 PulseDock

## Notes

- 当前 Widget 仍通过公开 API 自采样，符合沙盒与隐私边界；App Group 不是合规阻塞项，但能提升主 app 和桌面 widget 的数据一致性。
- `scripts/archive-app-store.sh` 是上架归档入口；SwiftPM 只验证主可执行和共享逻辑，不会构建 Widget Extension。
- 根目录 README 和 MIT LICENSE 已补齐，方便开源仓库首页和许可证识别。
