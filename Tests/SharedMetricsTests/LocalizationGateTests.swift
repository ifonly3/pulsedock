import Foundation
import Testing

@Test func localizationAuditScriptHasPortableFallbackWhenRipgrepIsUnavailable() throws {
    let script = try localizationAuditScript()

    #expect(script.contains("command -v rg"))
    #expect(script.contains("Sources/PulseDockApp"))
    #expect(script.contains("Sources/PulseDockWidget"))
    #expect(script.contains("Sources/SharedMetrics"))
    #expect(script.contains("find"))
    #expect(script.contains("-type f -name '*.swift'"))
    #expect(script.contains("perl"))
    #expect(script.contains("'\\p{Script=Han}'"))
    #expect(!script.contains("'[\\p{Han}]'"))
    #expect(!script.contains("'\\p{Han}'"))
}

@Test func localizationAuditScriptDoesNotExitTwoWhenRipgrepIsMissing() throws {
    let script = try localizationAuditScript()

    #expect(!script.contains("ripgrep (rg) is required to run the localization audit."))
    #expect(script.contains("if command -v rg >/dev/null 2>&1; then"))
    #expect(script.contains("else"))
    #expect(!script.contains("exit 2"))
}

@Test func localizationAuditFallbackRunsWithoutRipgrepAndReportsMatches() throws {
    let toolDirectory = try temporaryLocalizationAuditToolDirectory()
    defer { try? FileManager.default.removeItem(at: toolDirectory) }

    let toolCheck = try runRestrictedPathShell(
        "command -v rg >/dev/null 2>&1; echo rg=$?; command -v perl; command -v find; command -v dirname",
        path: toolDirectory.path
    )

    #expect(toolCheck.exitStatus == 0)
    #expect(toolCheck.combinedOutput.contains("rg=1"))
    #expect(toolCheck.combinedOutput.contains("/perl"))
    #expect(toolCheck.combinedOutput.contains("/find"))
    #expect(toolCheck.combinedOutput.contains("/dirname"))

    let dirtyRepo = try temporaryLocalizationAuditRepo()
    defer { try? FileManager.default.removeItem(at: dirtyRepo) }
    try writeSwiftFile(
        at: dirtyRepo.appendingPathComponent("Sources/PulseDockApp/Localized.swift"),
        contents: #"let title = "总览""#
    )

    let dirtyResult = try runLocalizationAudit(in: dirtyRepo, path: toolDirectory.path)

    #expect(dirtyResult.exitStatus == 1)
    #expect(dirtyResult.combinedOutput.contains("Found Chinese text in Swift sources."))
    #expect(dirtyResult.combinedOutput.contains(#"Sources/PulseDockApp/Localized.swift:1:let title = "总览""#))

    let cleanRepo = try temporaryLocalizationAuditRepo()
    defer { try? FileManager.default.removeItem(at: cleanRepo) }
    try writeSwiftFile(
        at: cleanRepo.appendingPathComponent("Sources/PulseDockApp/Clean.swift"),
        contents: #"let title = "Overview""#
    )
    try writeSwiftFile(
        at: cleanRepo.appendingPathComponent("Sources/PulseDockWidget/Clean.swift"),
        contents: #"let widgetTitle = "System Dashboard""#
    )
    try writeSwiftFile(
        at: cleanRepo.appendingPathComponent("Sources/PulseDockApp/NetworkDetail.swift"),
        contents: #"let detail = "Network · ↓ ↑""#
    )
    try writeSwiftFile(
        at: cleanRepo.appendingPathComponent("Sources/SharedMetrics/Clean.swift"),
        contents: #"let unavailable = "Not reported""#
    )

    let cleanResult = try runLocalizationAudit(in: cleanRepo, path: toolDirectory.path)

    #expect(cleanResult.exitStatus == 0)
    #expect(cleanResult.combinedOutput.contains("Localization audit passed: no Chinese text remains in Swift sources."))
}

@Test func sharedMetricSnapshotSwiftContainsNoChineseDisplayLiterals() throws {
    let metricSnapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")

    #expect(metricSnapshot.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
}

@Test func localizationGateDefinesGlobalEnglishResourceBaseline() throws {
    let appInfo = try plistDictionary("Resources/AppInfo.plist")
    let widgetInfo = try plistDictionary("Resources/WidgetInfo.plist")
    let appLocalizations = try #require(appInfo["CFBundleLocalizations"] as? [String])
    let widgetLocalizations = try #require(widgetInfo["CFBundleLocalizations"] as? [String])
    let package = try fixture("Package.swift")
    let generator = try fixture("scripts/generate-xcodeproj.rb")
    let readiness = try fixture("docs/app-store-readiness-checklist.md")
    let release = try fixture("docs/app-store-release-checklist.md")

    #expect(appInfo["CFBundleDevelopmentRegion"] as? String == "en")
    #expect(widgetInfo["CFBundleDevelopmentRegion"] as? String == "en")
    #expect(appLocalizations.contains("en"))
    #expect(appLocalizations.contains("zh-Hans"))
    #expect(widgetLocalizations.contains("en"))
    #expect(widgetLocalizations.contains("zh-Hans"))
    #expect(fileExists("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings"))
    #expect(fileExists("Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings"))
    #expect(fileExists("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"))
    #expect(fileExists("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"))
    #expect(!fileExists("Sources/SharedMetrics/Resources/SharedMetrics.xcstrings"))
    #expect(fileExists("Resources/App/en.lproj/InfoPlist.strings"))
    #expect(fileExists("Resources/App/zh-Hans.lproj/InfoPlist.strings"))
    #expect(fileExists("Resources/Widget/en.lproj/InfoPlist.strings"))
    #expect(fileExists("Resources/Widget/zh-Hans.lproj/InfoPlist.strings"))
    #expect(package.contains(#"defaultLocalization: "en""#))
    #expect(package.contains(#".process("Resources")"#))
    #expect(generator.contains("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings"))
    #expect(generator.contains("Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings"))
    #expect(generator.contains("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"))
    #expect(generator.contains("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"))
    #expect(generator.contains("Resources/App/en.lproj/InfoPlist.strings"))
    #expect(generator.contains("Resources/App/zh-Hans.lproj/InfoPlist.strings"))
    #expect(generator.contains("Resources/Widget/en.lproj/InfoPlist.strings"))
    #expect(generator.contains("Resources/Widget/zh-Hans.lproj/InfoPlist.strings"))
    #expect(generator.contains("development_region = \"en\""))
    #expect(generator.contains(#"known_regions = ["en", "zh-Hans", "Base"]"#))
    #expect(generator.contains("app_target.add_resources"))
    #expect(generator.contains("widget_target.add_resources"))
    #expect(!generator.contains("SharedMetrics.xcstrings"))
    #expect(!readiness.contains("SharedMetrics.xcstrings"))
    #expect(!release.contains("SharedMetrics.xcstrings"))
    #expect(release.contains("Do not submit as a global English-localized app until scripts/audit-localization.sh reports zero Swift Chinese string findings."))
    #expect(readiness.contains("Source folders were renamed to `Sources/PulseDockApp` and `Sources/PulseDockWidget`."))
    #expect(release.contains("Source folders: `Sources/PulseDockApp` and `Sources/PulseDockWidget`"))
}

