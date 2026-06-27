# Resources/Scripts/工程配置 深度审查报告

## 审查概要
- 审查文件数：14
- 发现问题数：17（Bug 级 3 / 质量级 8 / 整洁级 6）
- 审查范围：Resources（plist/entitlements/xcprivacy）、Scripts（5 个脚本）、Xcode 工程（pbxproj）、Package.swift、.gitignore
- 总体结论：App Store 合规基本面扎实（sandbox + Hardened Runtime + 隐私 manifest 均已就位且 reason code 正确），未发现会直接阻断首次提交的硬性违规。主要风险集中在 **缺少显式共享 Scheme**（自动化归档路径）、**pbxproj 中 productReference 名称与 PRODUCT_NAME 不一致**、以及若干一致性/整洁性问题。

---

## 逐文件审查

### 1. `Package.swift`（39 行）
- L1 `swift-tools-version: 6.0`：与工程 `SWIFT_VERSION = 6.0`（target 级）一致 ✓
- L7-9 `.macOS(.v14)`：与 `LSMinimumSystemVersion=14.0`、`MACOSX_DEPLOYMENT_TARGET=14.0` 一致 ✓
- L10-13 products：`SharedMetrics`（library）+ `SystemDashboardApp`（executable）。注意该 manifest 仅用于本地 SwiftPM 构建/测试，**不含 widget target**（SwiftPM 对 app-extension 支持有限，属合理设计）。
- L17-23 SharedMetrics 链接 CoreGraphics/IOKit/Metal/Network/SystemConfiguration；L28-32 App target 额外链接 AppKit/SwiftUI/WidgetKit。与 pbxproj 链接的框架集合基本对应（pbxproj 多了自动加入的 Cocoa）✓
- L34-37 `SharedMetricsTests` 测试 target 存在；注意 Xcode 工程中**无对应 test target**，测试仅走 SwiftPM（可接受）。
- 未发现 Bug。

### 2. `Resources/AppInfo.plist`（37 行）
- L6-7 `CFBundleDevelopmentRegion = zh-Hans` ✓
- L8-11 `CFBundleLocalizations = [zh-Hans]`：仅简中一种本地化，App Store 可接受但覆盖面窄。
- L12-13 `CFBundleExecutable = $(EXECUTABLE_NAME)` ✓
- L14-15 `CFBundleIconFile = AppIcon`：与资源 `AppIcon.icns`（pbxproj 已引用）匹配 ✓
- L16-17 `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)` ✓
- L18-19 `CFBundleInfoDictionaryVersion = 6.0` ✓
- L20-21 `CFBundleName = Pulse Dock`：与 pbxproj `PRODUCT_NAME = "Pulse Dock"` 一致 ✓
- L22-23 `CFBundlePackageType = APPL` ✓
- L24-25 `CFBundleShortVersionString = $(MARKETING_VERSION)` ✓
- L26-27 `CFBundleVersion = $(CURRENT_PROJECT_VERSION)` ✓
- L28-29 `LSMinimumSystemVersion = 14.0` ✓
- L30-31 `LSApplicationCategoryType = public.app-category.utilities` ✓（系统监控归类合理）
- L32-33 `NSHighResolutionCapable = true` ✓
- L34-35 `NSHumanReadableCopyright = © 2026 乔尼的铃角` ✓
- **缺 `CFBundleDisplayName`**：macOS 可选，但 widget 侧已设置，建议补 `Pulse Dock` 保持一致并利于本地化展示。
- **缺 `ITSAppUsesNonExemptEncryption`**：app 仅用 Network 框架的 NWPathMonitor（无自定义加密/HTTPS 出站），应显式声明 `false`，避免每次提交被弹出口岸合规问卷。
- **缩进不一致**：L6-11、L18-21、L30-35 用 2 空格；L12-17、L22-29 用 Tab。plist 仍可解析，纯整洁问题。
- **缺 `LSUIElement`**：已确认 `AppDelegate.swift:50` 调用 `NSApp.setActivationPolicy(.regular)`（常规 Dock 应用 + 状态栏项），故**不应**设置 `LSUIElement`，当前缺失是正确的 ✓

