# Pulse Dock App Store Readiness Checklist

> Updated 2026-06-19. This is an internal engineering checklist for App Store readiness and should not be surfaced verbatim in the product UI.

## Fixed In This Pass

- [x] 统一产品名为 Pulse Dock
- [x] 补标准 AppKit 主菜单、About 和设置快捷键
- [x] 声明中文本地化与 Utilities 分类
- [x] Widget 只刷新自己的 timeline kind
- [x] 暂停时停止刷新定时器
- [x] 修正电源状态颜色与进程启动日期显示

## Still Open

- [ ] 评估 App Group 共享最近一次样本

## Notes

- 当前 Widget 仍通过公开 API 自采样，符合沙盒与隐私边界；App Group 不是合规阻塞项，但能提升主 app 和桌面 widget 的数据一致性。
- `scripts/archive-app-store.sh` 是上架归档入口；SwiftPM 只验证主可执行和共享逻辑，不会构建 Widget Extension。
- 根目录 README 和 MIT LICENSE 已补齐，方便开源仓库首页和许可证识别。
