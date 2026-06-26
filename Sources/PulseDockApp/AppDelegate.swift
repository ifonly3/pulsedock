import AppKit
import Combine
import SwiftUI
#if canImport(SharedMetrics)
import SharedMetrics
#endif

private enum MenuBarStatusItemLayout {
    static let compactLength = NSStatusItem.squareLength
    static let cpuTitleLength: CGFloat = 72
}

private struct StatusPopoverPresentation {
    let placement: MenuBarPopoverGeometry.Placement
    let anchorRect: NSRect
    let preferredEdge: NSRectEdge
    let visibleFrame: NSRect?
}

private extension MenuBarPopoverGeometry.Edge {
    var nsRectEdge: NSRectEdge {
        switch self {
        case .minY:
            return .minY
        case .maxY:
            return .maxY
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var dashboardWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var statusHostingController: NSHostingController<WidgetPanelView>?
    private var isStatusPopoverClosing = false
    private var statusPopoverSuppressToggleUntil: Date?
    private var cancellables = Set<AnyCancellable>()
    private let store = MetricsStore()
    private let router = DashboardRouter()
    private let statusPopoverToggleSuppressionInterval: TimeInterval = 0.25
    private var menuPopoverSize: NSSize {
        NSSize(width: MenuPopoverLayout.width, height: MenuPopoverLayout.height)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMainMenu()
        showDashboardWindow(activating: true)
        createStatusItem()
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboardWindow(activating: true)
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        mainMenu.addItem(makeAppMenu())
        mainMenu.addItem(makeEditMenu())
        mainMenu.addItem(makeViewMenu())
        mainMenu.addItem(makeWindowMenu())
        NSApp.mainMenu = mainMenu
    }

    private func makeAppMenu() -> NSMenuItem {
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Pulse Dock")

        appMenu.addItem(NSMenuItem(title: "关于 Pulse Dock", action: #selector(showAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettingsFromMenu(_:)), keyEquivalent: ",")
        settingsItem.keyEquivalent = ","
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(NSMenuItem(title: "隐私政策", action: #selector(openPrivacyPolicyFromMenu(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "支持", action: #selector(openSupportFromMenu(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())

        let servicesItem = NSMenuItem(title: "服务", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "服务")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(NSMenuItem(title: "隐藏 Pulse Dock", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthersItem = NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(NSMenuItem(title: "全部显示", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "退出 Pulse Dock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        appMenuItem.submenu = appMenu
        return appMenuItem
    }

    private func makeEditMenu() -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")

        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "删除", action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        editMenuItem.submenu = editMenu
        return editMenuItem
    }

    private func makeViewMenu() -> NSMenuItem {
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "显示")
        viewMenu.addItem(NSMenuItem(title: "显示总览", action: #selector(showDashboardFromMenu(_:)), keyEquivalent: "1"))
        viewMenu.addItem(NSMenuItem(title: "打开设置", action: #selector(openSettingsFromMenu(_:)), keyEquivalent: ""))
        viewMenuItem.submenu = viewMenu
        return viewMenuItem
    }

    private func makeWindowMenu() -> NSMenuItem {
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "缩放", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "全部置于前方", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        NSApp.windowsMenu = windowMenu
        windowMenuItem.submenu = windowMenu
        return windowMenuItem
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Pulse Dock",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        ])
    }

    @objc private func openSettingsFromMenu(_ sender: Any?) {
        showDashboardWindow(activating: true)
        router.selectedPage = .settings
    }

    @objc private func openPrivacyPolicyFromMenu(_ sender: Any?) {
        PulseDockLinks.openPrivacyPolicy()
    }

    @objc private func openSupportFromMenu(_ sender: Any?) {
        PulseDockLinks.openSupport()
    }

    @objc private func showDashboardFromMenu(_ sender: Any?) {
        showDashboardWindow(activating: true)
        router.selectedPage = .overview
    }

    private func showDashboardWindow(activating: Bool) {
        if dashboardWindow == nil {
            createDashboardWindow()
        }

        dashboardWindow?.makeKeyAndOrderFront(nil)
        if activating {
            NSApp.activate()
        }
    }

    private func createDashboardWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pulse Dock"
        window.setFrameAutosaveName("PulseDockMainWindow")
        window.minSize = NSSize(width: 960, height: 640)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: DashboardView(store: store, router: router))
        window.center()
        dashboardWindow = window
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: MenuBarStatusItemLayout.compactLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg.rectangle", accessibilityDescription: "Pulse Dock")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggleStatusPopover(_:))
        }
        statusItem = item
        updateStatusButtonTitle()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = menuPopoverSize

        store.$snapshot.combineLatest(store.$showsMenuBarCPU)
            .sink { [weak self] _, _ in
                self?.updateStatusButtonTitle()
            }
            .store(in: &cancellables)

        statusPopover = popover
    }

    private func makeWidgetPanelView(popoverWidth: CGFloat, popoverHeight: CGFloat) -> WidgetPanelView {
        WidgetPanelView(
            store: store,
            popoverWidth: popoverWidth,
            popoverHeight: popoverHeight,
            openDashboard: { [weak self] in
                self?.openDashboardFromPopover()
            },
            togglePause: { [store] in
                store.togglePause()
            },
            openSettings: { [weak self] in
                self?.openSettingsFromPopover()
            }
        )
    }

    private func makeStatusHostingController(contentSize: NSSize) -> NSHostingController<WidgetPanelView> {
        let hostingController = NSHostingController(
            rootView: makeWidgetPanelView(
                popoverWidth: contentSize.width,
                popoverHeight: contentSize.height
            )
        )
        hostingController.sizingOptions = []
        hostingController.preferredContentSize = contentSize
        hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
        hostingController.view.setFrameSize(contentSize)
        hostingController.view.layoutSubtreeIfNeeded()
        return hostingController
    }

    private func installFreshStatusHostingController(_ contentSize: NSSize, in popover: NSPopover) {
        popover.contentViewController = nil
        statusHostingController = nil

        let hostingController = makeStatusHostingController(contentSize: contentSize)
        hostingController.preferredContentSize = contentSize
        hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
        hostingController.view.setFrameSize(contentSize)
        hostingController.view.layoutSubtreeIfNeeded()
        statusHostingController = hostingController
        popover.contentViewController = hostingController
    }

    private func resetStatusPopoverContentHost() {
        statusPopover?.contentViewController = nil
        statusHostingController = nil
    }

    private var statusButtonCPUText: String? {
        guard store.snapshot.hasCPUUsageReport else { return nil }
        let text = store.snapshot.cpuText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "未报告" else { return nil }
        return text
    }

    private func updateStatusButtonTitle() {
        guard store.showsMenuBarCPU else {
            statusItem?.length = MenuBarStatusItemLayout.compactLength
            statusItem?.button?.title = ""
            return
        }

        guard let cpuText = statusButtonCPUText else {
            statusItem?.length = MenuBarStatusItemLayout.compactLength
            statusItem?.button?.title = ""
            return
        }

        statusItem?.length = MenuBarStatusItemLayout.cpuTitleLength
        statusItem?.button?.title = " \(cpuText)"
    }

    @objc private func toggleStatusPopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover = statusPopover else { return }

        guard !shouldSuppressStatusPopoverToggle() else { return }

        if popover.isShown {
            closeStatusPopover(popover)
        } else {
            let presentation = prepareStatusPopover(popover, for: button)
            showPreparedStatusPopover(popover, for: button, presentation: presentation)
        }
    }

    private func showPreparedStatusPopover(_ popover: NSPopover, for button: NSStatusBarButton, presentation: StatusPopoverPresentation) {
        popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)
        popover.contentViewController?.view.window?.contentView?.layoutSubtreeIfNeeded()
    }

    private func prepareStatusPopover(_ popover: NSPopover, for button: NSStatusBarButton) -> StatusPopoverPresentation {
        let visibleFrame = statusPopoverVisibleFrame(for: button)
        let anchorFrame = statusButtonScreenFrame(button)
        let placement = statusPopoverPlacement(for: button, visibleFrame: visibleFrame, anchorFrame: anchorFrame)
        let contentSize = placement.size
        installFreshStatusHostingController(contentSize, in: popover)
        popover.contentSize = contentSize

        return StatusPopoverPresentation(
            placement: placement,
            anchorRect: statusButtonAnchorRect(button, placement: placement, anchorFrame: anchorFrame),
            preferredEdge: placement.preferredEdge.nsRectEdge,
            visibleFrame: visibleFrame
        )
    }

    private func statusPopoverPlacement(
        for button: NSStatusBarButton,
        visibleFrame: NSRect?,
        anchorFrame: NSRect?
    ) -> MenuBarPopoverGeometry.Placement {
        MenuBarPopoverGeometry.placement(
            preferredSize: menuPopoverSize,
            minimumHeight: MenuPopoverLayout.minimumHeight,
            screenMargin: MenuPopoverLayout.screenMargin,
            visibleFrame: visibleFrame,
            anchorFrame: anchorFrame,
            anchorKind: statusPopoverAnchorKind(for: button)
        )
    }

    private func statusPopoverAnchorKind(for button: NSStatusBarButton) -> MenuBarPopoverGeometry.AnchorKind {
        isStatusBarAnchorWindow(button.window) ? .statusBar : .regular
    }

    private func isStatusBarAnchorWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return window.level.rawValue >= NSWindow.Level.statusBar.rawValue
    }

    private func statusPopoverVisibleFrame(for button: NSStatusBarButton) -> NSRect? {
        button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
    }

    private func statusButtonScreenFrame(_ button: NSStatusBarButton) -> NSRect? {
        guard let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func statusButtonAnchorRect(
        _ button: NSStatusBarButton,
        placement: MenuBarPopoverGeometry.Placement,
        anchorFrame: NSRect?
    ) -> NSRect {
        let bounds = button.bounds
        let anchorWidth = min(max(bounds.width, 18), 30)
        let proposedAnchorCenterX: CGFloat
        if let anchorScreenMidX = placement.anchorScreenMidX,
           let anchorFrame {
            proposedAnchorCenterX = bounds.midX + anchorScreenMidX - anchorFrame.midX
        } else {
            proposedAnchorCenterX = bounds.midX
        }
        let minimumAnchorCenterX = bounds.minX + min(anchorWidth, bounds.width) / 2
        let maximumAnchorCenterX = bounds.maxX - min(anchorWidth, bounds.width) / 2
        let anchorCenterX = minimumAnchorCenterX <= maximumAnchorCenterX
            ? min(max(proposedAnchorCenterX, minimumAnchorCenterX), maximumAnchorCenterX)
            : bounds.midX

        return NSRect(
            x: anchorCenterX - anchorWidth / 2,
            y: bounds.minY,
            width: anchorWidth,
            height: bounds.height
        )
    }

    private func shouldSuppressStatusPopoverToggle() -> Bool {
        if isStatusPopoverClosing {
            if let statusPopoverSuppressToggleUntil, Date() >= statusPopoverSuppressToggleUntil {
                isStatusPopoverClosing = false
                self.statusPopoverSuppressToggleUntil = nil
                return false
            }
            return true
        }
        guard let statusPopoverSuppressToggleUntil else { return false }
        if Date() < statusPopoverSuppressToggleUntil {
            return true
        }
        self.statusPopoverSuppressToggleUntil = nil
        return false
    }

    private func closeStatusPopover(_ popover: NSPopover) {
        isStatusPopoverClosing = true
        statusPopoverSuppressToggleUntil = Date().addingTimeInterval(statusPopoverToggleSuppressionInterval)
        popover.close()
    }

    private func openDashboardFromPopover() {
        if let statusPopover {
            closeStatusPopover(statusPopover)
        }
        showDashboardWindow(activating: true)
    }

    private func openSettingsFromPopover() {
        router.openSettings()
        openDashboardFromPopover()
    }

    func popoverWillClose(_ notification: Notification) {
        guard notification.object as? NSPopover === statusPopover else { return }
        isStatusPopoverClosing = true
        statusPopoverSuppressToggleUntil = Date().addingTimeInterval(statusPopoverToggleSuppressionInterval)
    }

    func popoverDidClose(_ notification: Notification) {
        guard notification.object as? NSPopover === statusPopover else { return }
        isStatusPopoverClosing = false
        resetStatusPopoverContentHost()
    }
}