### 3. `Resources/WidgetInfo.plist`（36 行）
- L6-11 region/localizations 同 App ✓
- L12-13 `CFBundleDisplayName = Pulse Dock Widget` ✓
- L14-15 `CFBundleExecutable = $(EXECUTABLE_NAME)` ✓
- L16-17 `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)` ✓
- L18-19 `CFBundleInfoDictionaryVersion = 6.0` ✓
- L20-21 `CFBundleName = Pulse Dock Widget`：与 widget `PRODUCT_NAME = PulseDockWidgetExtension` 不同，但 CFBundleName 是展示名，硬编码合理 ✓
- L22-23 `CFBundlePackageType = $(PRODUCT_BUNDLE_PACKAGE_TYPE)`：app-extension 解析为 `XPC!`，用变量优于硬编码 ✓
- L24-27 版本号变量 ✓
- L28-34 `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension` ✓；`NSExtensionAttributes = {}` 可接受。
- 缺 `LSMinimumSystemVersion`：扩展由 deployment target 控制，可接受 ✓
- 缩进全程 2 空格一致 ✓
- 未发现 Bug。

### 4. `Resources/SystemDashboard.entitlements`（9 行）
- L6-7 `com.apple.security.app-sandbox = true`：App Store 必备 ✓
- 已核验源码：`NWPathMonitor` 仅监听路径状态、**无出站连接**，故**无需** `network.client/server` entitlement ✓
- 已核验：未用 AppleEvents/相机/麦克风/通讯录等 TCC API，故无需对应 entitlement ✓
- IOKit 实际用法为 `host_statistics64` + `sysctlbyname`（沙盒友好），SystemConfiguration 仅 `SCNetworkInterfaceCopyAll` 等只读查询，均可在 sandbox 下运行，无需额外 entitlement ✓
- Hardened Runtime 在 build settings 开启（与 entitlements 分离，正确）✓
- 权限最小化，合规良好 ✓

### 5. `Resources/SystemDashboardWidget.entitlements`（9 行）
- L6-7 仅 sandbox=true，与 widget 扩展要求一致 ✓
- widget 共享 SharedMetrics（SystemSampler 使用 DiskSpace/SystemBootTime），在沙盒内读取系统统计，无需额外 entitlement ✓

### 6. `Resources/App/PrivacyInfo.xcprivacy`（39 行）
已逐项与源码核对 required-reason API：
- L8-14 `NSPrivacyAccessedAPICategoryDiskSpace` + `85F4.1`：源码 `SystemSampler.swift:767-769` 用 `FileManager.attributesOfFileSystem` + `.systemFreeSize/.systemSize`，`:813-841` 用 `volumeAvailableCapacity`。`85F4.1`（向用户展示可用空间）正确 ✓
- L15-22 `NSPrivacyAccessedAPICategoryUserDefaults` + `CA92.1`：源码 `MetricsStore.swift` 大量使用 `UserDefaults.standard`。`CA92.1`（访问本 app 自身偏好）正确 ✓
- L23-30 `NSPrivacyAccessedAPICategorySystemBootTime` + `35F9.1`：源码 `SystemSampler.swift:248` 用 `ProcessInfo.processInfo.systemUptime`。`35F9.1`（测量启动后流逝时间）正确 ✓
- L32-33 `NSPrivacyCollectedDataTypes = []` ✓
- L34-35 `NSPrivacyTracking = false` ✓
- L36-37 `NSPrivacyTrackingDomains = []` ✓
- 已核验：**未发现遗漏的 RR API**（无 `creationDate/modificationDate` 等文件时间戳 API、无 active keyboard API）✓
- App 侧独有 UserDefaults（MetricsStore 属 App target），Widget 侧正确未声明 UserDefaults ✓
- 隐私 manifest 完整且准确，亮点。