@Test func appDelegateMenuStringsUsePulseDockAppLocalizationResources() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let catalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let english = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let chinese = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")

    let menuEntries = [
        (symbol: "mainMenuAbout", key: "app.main_menu.about", english: "About Pulse Dock", chinese: "关于 Pulse Dock"),
        (symbol: "mainMenuSettings", key: "app.main_menu.settings", english: "Settings...", chinese: "设置..."),
        (symbol: "mainMenuPrivacyPolicy", key: "app.main_menu.privacy_policy", english: "Privacy Policy", chinese: "隐私政策"),
        (symbol: "mainMenuSupport", key: "app.main_menu.support", english: "Support", chinese: "支持"),
        (symbol: "mainMenuServices", key: "app.main_menu.services", english: "Services", chinese: "服务"),
        (symbol: "mainMenuHideApp", key: "app.main_menu.hide_app", english: "Hide Pulse Dock", chinese: "隐藏 Pulse Dock"),
        (symbol: "mainMenuHideOthers", key: "app.main_menu.hide_others", english: "Hide Others", chinese: "隐藏其他"),
        (symbol: "mainMenuShowAll", key: "app.main_menu.show_all", english: "Show All", chinese: "全部显示"),
        (symbol: "mainMenuQuitApp", key: "app.main_menu.quit_app", english: "Quit Pulse Dock", chinese: "退出 Pulse Dock"),
        (symbol: "mainMenuEdit", key: "app.main_menu.edit", english: "Edit", chinese: "编辑"),
        (symbol: "mainMenuUndo", key: "app.main_menu.undo", english: "Undo", chinese: "撤销"),
        (symbol: "mainMenuRedo", key: "app.main_menu.redo", english: "Redo", chinese: "重做"),
        (symbol: "mainMenuCut", key: "app.main_menu.cut", english: "Cut", chinese: "剪切"),
        (symbol: "mainMenuCopy", key: "app.main_menu.copy", english: "Copy", chinese: "复制"),
        (symbol: "mainMenuPaste", key: "app.main_menu.paste", english: "Paste", chinese: "粘贴"),
        (symbol: "mainMenuDelete", key: "app.main_menu.delete", english: "Delete", chinese: "删除"),
        (symbol: "mainMenuSelectAll", key: "app.main_menu.select_all", english: "Select All", chinese: "全选"),
        (symbol: "mainMenuView", key: "app.main_menu.view", english: "View", chinese: "显示"),
        (symbol: "mainMenuShowOverview", key: "app.main_menu.show_overview", english: "Show Overview", chinese: "显示总览"),
        (symbol: "mainMenuOpenSettings", key: "app.main_menu.open_settings", english: "Open Settings", chinese: "打开设置"),
        (symbol: "mainMenuWindow", key: "app.main_menu.window", english: "Window", chinese: "窗口"),
        (symbol: "mainMenuMinimize", key: "app.main_menu.minimize", english: "Minimize", chinese: "最小化"),
        (symbol: "mainMenuZoom", key: "app.main_menu.zoom", english: "Zoom", chinese: "缩放"),
        (symbol: "mainMenuBringAllToFront", key: "app.main_menu.bring_all_to_front", english: "Bring All to Front", chinese: "全部置于前方")
    ]

    for entry in menuEntries {
        #expect(appStrings.contains("static var \(entry.symbol): String"))
        #expect(appStrings.contains(#"localized("\#(entry.key)", defaultValue: "\#(entry.english)")"#))
        #expect(catalog.contains(#""\#(entry.key)": {"#))
        #expect(catalog.contains(#""value": "\#(entry.english)""#))
        #expect(catalog.contains(#""value": "\#(entry.chinese)""#))
        #expect(english.contains(#""\#(entry.key)" = "\#(entry.english)";"#))
        #expect(chinese.contains(#""\#(entry.key)" = "\#(entry.chinese)";"#))
        #expect(appDelegate.contains("PulseDockAppStrings.\(entry.symbol)"))
    }

    #expect(appDelegate.contains("text != PulseDockAppStrings.notReported"))
    #expect(!appDelegate.contains(#"title: "关于 Pulse Dock""#))
    #expect(!appDelegate.contains(#"title: "设置...""#))
    #expect(!appDelegate.contains(#"title: "隐私政策""#))
    #expect(!appDelegate.contains(#"title: "支持""#))
    #expect(!appDelegate.contains(#"title: "服务""#))
    #expect(!appDelegate.contains(#"title: "编辑""#))
    #expect(!appDelegate.contains(#"title: "显示""#))
    #expect(!appDelegate.contains(#"title: "窗口""#))
    #expect(!appDelegate.contains(#"text != "未报告""#))
}

