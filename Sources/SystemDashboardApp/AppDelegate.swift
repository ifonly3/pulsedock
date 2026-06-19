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

private struct HiddenStatusPopoverContent {
    let view: NSView
    let alphaValue: CGFloat
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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dashboardWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var statusHostingController: NSHostingController<WidgetPanelView>?
    private var cancellables = Set<AnyCancellable>()
    private let store = MetricsStore()
    private let router = DashboardRouter()
    private var menuPopoverSize: NSSize {
        NSSize(width: MenuPopoverLayout.width, height: MenuPopoverLayout.height)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMainMenu()
        showDashboardWindow(activating: true)
        createStatusItem()
        DispatchQueue.main.async { [store] in
            store.start()
        }
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
        window.minSize = NSSize(width: 1180, height: 760)
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
        popover.animates = false
        popover.contentSize = menuPopoverSize
        let hostingController = makeStatusHostingController(popoverHeight: menuPopoverSize.height)
        hostingController.preferredContentSize = menuPopoverSize
        popover.contentViewController = hostingController
        statusHostingController = hostingController

        store.$snapshot
            .sink { [weak self] _ in
                self?.updateStatusButtonTitle()
            }
            .store(in: &cancellables)

        store.$showsMenuBarCPU
            .sink { [weak self] _ in
                self?.updateStatusButtonTitle()
            }
            .store(in: &cancellables)

        statusPopover = popover
    }

    private func makeWidgetPanelView(popoverHeight: CGFloat) -> WidgetPanelView {
        WidgetPanelView(
            store: store,
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

    private func makeStatusHostingController(popoverHeight: CGFloat) -> NSHostingController<WidgetPanelView> {
        let contentSize = NSSize(width: MenuPopoverLayout.width, height: popoverHeight)
        let hostingController = NSHostingController(rootView: makeWidgetPanelView(popoverHeight: popoverHeight))
        hostingController.sizingOptions = []
        hostingController.preferredContentSize = contentSize
        hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
        hostingController.view.setFrameSize(contentSize)
        hostingController.view.layoutSubtreeIfNeeded()
        return hostingController
    }

    private func updateStatusButtonTitle() {
        statusItem?.length = store.showsMenuBarCPU ? MenuBarStatusItemLayout.cpuTitleLength : MenuBarStatusItemLayout.compactLength
        statusItem?.button?.title = store.showsMenuBarCPU ? " \(store.snapshot.cpuText)" : ""
    }

    @objc private func toggleStatusPopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover = statusPopover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            let presentation = prepareStatusPopover(popover, for: button)
            showPreparedStatusPopover(popover, for: button, presentation: presentation)
        }
    }

    private func showPreparedStatusPopover(_ popover: NSPopover, for button: NSStatusBarButton, presentation: StatusPopoverPresentation) {
        let hiddenContent = hideStatusPopoverContentBeforeShowing(popover)
        popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)
        guard let window = popover.contentViewController?.view.window else {
            restoreStatusPopoverContentAfterShowing(hiddenContent)
            return
        }