### 7. `Resources/Widget/PrivacyInfo.xcprivacy`（31 行）
- L8-14 DiskSpace `85F4.1` ✓（SystemSampler 被共享进 widget target）
- L15-22 SystemBootTime `35F9.1` ✓
- 正确**未声明 UserDefaults**（widget 不含 MetricsStore）✓
- 其余 tracking/collected 字段同 App ✓
- 与实际用法匹配，亮点。

### 8. `scripts/archive-app-store.sh`（112 行）
- L1-2 shebang + `set -euo pipefail` ✓
- L4 `ROOT_DIR` 经 `cd "$(dirname "${BASH_SOURCE[0]}")/.."` 解析，健壮 ✓
- L6-12 `require_env`：缺 env 退出 2 ✓
- L14-25 `validate_bundle_identifier`：拒绝 `local.*`（L17）、校验反向 DNS 正则（L21）✓ 设计周到
- L27-28 强制 `APP_BUNDLE_IDENTIFIER`、`DEVELOPMENT_TEAM` ✓
- L30-38 默认值：widget id = app.widget、version 1.0.0/1、Release、derived data、archive/export 路径 ✓
- L43-46 校验 widget id 必须以 app id 开头 ✓
- L48-67 动态生成 `AppStoreExportOptions.plist`：`method=app-store-connect`、`signingStyle=automatic`、`teamID`、`manageAppVersionAndBuildNumber=false` ✓
- L70-73 `-allowProvisioningUpdates` 条件拼接 ✓
- L75-82 先 `cd`，跑 `generate-app-icon.swift`（经 `swift` 解释器，无需 +x）→ 跑 `generate-xcodeproj.rb`（直接执行，已有 +x）✓
- L84-103 `xcodebuild archive` 传 scheme/configuration/destination/derivedData/build settings ✓
- L105-110 `xcodebuild -exportArchive` ✓
- **风险**：L96 `-scheme SystemDashboard`，但工程内**无显式 .xcscheme 文件**（仅 `project.xcworkspace/xcshareddata/swiftpm`）。依赖 Xcode 自动生成 scheme。本机 Xcode 16 一般可自动生成，但**无共享 scheme 在纯 headless/CI 环境存在不确定性**，归档路径上建议显式生成共享 scheme。
- **L64 `manageAppVersionAndBuildNumber=false`**：意味着每次上传需手动递增 `CURRENT_PROJECT_VERSION`，脚本无自增逻辑，易出错（流程级提示，非代码 bug）。
- 未做归档产物存在性校验（次要）。

### 9. `scripts/package-app.sh`（82 行）
- L1-2 shebang + `set -euo pipefail` ✓
- L5 `APP_DIR` 含空格 `Pulse Dock.app`，赋值保留 ✓
- L6-13 默认值：`local.pulsedock` / `.widget`、Release、adhoc、version 1.0.0/1、team 空 ✓
- L15-23 校验 `PACKAGE_SIGNING_MODE ∈ {adhoc,xcode}` ✓
- L25-32 生成图标 + 工程 ✓
- L34-48 组装 BUILD_SETTINGS，adhoc 时加 `CODE_SIGNING_ALLOWED=NO` ✓
- L50-57 `xcodebuild build` ✓
- L59-64 校验 `BUILT_APP` 存在，否则退出 1 ✓
- L66-67 清理 + 拷贝 ✓
- L69-77 **adhoc 签名顺序正确**：先签 widget appex（L70-72），再签 app（L74-76），由内向外 ✓
- L79-80 `lsregister -f` 注册 ✓
- L72 引用 `PulseDockWidgetExtension.appex`（与 PRODUCT_NAME 一致）；若 Xcode 实际产出名不同则此处会失败——已确认 PRODUCT_NAME 主导产出名，匹配 ✓
- 整体逻辑严谨。