@Test func dashboardProcessesPageStringsUsePulseDockAppLocalizationResources() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let catalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let english = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let chinese = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")
    let processesStart = try #require(dashboard.range(of: "private struct ProcessesPage")?.lowerBound)
    let sensorsStart = try #require(dashboard.range(of: "private struct SensorsPage")?.lowerBound)
    let processesPage = String(dashboard[processesStart..<sensorsStart])

    let processEntries = [
        (symbol: "processesRunningAppsTitle", key: "app.dashboard.processes.running_apps", english: "Running Apps", chinese: "运行中 App"),
        (symbol: "processesListItemsTitle", key: "app.dashboard.processes.list_items", english: "List Items", chinese: "列表项"),
        (symbol: "processesForegroundAppsTitle", key: "app.dashboard.processes.foreground_apps", english: "Foreground Apps", chinese: "前台 App"),
        (symbol: "processesHiddenAppsTitle", key: "app.dashboard.processes.hidden_apps", english: "Hidden Apps", chinese: "隐藏 App"),
        (symbol: "processesDefaultSubtitle", key: "app.dashboard.processes.default_subtitle", english: "Foreground first, sorted by name", chinese: "前台优先 · 按名称排序"),
        (symbol: "processesColumnName", key: "app.dashboard.processes.column.name", english: "Name", chinese: "名称"),
        (symbol: "processesColumnState", key: "app.dashboard.processes.column.state", english: "State", chinese: "状态"),
        (symbol: "processesColumnArchitecture", key: "app.dashboard.processes.column.architecture", english: "Architecture", chinese: "架构"),
        (symbol: "processesColumnLaunch", key: "app.dashboard.processes.column.launch", english: "Launch", chinese: "启动")
    ]

    for entry in processEntries {
        #expect(appStrings.contains("static var \(entry.symbol): String"))
        #expect(appStrings.contains(#"localized("\#(entry.key)", defaultValue: "\#(entry.english)")"#))
        #expect(catalog.contains(#""\#(entry.key)": {"#))
        #expect(catalog.contains(#""value": "\#(entry.english)""#))
        #expect(catalog.contains(#""value": "\#(entry.chinese)""#))
        #expect(english.contains(#""\#(entry.key)" = "\#(entry.english)";"#))
        #expect(chinese.contains(#""\#(entry.key)" = "\#(entry.chinese)";"#))
        if !entry.key.contains(".column.") {
            #expect(processesPage.contains("PulseDockAppStrings.\(entry.symbol)"))
        }
        #expect(!processesPage.contains(#""\#(entry.chinese)""#))
    }

    #expect(appStrings.contains("static var processesTableColumns: [String]"))
    #expect(processesPage.contains("TableHeader(columns: PulseDockAppStrings.processesTableColumns)"))
    #expect(processesPage.contains("ProcessMetric.listSubtitle(for: snapshot.runningApps, defaultSubtitle: PulseDockAppStrings.processesDefaultSubtitle)"))
}

@Test func dashboardNavigationAndTopBarStringsUsePulseDockAppLocalizationResources() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let catalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let english = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let chinese = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")
    let pageStart = try #require(dashboard.range(of: "enum DashboardPage")?.lowerBound)
    let overviewStart = try #require(dashboard.range(of: "private struct OverviewPage")?.lowerBound)
    let navigationAndTopBar = String(dashboard[pageStart..<overviewStart])

    let entries = [
        (symbol: "dashboardPageOverviewTitle", key: "app.dashboard.page.overview.title", english: "Overview", chinese: "总览"),
        (symbol: "dashboardPageCPUTitle", key: "app.dashboard.page.cpu.title", english: "CPU", chinese: "CPU"),
        (symbol: "dashboardPageGPUTitle", key: "app.dashboard.page.gpu.title", english: "GPU / Display", chinese: "GPU / 显示"),
        (symbol: "dashboardPageMemoryTitle", key: "app.dashboard.page.memory.title", english: "Memory", chinese: "内存"),
        (symbol: "dashboardPageStorageTitle", key: "app.dashboard.page.storage.title", english: "Storage", chinese: "存储"),
        (symbol: "dashboardPageNetworkTitle", key: "app.dashboard.page.network.title", english: "Network", chinese: "网络"),
        (symbol: "dashboardPagePowerTitle", key: "app.dashboard.page.power.title", english: "Power", chinese: "电源"),
        (symbol: "dashboardPageProcessesTitle", key: "app.dashboard.page.processes.title", english: "Apps", chinese: "App"),
        (symbol: "dashboardPageSensorsTitle", key: "app.dashboard.page.sensors.title", english: "Status", chinese: "状态"),
        (symbol: "dashboardPageHistoryTitle", key: "app.dashboard.page.history.title", english: "History", chinese: "历史"),
        (symbol: "dashboardPageSettingsTitle", key: "app.dashboard.page.settings.title", english: "Settings", chinese: "设置"),
        (symbol: "dashboardPageOverviewSubtitle", key: "app.dashboard.page.overview.subtitle", english: "Runtime Overview", chinese: "运行总览"),
        (symbol: "dashboardPageCPUSubtitle", key: "app.dashboard.page.cpu.subtitle", english: "Processor load and cores", chinese: "处理器负载与核心"),
        (symbol: "dashboardPageGPUSubtitle", key: "app.dashboard.page.gpu.subtitle", english: "Graphics devices and displays", chinese: "图形设备与屏幕"),
        (symbol: "dashboardPageMemorySubtitle", key: "app.dashboard.page.memory.subtitle", english: "Usage, cache, and compression", chinese: "占用、缓存与压缩"),
        (symbol: "dashboardPageStorageSubtitle", key: "app.dashboard.page.storage.subtitle", english: "Capacity and disk status", chinese: "容量与磁盘状态"),
        (symbol: "dashboardPageNetworkSubtitle", key: "app.dashboard.page.network.subtitle", english: "Interfaces, throughput, and connectivity", chinese: "接口、吞吐与连接状态"),
        (symbol: "dashboardPagePowerSubtitle", key: "app.dashboard.page.power.subtitle", english: "Battery, power, and thermal state", chinese: "电池、电源与热状态"),
        (symbol: "dashboardPageProcessesSubtitle", key: "app.dashboard.page.processes.subtitle", english: "Running applications", chinese: "运行中的应用"),
        (symbol: "dashboardPageSensorsSubtitle", key: "app.dashboard.page.sensors.subtitle", english: "Thermal state and system signals", chinese: "热状态与系统信号"),
        (symbol: "dashboardPageHistorySubtitle", key: "app.dashboard.page.history.subtitle", english: "Local sample history and thresholds", chinese: "本地采样历史与阈值判断"),
        (symbol: "dashboardPageSettingsSubtitle", key: "app.dashboard.page.settings.subtitle", english: "Display, refresh, and widgets", chinese: "显示、刷新与小组件"),
        (symbol: "dashboardSidebarLocalStatus", key: "app.dashboard.sidebar.local_status", english: "Local Status", chinese: "本机状态"),
        (symbol: "dashboardSidebarLiveSampling", key: "app.dashboard.sidebar.live_sampling", english: "Live Sampling", chinese: "实时采样"),
        (symbol: "dashboardTopBarTagline", key: "app.dashboard.top_bar.tagline", english: "Live local system sampling with a clear, readable overview", chinese: "实时采样本机状态，专注清晰可读的系统概览"),
        (symbol: "dashboardTopBarLocalMachine", key: "app.dashboard.top_bar.local_machine", english: "This Mac", chinese: "本机")
    ]

    for entry in entries {
        expectAppStringEntry(entry, appStrings: appStrings, catalog: catalog, english: english, chinese: chinese)
        #expect(navigationAndTopBar.contains("PulseDockAppStrings.\(entry.symbol)"))
    }

    expectAppStringFunction(symbol: "dashboardSampleChip", key: "app.dashboard.top_bar.sample_format", english: "Sample %@", chinese: "采样 %@", appStrings: appStrings, catalog: catalog, englishResource: english, chineseResource: chinese)
    #expect(navigationAndTopBar.contains("PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText)"))
    #expect(navigationAndTopBar.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
}