        let originalAlphaValue = window.alphaValue
        window.alphaValue = 0
        constrainStatusPopoverWindow(popover, for: button, presentation: presentation)
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        window.alphaValue = originalAlphaValue
        restoreStatusPopoverContentAfterShowing(hiddenContent)
    }

    private func hideStatusPopoverContentBeforeShowing(_ popover: NSPopover) -> HiddenStatusPopoverContent? {
        guard let view = popover.contentViewController?.view else { return nil }
        let hiddenContent = HiddenStatusPopoverContent(view: view, alphaValue: view.alphaValue)
        view.alphaValue = 0
        return hiddenContent
    }

    private func restoreStatusPopoverContentAfterShowing(_ hiddenContent: HiddenStatusPopoverContent?) {
        guard let hiddenContent else { return }
        hiddenContent.view.alphaValue = hiddenContent.alphaValue
    }

    private func prepareStatusPopover(_ popover: NSPopover, for button: NSStatusBarButton) -> StatusPopoverPresentation {
        button.window?.layoutIfNeeded()
        let visibleFrame = statusPopoverVisibleFrame(for: button)
        let placement = statusPopoverPlacement(for: button)
        let contentSize = placement.size
        let hostingController = makeStatusHostingController(popoverHeight: contentSize.height)
        hostingController.preferredContentSize = contentSize
        hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
        hostingController.view.setFrameSize(contentSize)
        hostingController.view.layoutSubtreeIfNeeded()
        popover.contentSize = contentSize
        popover.contentViewController = hostingController
        statusHostingController = hostingController

        return StatusPopoverPresentation(
            placement: placement,
            anchorRect: statusButtonAnchorRect(button, placement: placement),
            preferredEdge: placement.preferredEdge.nsRectEdge,
            visibleFrame: visibleFrame
        )
    }

    private func statusPopoverPlacement(for button: NSStatusBarButton) -> MenuBarPopoverGeometry.Placement {
        MenuBarPopoverGeometry.placement(
            preferredSize: menuPopoverSize,
            minimumHeight: MenuPopoverLayout.minimumHeight,
            screenMargin: MenuPopoverLayout.screenMargin,
            visibleFrame: statusPopoverVisibleFrame(for: button),
            anchorFrame: statusButtonScreenFrame(button),
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

    private func statusButtonAnchorRect(_ button: NSStatusBarButton, placement: MenuBarPopoverGeometry.Placement) -> NSRect {
        let bounds = button.bounds
        let anchorWidth = min(max(bounds.width, 18), 30)
        var anchorCenterX = bounds.midX
        if let anchorScreenMidX = placement.anchorScreenMidX,
           let buttonFrame = statusButtonScreenFrame(button) {
            anchorCenterX += anchorScreenMidX - buttonFrame.midX
        }
        return NSRect(
            x: anchorCenterX - anchorWidth / 2,
            y: bounds.minY,
            width: anchorWidth,
            height: bounds.height
        )
    }

    private func constrainStatusPopoverWindow(_ popover: NSPopover, for button: NSStatusBarButton, presentation: StatusPopoverPresentation) {
        guard let window = popover.contentViewController?.view.window,
              let visibleFrame = presentation.visibleFrame ?? statusPopoverVisibleFrame(for: button) else { return }

        var constrainedFrame = MenuBarPopoverGeometry.constrainedWindowFrame(
            window.frame,
            visibleFrame: visibleFrame,
            screenMargin: MenuPopoverLayout.screenMargin
        )
        let heightDelta = max(0, window.frame.height - constrainedFrame.height)
        if heightDelta > 0 {
            fitStatusPopoverContent(popover, height: popover.contentSize.height - heightDelta)
            constrainedFrame = MenuBarPopoverGeometry.constrainedWindowFrame(
                window.frame,
                visibleFrame: visibleFrame,
                screenMargin: MenuPopoverLayout.screenMargin
            )
        }
        guard constrainedFrame != window.frame else { return }

        window.setFrame(constrainedFrame, display: false, animate: false)
    }

    private func fitStatusPopoverContent(_ popover: NSPopover, height: CGFloat) {
        let fittedHeight = max(1, min(popover.contentSize.height, height))
        guard fittedHeight < popover.contentSize.height else { return }

        let contentSize = NSSize(width: MenuPopoverLayout.width, height: fittedHeight)
        let hostingController = makeStatusHostingController(popoverHeight: fittedHeight)
        hostingController.preferredContentSize = contentSize
        hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
        hostingController.view.setFrameSize(contentSize)
        hostingController.view.layoutSubtreeIfNeeded()
        popover.contentSize = contentSize
        popover.contentViewController = hostingController
        statusHostingController = hostingController
    }

    private func openDashboardFromPopover() {
        statusPopover?.performClose(nil)
        showDashboardWindow(activating: true)
    }

    private func openSettingsFromPopover() {
        router.openSettings()
        openDashboardFromPopover()
    }
}