### 10. `scripts/generate-xcodeproj.rb`（87 行）
- L1-2 shebang ruby + `frozen_string_literal` ✓
- L4-5 require xcodeproj/fileutils ✓
- L7-9 解析 root、删除并重建 `.xcodeproj`（说明 pbxproj 是**生成产物**，已提交便于直接用 Xcode 打开）✓
- L13-16 建立 4 个 group ✓
- L18-20 `Dir.glob(...).sort` 收集源文件，确定性排序 ✓
- L22-28 注册 plist/entitlements/privacy/icon 资源引用 ✓
- L30-35 ENV 默认值：app `com.ifonly3.pulsedock`、widget `.widget`、version 1.0.0/1、team 空——与 pbxproj 一致 ✓
- L37-38 创建 app `:application` 与 widget `:app_extension` target（target 名分别为 "SystemDashboard"、"SystemDashboardWidgetExtension"）✓
- L40-43 源文件分配、资源添加 ✓
- L45-59 系统框架添加（Cocoa 由 xcodeproj gem 自动追加，解释了 pbxproj 中出现的 Cocoa）✓
- L61-63 `Embed App Extensions` copy phase（`:plug_ins`）✓
- L65 `app_target.add_dependency(widget_target)` ✓
- L67-84 遍历所有 config 设 build settings：CODE_SIGN_STYLE=Automatic、DEVELOPMENT_TEAM、deployment 14.0、版本、SWIFT_VERSION=6.0、ENABLE_HARDENED_RUNTIME=YES、GENERATE_INFOPLIST_FILE=NO、INFOPLIST_FILE、entitlements、bundle id、PRODUCT_NAME ✓
- L82 `reject! ASSETCATALOG_COMPILER_`：无 asset catalog，防御性清理 ✓
- **L37-38 vs L81 一致性问题**：widget target 名 "SystemDashboardWidgetExtension"，但 `PRODUCT_NAME = PulseDockWidgetExtension`；app target 名 "SystemDashboard"，`PRODUCT_NAME = "Pulse Dock"`。导致 pbxproj 中 `productReference.path` 为 target 名派生的 `SystemDashboard.app` / `SystemDashboardWidgetExtension.appex`，而实际产出用 PRODUCT_NAME。见问题汇总。
- **L67-84 仅设 target 级 SWIFT_VERSION=6.0**，未覆盖 project 级；xcodeproj gem 默认 project 级为 5.0，故 pbxproj 出现 project=5.0 / target=6.0 的不一致（target 覆盖 project，功能无误）。
- **未生成共享 .xcscheme**：xcodeproj gem 不自动产出 scheme 文件，导致 `xcodebuild -scheme` 依赖 Xcode 运行时自动生成。

### 11. `scripts/install-system-widget.sh`（66 行）
- L1-2 shebang + `set -euo pipefail` ✓
- L4-9 路径定义（含空格正确处理）✓
- L10-11 默认 `local.pulsedock` / `.widget` ✓
- L13-20 `validate_bundle_identifier`：本脚本**不拒绝** `local.*`（本地安装场景合理）✓
- L22-33 `wait_for_widget_registration`：5 次重试，每次 `pluginkit -a` 后 grep 校验 ✓
- L35-37 源 app 不存在则自动调 `package-app.sh` ✓
- L39-40 校验 bundle id ✓
- L42-51 若进程在跑，osascript 退出并 sleep 1 ✓
- L53-54 删旧 + 拷贝 ✓
- L56-58 `pluginkit -r` 旧源 appex，`|| true` 容错 ✓
- L60-61 `lsregister -f` ✓
- L63-64 等待注册 + `pluginkit -e use` 启用 ✓
- **L25 `pluginkit -a "$WIDGET_EXTENSION" >/dev/null`**：在 `set -e` 下且不在条件分支中，若 pluginkit 返回非 0（如已注册/路径问题）会直接终止脚本，与重试语义相悖。建议加 `|| true`。
- 仅本地开发链路，不影响 App Store 归档。