@Test func dashboardOverviewPageStringsUsePulseDockAppLocalizationResources() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let catalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let english = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let chinese = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")
    let overviewStart = try #require(dashboard.range(of: "private struct OverviewPage")?.lowerBound)
    let cpuStart = try #require(dashboard.range(of: "private struct CPUPage")?.lowerBound)
    let overviewPage = String(dashboard[overviewStart..<cpuStart])

    let entries = [
        (symbol: "overviewCPUUsageTitle", key: "app.dashboard.overview.cpu_usage.title", english: "CPU Usage", chinese: "CPU 使用率"),
        (symbol: "overviewMemoryUsageTitle", key: "app.dashboard.overview.memory_usage.title", english: "Memory Usage", chinese: "内存占用"),
        (symbol: "overviewNetworkThroughputTitle", key: "app.dashboard.overview.network_throughput.title", english: "Network Throughput", chinese: "网络吞吐"),
        (symbol: "overviewPowerStatusTitle", key: "app.dashboard.overview.power_status.title", english: "Power Status", chinese: "电源状态"),
        (symbol: "overviewRuntimeTrendsTitle", key: "app.dashboard.overview.runtime_trends.title", english: "Runtime Trends", chinese: "运行趋势"),
        (symbol: "overviewSystemStatusTitle", key: "app.dashboard.overview.system_status.title", english: "System Status", chinese: "系统状态"),
        (symbol: "overviewCPUStatusTitle", key: "app.dashboard.overview.cpu_status.title", english: "CPU Status", chinese: "CPU 状态"),
        (symbol: "overviewMemoryStatusTitle", key: "app.dashboard.overview.memory_status.title", english: "Memory Status", chinese: "内存状态"),
        (symbol: "overviewDiskAvailableTitle", key: "app.dashboard.overview.disk_available.title", english: "Disk Available", chinese: "磁盘可用")
    ]

    for entry in entries {
        expectAppStringEntry(entry, appStrings: appStrings, catalog: catalog, english: english, chinese: chinese)
        #expect(overviewPage.contains("PulseDockAppStrings.\(entry.symbol)"))
    }

    #expect(overviewPage.contains("PulseDockAppStrings.metricLoad"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricMemory"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricNetwork"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricDisk"))
    #expect(overviewPage.contains("PulseDockAppStrings.statusThermalTitle"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricUptime"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricKernelVersion"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricRunningApps"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricNetworkConnection"))
    #expect(overviewPage.contains("PulseDockAppStrings.metricGPUDisplays"))
    #expect(overviewPage.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
}