### 12. `scripts/generate-app-icon.swift`（342 行）
- L1 shebang `swift`；通过 `swift scripts/...` 调用，**无需 +x**（文件确为 644，符合）✓
- L6-290 `PulseGlyphIconRenderer`：1024 设计坐标系 + `scale(value * pixelSize/1024)` 缩放，多尺寸渲染 ✓
- L29-34 `saveGraphicsState`/设 current/`defer restore` 配对平衡 ✓
- L313-317 路径解析：脚本位于 `scripts/`，两次 `deletingLastPathComponent` 得到 root ✓
- L320 创建 iconset 目录 ✓
- L322-333 10 个 rendition（16~1024，含 @2x）覆盖 macOS icns 全规格 ✓
- L335-338 逐尺寸渲染写 PNG ✓
- L340-341 删旧 icns → `iconutil -c icns` ✓
- L301-311 `runIconutil` 校验 `terminationStatus==0` ✓
- L25,28 force-unwrap：构建脚本可接受。
- **L22 `colorSpaceName: .deviceRGB`**：App Store 图标推荐 sRGB；deviceRGB 为设备相关色彩空间，跨机器色彩不一致。建议 `.sRGB`/`.extendedSRGB`。
- 设计风格（显示器+脉冲波形）与 "Pulse Dock" 品牌一致 ✓

### 13. `SystemDashboard.xcodeproj/project.pbxproj`（599 行）
- L6 `objectVersion = 46`、L296 `preferredProjectObjectVersion = 77`、L283-284 `LastSwiftUpdateCheck/UpgradeCheck = 1600`：Xcode 16 / 新工程格式 ✓
- L240-277 两 NativeTarget：`SystemDashboard`(app) 与 `SystemDashboardWidgetExtension`(widget, `com.apple.product-type.app-extension`) ✓
- L261-266 app build phases：Sources/Frameworks/Resources/Embed App Extensions ✓
- L244-248 widget build phases：Sources/Frameworks/Resources（无 Embed，正确）✓
- L269-271 app 依赖 widget ✓
- L60-72 Copy Files `dstSubfolderSpec = 13`(PlugIns)，嵌入 widget appex ✓
- L328-358 Sources：app 11 文件（5 shared + 6 app）、widget 6 文件（5 shared + 1 widget）——与 `Sources/` 目录一致 ✓
- L308-324 Resources：app 含 PrivacyInfo + AppIcon.icns；widget 含 PrivacyInfo ✓
- L107-139 Frameworks：app 链 Cocoa/SwiftUI/AppKit/WidgetKit/CoreGraphics/IOKit/Metal/Network/SystemConfiguration；widget 链同集合但**无 AppKit**（widget 用 SwiftUI）✓
- L370-566 Build settings：
  - app Release/Debug（L505-525/L526-546）：entitlements=SystemDashboard.entitlements、INFOPLIST=AppInfo.plist、PRODUCT_BUNDLE_IDENTIFIER=`com.ifonly3.pulsedock`、PRODUCT_NAME=`Pulse Dock`、deployment 14.0、version 1.0.0/1、HARDENED_RUNTIME=YES、SWIFT_VERSION=6.0、SDKROOT=macosx、LD_RUNPATH_SEARCH_PATHS=`@executable_path/../Frameworks` ✓
  - widget Release/Debug（L425-443/L547-565）：entitlements=Widget、INFOPLIST=WidgetInfo、bundle id `.widget`、PRODUCT_NAME=`PulseDockWidgetExtension`、无 LD_RUNPATH（无嵌入 framework，正确）✓
  - project 级 Debug/Release（L371-424/L444-504）：CLANG/GCC 警告全套 ✓，但 **SWIFT_VERSION = 5.0**（L421/L501）与 target 级 6.0 不一致（target 覆盖，功能无误）