@Test func dashboardCPUMemoryStorageAndNetworkStringsUsePulseDockAppLocalizationResources() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let catalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let english = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let chinese = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")
    let cpuStart = try #require(dashboard.range(of: "private struct CPUPage")?.lowerBound)
    let memoryStart = try #require(dashboard.range(of: "private struct MemoryPage")?.lowerBound)
    let storageStart = try #require(dashboard.range(of: "private struct StoragePage")?.lowerBound)
    let networkStart = try #require(dashboard.range(of: "private struct NetworkPage")?.lowerBound)
    let powerStart = try #require(dashboard.range(of: "private struct PowerPage")?.lowerBound)
    let scopedPages = String(dashboard[cpuStart..<powerStart])
    let cpuPage = String(dashboard[cpuStart..<memoryStart])
    let memoryPage = String(dashboard[memoryStart..<storageStart])
    let storagePage = String(dashboard[storageStart..<networkStart])
    let networkPage = String(dashboard[networkStart..<powerStart])

    let entries = [
        (symbol: "cpuProcessorTitle", key: "app.dashboard.cpu.processor.title", english: "CPU Processor", chinese: "CPU 处理器"),
        (symbol: "cpuProcessorSubtitle", key: "app.dashboard.cpu.processor.subtitle", english: "Processor core statistics", chinese: "处理器核心统计"),
        (symbol: "cpuCurrentTotalUsageTitle", key: "app.dashboard.cpu.current_total_usage", english: "Current Total Usage", chinese: "当前总占用"),
        (symbol: "cpuLoadTrendSubtitle", key: "app.dashboard.cpu.load_trend.subtitle", english: "System load trend", chinese: "系统负载趋势"),
        (symbol: "cpuOneMinuteLabel", key: "app.dashboard.cpu.load.one_minute", english: "1 Minute", chinese: "1 分钟"),
        (symbol: "cpuFiveMinuteLabel", key: "app.dashboard.cpu.load.five_minutes", english: "5 Minutes", chinese: "5 分钟"),
        (symbol: "cpuFifteenMinuteLabel", key: "app.dashboard.cpu.load.fifteen_minutes", english: "15 Minutes", chinese: "15 分钟"),
        (symbol: "cpuProcessorLabel", key: "app.dashboard.cpu.processor.label", english: "Processor", chinese: "处理器"),
        (symbol: "cpuPhysicalCoresLabel", key: "app.dashboard.cpu.physical_cores.label", english: "Physical Cores", chinese: "物理核心"),
        (symbol: "cpuLogicalCoresLabel", key: "app.dashboard.cpu.logical_cores.label", english: "Logical Cores", chinese: "逻辑核心"),
        (symbol: "cpuActiveCoresLabel", key: "app.dashboard.cpu.active_cores.label", english: "Active Cores", chinese: "活动核心"),
        (symbol: "cpuRecentSampleLabel", key: "app.dashboard.cpu.recent_sample.label", english: "Recent Sample", chinese: "最近采样"),
        (symbol: "cpuPerCoreUsageTitle", key: "app.dashboard.cpu.per_core_usage.title", english: "Per-Core Usage", chinese: "每核心使用率"),
        (symbol: "cpuPerCoreUsageSubtitle", key: "app.dashboard.cpu.per_core_usage.subtitle", english: "Shown by logical cores reported by the system", chinese: "按系统报告的逻辑核心显示"),
        (symbol: "cpuPerCoreSampleTitle", key: "app.dashboard.cpu.per_core_sample.title", english: "Per-Core Sample", chinese: "每核心采样"),
        (symbol: "memoryRealtimeStatsSubtitle", key: "app.dashboard.memory.realtime_stats.subtitle", english: "Live memory statistics", chinese: "实时内存统计"),
        (symbol: "memoryUsedTitle", key: "app.dashboard.memory.used.title", english: "Used", chinese: "已用"),
        (symbol: "memoryUsageTrendTitle", key: "app.dashboard.memory.usage_trend.title", english: "Usage Trend", chinese: "占用趋势"),
        (symbol: "memoryTotalLabel", key: "app.dashboard.memory.total.label", english: "Total Memory", chinese: "总内存"),
        (symbol: "memoryFreeLabel", key: "app.dashboard.memory.free.label", english: "Free", chinese: "空闲"),
        (symbol: "memoryCachedLabel", key: "app.dashboard.memory.cached.label", english: "Cached", chinese: "缓存"),
        (symbol: "memoryCompressedLabel", key: "app.dashboard.memory.compressed.label", english: "Compressed", chinese: "压缩"),
        (symbol: "memorySwapLabel", key: "app.dashboard.memory.swap.label", english: "Swap", chinese: "交换"),
        (symbol: "memorySwapAvailableLabel", key: "app.dashboard.memory.swap_available.label", english: "Swap Available", chinese: "交换可用"),
        (symbol: "memorySwapTotalLabel", key: "app.dashboard.memory.swap_total.label", english: "Swap Total", chinese: "交换总量"),
        (symbol: "memoryCompositionTitle", key: "app.dashboard.memory.composition.title", english: "Composition", chinese: "组成"),
        (symbol: "memoryCompositionSubtitle", key: "app.dashboard.memory.composition.subtitle", english: "Unified memory friendly view", chinese: "统一内存友好展示"),
        (symbol: "memoryAppActiveLabel", key: "app.dashboard.memory.app_active.label", english: "App / Active", chinese: "App / 活跃"),
        (symbol: "memoryWiredLabel", key: "app.dashboard.memory.wired.label", english: "Wired", chinese: "有线"),
        (symbol: "memoryCachedFilesLabel", key: "app.dashboard.memory.cached_files.label", english: "Cached Files", chinese: "缓存文件"),
        (symbol: "processesCurrentSessionSubtitle", key: "app.dashboard.processes.current_session_subtitle", english: "Applications in the current session", chinese: "当前会话中的应用列表"),
        (symbol: "storageSpaceTitle", key: "app.dashboard.storage.space.title", english: "Storage Space", chinese: "存储空间"),
        (symbol: "storageLocalVolumeCapacitySubtitle", key: "app.dashboard.storage.local_volume_capacity.subtitle", english: "Local volume capacity", chinese: "本机卷容量"),
        (symbol: "storagePrimaryVolumeLabel", key: "app.dashboard.storage.primary_volume.label", english: "Primary Volume", chinese: "主卷"),
        (symbol: "storageCapacityUsageTitle", key: "app.dashboard.storage.capacity_usage.title", english: "Capacity Usage", chinese: "容量使用"),
        (symbol: "storageCapacityStatsTitle", key: "app.dashboard.storage.capacity_stats.title", english: "Capacity Stats", chinese: "容量统计"),
        (symbol: "storageSystemVolumeInfoSource", key: "app.dashboard.storage.system_volume_info.source", english: "System volume information", chinese: "系统卷信息"),
        (symbol: "storagePrimaryAvailableTitle", key: "app.dashboard.storage.primary_available.title", english: "Primary Volume Available", chinese: "主卷可用"),
        (symbol: "storageExternalVolumesTitle", key: "app.dashboard.storage.external_volumes.title", english: "External Volumes", chinese: "外接卷"),
        (symbol: "storageMountedVolumesSource", key: "app.dashboard.storage.mounted_volumes.source", english: "Mounted volumes", chinese: "已挂载卷"),
        (symbol: "storageVolumeListTitle", key: "app.dashboard.storage.volume_list.title", english: "Volume List", chinese: "卷列表"),
        (symbol: "storageVolumeListSubtitle", key: "app.dashboard.storage.volume_list.subtitle", english: "Mounted storage volumes", chinese: "已挂载的存储卷"),
        (symbol: "networkDownloadTitle", key: "app.dashboard.network.download.title", english: "Download", chinese: "下载"),
        (symbol: "networkUploadTitle", key: "app.dashboard.network.upload.title", english: "Upload", chinese: "上传"),
        (symbol: "networkTotalThroughputTitle", key: "app.dashboard.network.total_throughput.title", english: "Total Throughput", chinese: "总吞吐"),
        (symbol: "networkConnectionStatusTitle", key: "app.dashboard.network.connection_status.title", english: "Connection Status", chinese: "连接状态"),
        (symbol: "networkInterfaceTitle", key: "app.dashboard.network.interface.title", english: "Interface", chinese: "接口"),
        (symbol: "networkRealtimeRateDetail", key: "app.dashboard.network.realtime_rate.detail", english: "Live Rate", chinese: "实时速率"),
        (symbol: "networkCombinedTrafficDetail", key: "app.dashboard.network.combined_traffic.detail", english: "Combined upload and download", chinese: "合并上下行"),
        (symbol: "networkActiveInterfacesDetail", key: "app.dashboard.network.active_interfaces.detail", english: "Active Interfaces", chinese: "活动接口"),
        (symbol: "networkConnectivityTitle", key: "app.dashboard.network.connectivity.title", english: "Connectivity", chinese: "连接能力"),
        (symbol: "networkSystemPathSubtitle", key: "app.dashboard.network.system_path.subtitle", english: "System network path", chinese: "系统网络路径"),
        (symbol: "networkPathLabel", key: "app.dashboard.network.path.label", english: "Path", chinese: "路径"),
        (symbol: "networkCapabilityLabel", key: "app.dashboard.network.capability.label", english: "Capability", chinese: "能力"),
        (symbol: "networkNameResolutionSource", key: "app.dashboard.network.name_resolution.source", english: "Name resolution", chinese: "名称解析"),
        (symbol: "networkLowDataModeLabel", key: "app.dashboard.network.low_data_mode.label", english: "Low Data Mode", chinese: "低数据模式"),
        (symbol: "networkMeteredLabel", key: "app.dashboard.network.metered.label", english: "Metered Network", chinese: "计量网络"),
        (symbol: "networkTrendTitle", key: "app.dashboard.network.trend.title", english: "Network Trend", chinese: "网络趋势"),
        (symbol: "networkRecentLiveSamplesSubtitle", key: "app.dashboard.network.recent_live_samples.subtitle", english: "Recent live samples", chinese: "最近实时采样"),
        (symbol: "networkTotalLabel", key: "app.dashboard.network.total.label", english: "Total", chinese: "总计"),
        (symbol: "networkConnectionLabel", key: "app.dashboard.network.connection.label", english: "Connection", chinese: "连接"),
        (symbol: "networkInterfacesSubtitle", key: "app.dashboard.network.interfaces.subtitle", english: "Network interfaces and links", chinese: "网络接口与链路")
    ]

    for entry in entries {
        expectAppStringEntry(entry, appStrings: appStrings, catalog: catalog, english: english, chinese: chinese)
        #expect(scopedPages.contains("PulseDockAppStrings.\(entry.symbol)"))
    }

    expectAppStringFunction(symbol: "storageUsedOfTotal", key: "app.dashboard.storage.used_of_total_format", english: "Used / %@", chinese: "已用 / %@", appStrings: appStrings, catalog: catalog, englishResource: english, chineseResource: chinese)
    #expect(storagePage.contains("PulseDockAppStrings.storageUsedOfTotal(snapshot.diskTotalText)"))
    #expect(appStrings.contains("static var storageVolumeTableColumns: [String]"))
    #expect(appStrings.contains("static var networkCapabilityTableColumns: [String]"))
    #expect(appStrings.contains("static var networkInterfaceTableColumns: [String]"))
    #expect(storagePage.contains("PulseDockAppStrings.storageVolumeTableColumns"))
    #expect(networkPage.contains("PulseDockAppStrings.networkCapabilityTableColumns"))
    #expect(networkPage.contains("PulseDockAppStrings.networkInterfaceTableColumns"))
    #expect(cpuPage.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
    #expect(memoryPage.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
    #expect(storagePage.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
    #expect(networkPage.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
}

@Test func dashboardStatusPageStringsUsePulseDockAppLocalizationResources() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let catalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let english = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let chinese = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")
    let sensorsStart = try #require(dashboard.range(of: "private struct SensorsPage")?.lowerBound)
    let historyStart = try #require(dashboard.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let sensorsPage = String(dashboard[sensorsStart..<historyStart])

    let statusEntries = [
        (symbol: "statusThermalTitle", key: "app.dashboard.status.thermal.title", english: "Thermal State", chinese: "热状态"),
        (symbol: "statusThermalSubtitle", key: "app.dashboard.status.thermal.subtitle", english: "System thermal control state", chinese: "系统温控状态"),
        (symbol: "statusSystemStatusTitle", key: "app.dashboard.status.system_status", english: "System Status", chinese: "系统状态"),
        (symbol: "statusRealtimeSignalsTitle", key: "app.dashboard.status.realtime_signals.title", english: "Live Signals", chinese: "实时信号"),
        (symbol: "statusRealtimeSignalsSubtitle", key: "app.dashboard.status.realtime_signals.subtitle", english: "Latest sample", chinese: "最近一次采样"),
        (symbol: "statusRulesTitle", key: "app.dashboard.status.rules.title", english: "Status Rules", chinese: "状态判断"),
        (symbol: "statusRulesSubtitle", key: "app.dashboard.status.rules.subtitle", english: "Local results for the current sample", chinese: "当前采样的本地结果"),
        (symbol: "statusRuleColumnRule", key: "app.dashboard.status.rules.column.rule", english: "Rule", chinese: "规则"),
        (symbol: "statusRuleColumnThreshold", key: "app.dashboard.status.rules.column.threshold", english: "Threshold", chinese: "阈值"),
        (symbol: "statusRuleColumnCurrent", key: "app.dashboard.status.rules.column.current", english: "Current", chinese: "当前"),
        (symbol: "statusRuleColumnStatus", key: "app.dashboard.status.rules.column.status", english: "Status", chinese: "状态"),
        (symbol: "statusSystemSignalsTitle", key: "app.dashboard.status.system_signals.title", english: "System Signals", chinese: "系统信号"),
        (symbol: "statusSystemSignalsSubtitle", key: "app.dashboard.status.system_signals.subtitle", english: "Reported data in this view", chinese: "当前显示的数据项"),
        (symbol: "statusSignalColumnName", key: "app.dashboard.status.signals.column.name", english: "Name", chinese: "名称"),
        (symbol: "statusSignalColumnCurrentValue", key: "app.dashboard.status.signals.column.current_value", english: "Current Value", chinese: "当前值"),
        (symbol: "statusSignalColumnSource", key: "app.dashboard.status.signals.column.source", english: "Source", chinese: "来源"),
        (symbol: "statusNormal", key: "app.status.normal", english: "Normal", chinese: "正常"),
        (symbol: "statusWarning", key: "app.status.warning", english: "Warning", chinese: "注意"),
        (symbol: "statusCritical", key: "app.status.critical", english: "Critical", chinese: "严重"),
        (symbol: "statusOnline", key: "app.status.online", english: "Online", chinese: "在线"),
        (symbol: "metricCPU", key: "app.metric.cpu", english: "CPU", chinese: "CPU"),
        (symbol: "metricNetworkConnection", key: "app.metric.network_connection", english: "Network Connection", chinese: "网络连接"),
        (symbol: "metricGPU", key: "app.metric.gpu", english: "GPU", chinese: "GPU"),
        (symbol: "metricSystemThermalState", key: "app.metric.system_thermal_state", english: "System Thermal State", chinese: "系统热状态"),
        (symbol: "metricStorageVolumes", key: "app.metric.storage_volumes", english: "Storage Volumes", chinese: "存储卷"),
        (symbol: "metricSystemVersion", key: "app.metric.system_version", english: "System Version", chinese: "系统版本"),
        (symbol: "metricKernelVersion", key: "app.metric.kernel_version", english: "Kernel Version", chinese: "内核版本"),
        (symbol: "sourceGraphicsDevices", key: "app.source.graphics_devices", english: "Graphics devices", chinese: "图形设备"),
        (symbol: "sourceFileSystemCapacity", key: "app.source.file_system_capacity", english: "File system capacity", chinese: "文件系统容量"),
        (symbol: "sourceLoadAverages", key: "app.source.load_averages", english: "1 / 5 / 15 minutes", chinese: "1 / 5 / 15 分钟"),
        (symbol: "sourceOSVersion", key: "app.source.os_version", english: "Operating system version", chinese: "操作系统版本"),
        (symbol: "sourceSystemBootTime", key: "app.source.system_boot_time", english: "System boot time", chinese: "系统启动时间"),
        (symbol: "sourceThermalState", key: "app.source.thermal_state", english: "Thermal control state", chinese: "温控状态"),
        (symbol: "sourceSystemVersion", key: "app.source.system_version", english: "System version", chinese: "系统版本"),
        (symbol: "sourceDisplayConfiguration", key: "app.source.display_configuration", english: "Display configuration", chinese: "显示配置")
    ]

    let statusSymbolsUsedOutsideSensorsPage = Set(["statusNormal", "statusCritical"])
    for entry in statusEntries {
        expectAppStringEntry(entry, appStrings: appStrings, catalog: catalog, english: english, chinese: chinese)
        #expect(sensorsPage.contains("PulseDockAppStrings.\(entry.symbol)") || entry.key.contains(".column.") || statusSymbolsUsedOutsideSensorsPage.contains(entry.symbol))
    }

    expectAppStringFunction(symbol: "sourceThreshold", key: "app.dashboard.source.threshold_format", english: "Threshold %@", chinese: "阈值 %@", appStrings: appStrings, catalog: catalog, englishResource: english, chineseResource: chinese)
    #expect(appStrings.contains("static var statusRuleTableColumns: [String]"))
    #expect(appStrings.contains("static var statusSignalTableColumns: [String]"))
    #expect(sensorsPage.contains("PulseDockAppStrings.statusRuleTableColumns"))
    #expect(sensorsPage.contains("PulseDockAppStrings.statusSignalTableColumns"))
    #expect(sensorsPage.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
    #expect(dashboard.contains("case .normal: PulseDockAppStrings.statusNormal"))
    #expect(dashboard.contains("guard hasReport else { return PulseDockAppStrings.notReported }"))
}