- L288 `developmentRegion = en`、L290-293 `knownRegions = (en, Base)`：与 Info.plist 的 `zh-Hans` 不一致；因无 `.lproj` 文件，功能无影响，但语义不一致
- L87-104 框架路径硬编码 `MacOSX15.0.sdk`：构建时由 Xcode 解析 SDK，且工程由脚本再生成，可接受
- L80/L84 **productReference.path = `SystemDashboard.app` / `SystemDashboardWidgetExtension.appex`**，与 PRODUCT_NAME(`Pulse Dock`/`PulseDockWidgetExtension`) 不一致：Xcode 新构建系统以 PRODUCT_NAME 决定产出名，故实际产物为 `Pulse Dock.app`/`PulseDockWidgetExtension.appex`（与脚本引用一致），productReference 仅为 target 创建时的派生标签，属陈旧不一致
- 无 `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES`：macOS 14+ 系统自带 Swift 运行，无需 ✓
- 无 test target：测试走 SwiftPM ✓
- 未发现会导致构建失败的硬 Bug。

### 14. `.gitignore`（22 行）
- L1 `.DS_Store` ✓
- L4-5 `.build/`、`.swiftpm/`（SwiftPM）✓
- L8-11 `DerivedData/`、`*.xcuserstate`、`*.xcscmblueprint`、`xcuserdata/`（Xcode 用户态）✓
- L14-16 `dist/`、`*.dSYM/`、`*.xcarchive/`（产物）✓
- L19-21 `*.log`、`*.tmp`、`*.swp`（临时）✓
- `.build/AppStoreExportOptions.plist`（archive 脚本生成）被 `.build/` 覆盖 ✓
- `SystemDashboard.xcodeproj/` 与 `Resources/AppIcon.icns` 为生成产物但**有意提交**（便于直接打开/构建），属设计选择，未忽略合理 ✓
- 完整且无冗余 ✓

---

## 问题汇总

### Bug 级（必须修）
| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| B1 | scripts/generate-xcodeproj.rb:86（及 archive-app-store.sh:96 / package-app.sh:52） | 工程未生成显式共享 `.xcscheme`，`xcodebuild -scheme SystemDashboard` 依赖 Xcode 运行时自动生成；纯 headless/CI 归档存在「scheme not found」风险，恰在 App Store 归档链路上 | 高 | 在 ruby 脚本中显式写出 `SystemDashboard.xcodeproj/xcshareddata/xcschemes/SystemDashboard.xcscheme`（Build/Archive 动作含 widget 依赖），消除自动生成依赖 |
| B2 | SystemDashboard.xcodeproj/project.pbxproj:80,84（generate-xcodeproj.rb:37-38 vs 81） | productReference.path（`SystemDashboard.app`/`SystemDashboardWidgetExtension.appex`）与 PRODUCT_NAME（`Pulse Dock`/`PulseDockWidgetExtension`）不一致；新构建系统以 PRODUCT_NAME 产出，但 productReference 标签陈旧，易误导工具/签名脚本，且与 package-app.sh:72 引用的 appex 名绑定为隐式契约 | 高 | 将 widget target 命名为 `PulseDockWidgetExtension`、app target 命名为 `Pulse Dock`（或生成后同步 productReference.path = PRODUCT_NAME），使三处名称强一致 |
| B3 | Resources/App/PrivacyInfo.xcprivacy（及 AppInfo.plist） | 隐私 manifest 已正确，但 AppInfo.plist 缺 `ITSAppUsesNonExemptEncryption`：App Store Connect 每次提交会弹出出口合规问卷；本项目无自定义加密应声明 `false` | 中-高 | AppInfo.plist 增加 `ITSAppUsesNonExemptEncryption = false` |