@Test func dashboardSettingsStringsUsePulseDockAppLocalizationResources() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let catalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let english = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let chinese = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")
    let settingsStart = try #require(dashboard.range(of: "private struct SettingsPage")?.lowerBound)
    let panelStart = try #require(dashboard.range(of: "private struct DashboardPanel")?.lowerBound)
    let settingsPage = String(dashboard[settingsStart..<panelStart])

    let settingsEntries = [
        (symbol: "settingsSupportPrivacyTitle", key: "app.settings.support_privacy.title", english: "Support & Privacy", chinese: "支持与隐私"),
        (symbol: "settingsSupportPrivacySubtitle", key: "app.settings.support_privacy.subtitle", english: "Review information and public links", chinese: "审核信息与公开入口"),
        (symbol: "settingsPrivacyPolicyTitle", key: "app.settings.privacy_policy.title", english: "Privacy Policy", chinese: "隐私政策"),
        (symbol: "settingsPrivacyPolicyDetail", key: "app.settings.privacy_policy.detail", english: "Local sampling, no account, no tracking", chinese: "本地采样、无账号、无追踪"),
        (symbol: "settingsSupportTitle", key: "app.settings.support.title", english: "Support", chinese: "支持"),
        (symbol: "settingsSupportDetail", key: "app.settings.support.detail", english: "Contact channels and version support information", chinese: "联系渠道与版本支持信息"),
        (symbol: "settingsDataSourcesTitle", key: "app.settings.data_sources.title", english: "Data Sources", chinese: "数据来源"),
        (symbol: "settingsDataSourcesSubtitle", key: "app.settings.data_sources.subtitle", english: "System signals used on this page", chinese: "当前页面使用的系统信号"),
        (symbol: "settingsDataSourceColumnFeature", key: "app.settings.data_sources.column.feature", english: "Feature", chinese: "功能"),
        (symbol: "settingsDataSourceColumnStatus", key: "app.settings.data_sources.column.status", english: "Status", chinese: "状态"),
        (symbol: "settingsDataSourceColumnSource", key: "app.settings.data_sources.column.source", english: "Source", chinese: "来源"),
        (symbol: "settingsRefreshDisplayTitle", key: "app.settings.refresh_display.title", english: "Refresh & Display", chinese: "刷新与显示"),
        (symbol: "settingsRefreshDisplaySubtitle", key: "app.settings.refresh_display.subtitle", english: "Low wakeups, readability first", chinese: "低唤醒、可读性优先"),
        (symbol: "settingsMainWindowRefreshTitle", key: "app.settings.main_window_refresh.title", english: "Main Window Refresh", chinese: "主窗口刷新"),
        (symbol: "settingsMainWindowRefreshDetail", key: "app.settings.main_window_refresh.detail", english: "Live trends and status cards", chinese: "实时趋势与状态卡片"),
        (symbol: "settingsMenuBarStatusTitle", key: "app.settings.menu_bar_status.title", english: "Menu Bar Status", chinese: "菜单栏状态"),
        (symbol: "settingsMenuBarStatusDetail", key: "app.settings.menu_bar_status.detail", english: "Show current CPU usage", chinese: "显示当前 CPU 占用"),
        (symbol: "settingsMenuBarCPULabel", key: "app.settings.menu_bar_cpu.label", english: "Menu Bar CPU", chinese: "菜单栏 CPU"),
        (symbol: "settingsWidgetRefreshTitle", key: "app.settings.widget_refresh.title", english: "Widget Refresh", chinese: "小组件刷新"),
        (symbol: "settingsWidgetRefreshDetail", key: "app.settings.widget_refresh.detail", english: "Scheduled by the system timeline", chinese: "由系统按时间线调度"),
        (symbol: "settingsLocalHistoryTitle", key: "app.settings.local_history.title", english: "Local History", chinese: "本地历史"),
        (symbol: "settingsWidgetTitle", key: "app.settings.widget.title", english: "Widget", chinese: "小组件"),
        (symbol: "settingsWidgetSubtitle", key: "app.settings.widget.subtitle", english: "Desktop status preview", chinese: "桌面状态预览"),
        (symbol: "settingsWidgetSizeLabel", key: "app.settings.widget.size.label", english: "Size", chinese: "尺寸"),
        (symbol: "settingsWidgetSizesValue", key: "app.settings.widget.size.value", english: "Small / Medium / Large", chinese: "小 / 中 / 大"),
        (symbol: "settingsWidgetDataSourceLabel", key: "app.settings.widget.data_source.label", english: "Data Source", chinese: "数据源"),
        (symbol: "settingsWidgetDataSourceValue", key: "app.settings.widget.data_source.value", english: "System Sampling", chinese: "系统采样"),
        (symbol: "settingsWidgetRefreshLabel", key: "app.settings.widget.refresh.label", english: "Refresh", chinese: "刷新"),
        (symbol: "settingsWidgetRefreshValue", key: "app.settings.widget.refresh.value", english: "System Scheduled", chinese: "系统调度"),
        (symbol: "settingsWidgetSampleLabel", key: "app.settings.widget.sample.label", english: "Sample", chinese: "采样"),
        (symbol: "settingsWidgetHistoryLabel", key: "app.settings.widget.history.label", english: "History", chinese: "历史"),
        (symbol: "settingsWidgetMainWindowLabel", key: "app.settings.widget.main_window.label", english: "Main Window", chinese: "主窗口"),
        (symbol: "metricCPUMemory", key: "app.metric.cpu_memory", english: "CPU / Memory", chinese: "CPU / 内存"),
        (symbol: "metricRunningApps", key: "app.metric.running_apps", english: "Running Apps", chinese: "运行中 App"),
        (symbol: "metricGPUDisplays", key: "app.metric.gpu_displays", english: "GPU / Displays", chinese: "GPU / 显示器"),
        (symbol: "metricVolumeCapacity", key: "app.metric.volume_capacity", english: "Volume Capacity", chinese: "卷容量"),
        (symbol: "metricPowerThermalState", key: "app.metric.power_thermal_state", english: "Power / Thermal State", chinese: "电源 / 热状态"),
        (symbol: "metricSystemVersionUptimeKernel", key: "app.metric.system_version_uptime_kernel", english: "System Version / Uptime / Kernel Version", chinese: "系统版本 / 运行时间 / 内核版本"),
        (symbol: "sourceSystemProcessorMemoryStats", key: "app.source.system_processor_memory_stats", english: "System processor and memory statistics", chinese: "系统处理器与内存统计"),
        (symbol: "sourceConnectionInterfaceTraffic", key: "app.source.connection_interface_traffic", english: "Connection status and interface traffic", chinese: "连接状态与接口流量"),
        (symbol: "sourceApplicationSessionList", key: "app.source.application_session_list", english: "Application session list", chinese: "应用会话列表"),
        (symbol: "sourceGraphicsDisplayConfiguration", key: "app.source.graphics_display_configuration", english: "Graphics devices and display configuration", chinese: "图形设备与显示配置"),
        (symbol: "sourcePowerThermalState", key: "app.source.power_thermal_state", english: "Power and thermal control state", chinese: "电源与温控状态"),
        (symbol: "sourceSystemVersionBootTime", key: "app.source.system_version_boot_time", english: "System version and boot time", chinese: "系统版本与启动时间")
    ]

    for entry in settingsEntries {
        expectAppStringEntry(entry, appStrings: appStrings, catalog: catalog, english: english, chinese: chinese)
        #expect(settingsPage.contains("PulseDockAppStrings.\(entry.symbol)") || entry.key.contains(".column."))
    }

    expectAppStringFunction(symbol: "settingsLocalHistoryDetail", key: "app.settings.local_history.detail_format", english: "Keep the most recent %d samples", chinese: "保留最近 %d 次采样", appStrings: appStrings, catalog: catalog, englishResource: english, chineseResource: chinese)
    #expect(appStrings.contains("static var settingsDataSourceTableColumns: [String]"))
    #expect(settingsPage.contains("PulseDockAppStrings.settingsDataSourceTableColumns"))
    #expect(settingsPage.contains("PulseDockAppStrings.settingsLocalHistoryDetail(sampleCount: store.historyDepth.sampleCount)"))
    #expect(settingsPage.range(of: #"\p{Script=Han}"#, options: .regularExpression) == nil)
}