### 质量级（建议修）
| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| Q1 | scripts/install-system-widget.sh:25 | `pluginkit -a "$WIDGET_EXTENSION"` 在 `set -e` 下且非条件分支，返回非 0 会直接终止重试循环，与「最多 5 次重试」语义冲突 | 中 | 改为 `pluginkit -a "$WIDGET_EXTENSION" >/dev/null 2>&1 || true` |
| Q2 | SystemDashboard.xcodeproj/project.pbxproj:421,501 | project 级 `SWIFT_VERSION = 5.0` 与 target 级 6.0 不一致（target 覆盖，功能无误但具误导性，且与 Package.swift `swift-tools-version:6.0` 不符） | 中 | generate-xcodeproj.rb 对 project 级 config 也设 `SWIFT_VERSION = 6.0` |
| Q3 | SystemDashboard.xcodeproj/project.pbxproj:288,290-293 | `developmentRegion = en`、`knownRegions = (en, Base)` 与 Info.plist `CFBundleDevelopmentRegion = zh-Hans` 不一致；无 .lproj 时无功能影响 | 中 | generate-xcodeproj.rb 设 `developmentRegion = zh-Hans`，`knownRegions` 含 `zh-Hans` |
| Q4 | Resources/AppInfo.plist:12-35 | Tab 与 2 空格缩进混用 | 低 | 统一为 2 空格（与 WidgetInfo.plist 风格一致） |
| Q5 | Resources/AppInfo.plist | 缺 `CFBundleDisplayName`（widget 侧已设） | 低 | 增加 `CFBundleDisplayName = Pulse Dock` |
| Q6 | scripts/generate-app-icon.swift:22 | `colorSpaceName: .deviceRGB` 为设备相关色彩空间，App Store 图标推荐 sRGB | 低 | 改为 `.sRGB` 或 `.extendedSRGB` |
| Q7 | scripts/archive-app-store.sh:64 | `manageAppVersionAndBuildNumber=false` 且脚本无构建号自增，重复上传同版本会失败 | 低 | 文档化每次上传需递增 `CURRENT_PROJECT_VERSION`，或改为 `true` 由 ASC 托管 |
| Q8 | scripts/generate-xcodeproj.rb:14-25 `validate_bundle_identifier`（archive 脚本:21） | bundle id 正则不允许下划线；Apple 实际允许下划线，若将来 id 含 `_` 会被误拒 | 低 | 正则段允许 `_`：`[A-Za-z0-9_]` |

### 整洁级（可后续）
| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| T1 | SystemDashboard.xcodeproj/project.pbxproj:87-104 | 框架路径硬编码 `MacOSX15.0.sdk`；换 Xcode 版本需再生成 | 低 | 工程为生成产物，可接受；保持「改工程先跑 ruby 脚本」约定 |
| T2 | pbxproj widget frameworks(112-119) | widget 经 Cocoa 自动链接引入 AppKit，widget 用 SwiftUI 无需 AppKit | 低 | 可忽略（gem 默认行为）；如需精简可在 ruby 中移除 widget 的 Cocoa |
| T3 | Package.swift | 未含 widget target（SwiftPM 限制） | 低 | 维持现状，注释说明 widget 仅在 Xcode 工程构建 |
| T4 | scripts/package-app.sh:79-80 | `lsregister` 路径硬编码系统框架内部路径 | 低 | 可接受（系统稳定路径）；可用 `lsregister` 软链/PATH 兜底 |
| T5 | Resources/AppInfo.plist:8-11 | 仅 `zh-Hans` 一种本地化 | 低 | 视市场计划补充 `en` 等本地化 |
| T6 | scripts/archive-app-store.sh:94-103 | 归档后未校验 `.xcarchive` 存在 | 低 | 归档后 `[ -d "$ARCHIVE_PATH" ] \|\| exit` 增强健壮性 |

---

## 一致性矩阵