private func localizationAuditScript() throws -> String {
    try fixture("scripts/audit-localization.sh")
}

private func expectAppStringEntry(
    _ entry: (symbol: String, key: String, english: String, chinese: String),
    appStrings: String,
    catalog: String,
    english: String,
    chinese: String
) {
    #expect(appStrings.contains("static var \(entry.symbol): String"))
    #expect(appStrings.contains(#"localized("\#(entry.key)", defaultValue: "\#(entry.english)")"#))
    #expect(catalog.contains(#""\#(entry.key)": {"#))
    #expect(catalog.contains(#""value": "\#(entry.english)""#))
    #expect(catalog.contains(#""value": "\#(entry.chinese)""#))
    #expect(english.contains(#""\#(entry.key)" = "\#(entry.english)";"#))
    #expect(chinese.contains(#""\#(entry.key)" = "\#(entry.chinese)";"#))
}

private func expectAppStringFunction(
    symbol: String,
    key: String,
    english: String,
    chinese: String,
    appStrings: String,
    catalog: String,
    englishResource: String,
    chineseResource: String
) {
    #expect(appStrings.contains("static func \(symbol)("))
    #expect(appStrings.contains(#"localizedFormat("\#(key)", defaultValue: "\#(english)""#))
    #expect(catalog.contains(#""\#(key)": {"#))
    #expect(catalog.contains(#""value": "\#(english)""#))
    #expect(catalog.contains(#""value": "\#(chinese)""#))
    #expect(englishResource.contains(#""\#(key)" = "\#(english)";"#))
    #expect(chineseResource.contains(#""\#(key)" = "\#(chinese)";"#))
}

private func fixture(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

private func plistDictionary(_ path: String) throws -> [String: Any] {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try Data(contentsOf: root.appendingPathComponent(path))
    return try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )
}

private func fileExists(_ path: String) -> Bool {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path)
}

private func temporaryLocalizationAuditRepo() throws -> URL {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
        .appendingPathComponent("LocalizationGateTests-\(UUID().uuidString)", isDirectory: true)
    let scripts = root.appendingPathComponent("scripts", isDirectory: true)
    let sourceRoots = [
        root.appendingPathComponent("Sources/PulseDockApp", isDirectory: true),
        root.appendingPathComponent("Sources/PulseDockWidget", isDirectory: true),
        root.appendingPathComponent("Sources/SharedMetrics", isDirectory: true)
    ]

    try fileManager.createDirectory(at: scripts, withIntermediateDirectories: true)
    for sourceRoot in sourceRoots {
        try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    }

    try fileManager.copyItem(
        at: URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("scripts/audit-localization.sh"),
        to: scripts.appendingPathComponent("audit-localization.sh")
    )

    return root
}

private func temporaryLocalizationAuditToolDirectory() throws -> URL {
    let fileManager = FileManager.default
    let tools = fileManager.temporaryDirectory
        .appendingPathComponent("LocalizationGateTools-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: tools, withIntermediateDirectories: true)

    for tool in ["find", "perl", "dirname"] {
        try fileManager.createSymbolicLink(
            at: tools.appendingPathComponent(tool),
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/\(tool)")
        )
    }

    return tools
}

private func writeSwiftFile(at url: URL, contents: String) throws {
    try contents.write(to: url, atomically: true, encoding: .utf8)
}

private func runLocalizationAudit(in repo: URL, path: String) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/audit-localization.sh"]
    process.currentDirectoryURL = repo
    process.environment = ["PATH": path]

    return try run(process)
}

private func runRestrictedPathShell(_ command: String, path: String) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    process.environment = ["PATH": path]

    return try run(process)
}

private func run(_ process: Process) throws -> ProcessResult {
    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error

    try process.run()
    process.waitUntilExit()

    let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    return ProcessResult(
        exitStatus: process.terminationStatus,
        standardOutput: outputText,
        standardError: errorText
    )
}

private struct ProcessResult {
    var exitStatus: Int32
    var standardOutput: String
    var standardError: String

    var combinedOutput: String {
        standardOutput + standardError
    }
}