| 项目 | Package.swift | pbxproj | 脚本默认值 | plist |
|------|---------------|---------|------------|-------|
| App Bundle ID | N/A（SwiftPM 产品名） | `com.ifonly3.pulsedock` | archive：必填 env；package/install：`local.pulsedock`；ruby 默认 `com.ifonly3.pulsedock` | `$(PRODUCT_BUNDLE_IDENTIFIER)` |
| Widget Bundle ID | N/A | `com.ifonly3.pulsedock.widget` | `<app>.widget` | `$(PRODUCT_BUNDLE_IDENTIFIER)` |
| 版本号(CFBundleShortVersionString) | N/A | `MARKETING_VERSION=1.0.0` | `1.0.0` | `$(MARKETING_VERSION)` |
| Build(CFBundleVersion) | N/A | `CURRENT_PROJECT_VERSION=1` | `1` | `$(CURRENT_PROJECT_VERSION)` |
| App 产品名 | executable `SystemDashboardApp` | `PRODUCT_NAME="Pulse Dock"`；productReference `SystemDashboard.app`(陈旧) | `Pulse Dock.app` | `CFBundleName=Pulse Dock` |
| Widget 产品名 | N/A | `PRODUCT_NAME=PulseDockWidgetExtension`；productReference `SystemDashboardWidgetExtension.appex`(陈旧) | `PulseDockWidgetExtension.appex` | `CFBundleName/DisplayName=Pulse Dock Widget` |
| 部署目标 | `.macOS(.v14)` | `14.0` | ruby: `14.0` | `LSMinimumSystemVersion=14.0` |
| Swift 版本 | `swift-tools-version:6.0` | target `6.0` / project `5.0` | ruby 设 `6.0` | N/A |
| Sandbox | N/A | entitlements `true`(App+Widget) | N/A | N/A |
| Hardened Runtime | N/A | `ENABLE_HARDENED_RUNTIME=YES`(App+Widget) | ruby 设 `YES` | N/A |
| 隐私 manifest RR API | N/A | 资源已引用两份 xcprivacy | N/A | DiskSpace/UserDefaults(SystemBootTime) 与源码实际使用一致 ✓ |

---

## 亮点
1. **权限最小化到位**：entitlements 仅 `app-sandbox=true`，无任何多余权限；经源码核验 NWPathMonitor 无出站连接、IOKit/SystemConfiguration 用法均沙盒友好，App Store 兼容性优秀。
2. **隐私 manifest 精准**：三类 required-reason API（DiskSpace `85F4.1`、UserDefaults `CA92.1`、SystemBootTime `35F9.1`）均与源码实际调用一一对应，App/Widget 各自声明范围正确（Widget 不声明 UserDefaults），reason code 选用正确，无遗漏。
3. **脚本工程质量高**：`set -euo pipefail`、环境变量校验、bundle id 双重校验（拒绝 `local.*` + 反向 DNS 正则 + widget 必须为 app 前缀）、adhoc 签名由内向外顺序、产物存在性检查、确定性排序的工程生成。
4. **签名/归档链路完整**：Hardened Runtime + sandbox + automatic signing + `app-store-connect` 导出方法 + `-allowProvisioningUpdates`，符合 Apple 分发要求。
5. **图标管线自包含**：generate-app-icon.swift 程序化生成全规格 icns，无需美术资产二进制提交。
6. **三处版本/部署目标一致**：14.0 / 1.0.0 / 1 在 Package、pbxproj、脚本、plist 间完全对齐。

---

## 模块整体评价
Resources/Scripts/工程配置整体处于**可上架的高完成度**。App Store 合规三要素（Sandbox、Hardened Runtime、Privacy Manifest）均已正确落实，且经源码交叉验证无多余权限、无遗漏 RR API、reason code 准确。脚本体系（归档/打包/安装/工程生成/图标）设计严谨、错误处理规范。

最需优先处理的是 **B1（显式共享 Scheme）** 与 **B2（productReference 与 PRODUCT_NAME 名称对齐）**——两者都在自动化归档链路上，虽本机 Xcode 16 多数情况能自动消解，但属于「不应依赖隐式行为」的工程卫生问题，建议在 generate-xcodeproj.rb 中一次性修正。**B3（ITSAppUsesNonExemptEncryption）** 是低成本的提交体验优化。其余为一致性与整洁性改进，不阻断 1.0.0 首发但建议跟进。
