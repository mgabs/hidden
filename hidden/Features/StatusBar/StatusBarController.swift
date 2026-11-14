//
//  StatusBarController.swift
//  vanillaClone
//
//  Created by Thanh Nguyen on 1/30/19.
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit
import UserNotifications

class StatusBarController: MenuBarItemProvider {

    //MARK: - Variables
    private var activeMenuTrackingCount = 0
    private var isPopupMenuOpen: Bool { activeMenuTrackingCount > 0 }

    private lazy var autoCollapseCoordinator = AutoCollapseCoordinator(
        isAutoHideEnabled: { Preferences.isAutoHide },
        delayProvider: { Preferences.numberOfSecondForAutoHide },
        isCollapsed: { [weak self] in self?.isCollapsed ?? true },
        isBusy: { [weak self] in
            guard let self = self else { return false }
            return self.isMouseInMenuBar || self.isPreferencesWindowVisible || self.isPopupMenuOpen
        },
        isAccessibilityAuthorized: { AXIsProcessTrusted() },
        requestCollapse: { [weak self] completion in
            self?.collapseMenuBar(completion: completion)
        },
        notifyAccessibilityRequired: { [weak self] in
            self?.notifyAccessibilityPermissionNeeded()
        }
    )

    //MARK: - BarItems

    private let btnExpandCollapse = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let btnSeparate = NSStatusBar.system.statusItem(withLength: 1)
    private var btnAlwaysHidden:NSStatusItem? = nil

    //MARK: - Notch Overflow
    private var notchOverflowController = NotchOverflowController()

    var toggleItem: NSStatusItem { btnExpandCollapse }
    var separatorItem: NSStatusItem { btnSeparate }
    var alwaysHiddenItem: NSStatusItem? { btnAlwaysHidden }

    // How hiding is achieved (separator lengths) lives in the engine; this class
    // owns the items, the UI, and when to collapse or expand.
    private lazy var menuBarEngine: MenuBarEngine = MenuBarEngineFactory.make(items: self)

    private let imgIconLine = NSImage(named:NSImage.Name("ic_line"))

    private var isCollapsed: Bool {
        return menuBarEngine.state == .collapsed
    }

    private var isBtnAlwaysHiddenValidPosition: Bool {
        if !Preferences.alwaysHiddenSectionEnabled { return true }
        return menuBarEngine.isAlwaysHiddenSeparatorPlaced
    }

    private var isToggle = false

    private var hoverMonitor: Any?
    private var hoverDwellTimer: Timer?
    private var cachedMenuBarFrames: [CGRect]?

    // True while the pointer sits in any screen's menubar band (the strip between
    // visibleFrame.maxY and frame.maxY, which is the menubar's exact height there).
    // On fullscreen spaces the menubar is hidden and the band collapses to ~zero,
    // so this returns false there: intentional, no visible menubar = no deferral.
    private var isMouseInMenuBar: Bool {
        let frames = cachedMenuBarFrames ?? {
            let computed = NSScreen.screens.map { screen in
                CGRect(
                    x: screen.frame.minX,
                    y: screen.visibleFrame.maxY,
                    width: screen.frame.width,
                    height: max(0, screen.frame.maxY - screen.visibleFrame.maxY)
                )
            }
            cachedMenuBarFrames = computed
            return computed
        }()
        let mouse = NSEvent.mouseLocation
        return frames.contains { $0.contains(mouse) }
    }

    // The preferences window is an ordinary app window, not in the menu bar, so
    // the mouse-in-menubar guard does not cover it. With "use full menu bar on
    // expanding" on, an auto-collapse deactivates the app and dismisses this
    // window mid-edit (#170, same family as #66/#151). Defer the collapse while
    // it is on screen, without creating the controller or loading its window
    // when preferences were never opened.
    private var isPreferencesWindowVisible: Bool {
        return PreferencesWindowController.isVisible
    }

    //MARK: - Methods
    init() {
        setupUI()
        restoreRemovedStatusItems()
        setupAlwayHideStatusBar()
        setupHoverToExpandIfEnabled()
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWorkspaceMenuBarChange), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWorkspaceMenuBarChange), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateAutoHide), name: .prefsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncActivationPolicyWithFullStatusBar), name: .useFullStatusBarToggle, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMenuDidBeginTracking), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMenuDidEndTracking), name: NSMenu.didEndTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWindowWillClose), name: NSWindow.willCloseNotification, object: nil)
        // Sections are read from where the items sit, so wait until macOS has put
        // them back in place (the always-hidden separator may have been taken
        // out of the bar when the app quit).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            if Preferences.areSeparatorsHidden { self.hideSeparators() }
            self.collapseMenuBar { [weak self] result in
                if result == .unavailable {
                    self?.autoCollapseCoordinator.handleUnavailable()
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        autoCollapseCoordinator.cancel()
        hoverDwellTimer?.invalidate()
        if let monitor = hoverMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // Opt-in via `defaults write com.mgabs.hiddenbar hoverToExpand -bool true`.
    // No monitor is installed at all unless the pref is true at launch.
    private func setupHoverToExpandIfEnabled() {
        guard Preferences.hoverToExpand else { return }
        NSLog("HoverToExpand: enabled, installing global mouse monitor")
        hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self = self else { return }
            guard self.isCollapsed && self.isMouseInMenuBar else {
                self.hoverDwellTimer?.invalidate()
                self.hoverDwellTimer = nil
                return
            }
            // Short dwell so a pointer merely passing through doesn't expand.
            guard self.hoverDwellTimer == nil else { return }
            self.hoverDwellTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.hoverDwellTimer = nil
                if self.isCollapsed && self.isMouseInMenuBar {
                    self.expandMenubar()
                }
            }
        }
    }

    @objc private func handleScreenParametersChanged() {
        cachedMenuBarFrames = nil
        invalidateNativeLayoutAfterEnvironmentChange()
    }

    // A new status item or a wake can change the Accessibility inventory just
    // as much as a monitor hot-plug.  The native engine releases its global
    // restriction here instead of applying a stale per-display classification.
    @objc private func handleWorkspaceMenuBarChange() {
        invalidateNativeLayoutAfterEnvironmentChange()
    }

    private func invalidateNativeLayoutAfterEnvironmentChange() {
        let wasCollapsed = isCollapsed
        menuBarEngine.invalidateLayout()
        if wasCollapsed && !isCollapsed {
            didFailToCollapseMenuBar()
            autoCollapseCoordinator.didInvalidateLayoutToExpanded()
        }
        if wasCollapsed && Preferences.areSeparatorsHidden {
            menuBarEngine.updateAlwaysHiddenSection(enabled: Preferences.alwaysHiddenSectionEnabled, separatorHidden: true)
        }
    }

    private func restoreRemovedStatusItems() {
        // Cmd-dragging a status item off the bar is persisted by macOS via
        // autosaveName, leaving the app running but unreachable. These items are
        // the app's only UI, so they self-restore at launch.
        btnExpandCollapse.isVisible = true
        btnSeparate.isVisible = true
        // Create the engine now so one that does not use the separator (macOS 27
        // native hiding) takes it back out before it is ever drawn.
        _ = menuBarEngine
    }

    private func setupUI() {
        if let button = btnSeparate.button {
            button.image = self.imgIconLine
            button.target = self
            button.action = #selector(self.showContextMenuFromSeparator(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
            button.target = self

            button.action = #selector(self.btnExpandCollapsePressed(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        btnExpandCollapse.autosaveName = "hiddenbar_expandcollapse";
        btnSeparate.autosaveName = "hiddenbar_separate";
    }

    @objc func btnExpandCollapsePressed(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        // AXPress synthesis carries no NSEvent; the resolver maps nil to .toggle
        // so VoiceOver can operate the bar.
        let optionPressed = ExpandCollapseActionResolver.isOptionPressed(eventFlags: event?.modifierFlags, liveFlags: NSEvent.modifierFlags)
        switch ExpandCollapseActionResolver.action(eventType: event?.type, optionPressed: optionPressed) {
        case .toggle:
            self.expandCollapseIfNeeded()
        case .contextMenu:
            // Right-click opens the same context menu the separator has (#356),
            // making settings reachable from the control everyone clicks.
            // The separators/always-hidden toggle stays on option-click.
            showContextMenu(from: sender)
        case .toggleSeparators:
            // Both option+left and option+right land here: separators toggle.
            self.showHideSeparatorsAndAlwayHideArea()
        }
    }

    @objc private func showContextMenuFromSeparator(sender: NSStatusBarButton) {
        showContextMenu(from: sender)
    }

    // Builds a brand-new NSMenu for every presentation rather than mutating
    // a reused one via a delegate callback (content changes on an
    // already-displayed-before NSMenu instance could leave its backing
    // window at a stale size until an unrelated redraw corrected it).
    //
    // Uses popUp(at:), not performClick(nil): this method is ITSELF called
    // from this same button's own action handler (a real click already in
    // progress). performClick(nil) here re-entered NSStatusBarButtonCell's
    // own sendAction dispatch, recursing into this handler again and
    // stack-overflowing (SIGSEGV, confirmed via crash report) - unlike
    // NotchOverflowController.showOverflowMenuFromSeparator, which is safe
    // because it's invoked from a *different* control's action (a menu
    // item), not from btnExpandCollapse's own click handler.
    //
    // Previously anchored at `button.bounds.maxY + 5` (5pt above the
    // button's TOP edge). For a menu-bar item that's essentially the
    // physical top of the screen, so once "Show Notch Items" made the menu
    // one row taller, that top row landed in the sliver above the visible
    // screen and AppKit showed its standard "content doesn't fit here"
    // scroll-indicator caret instead of rendering it - hovering over the
    // indicator scrolled the whole menu into view, which is what looked
    // like the item "appearing on hover". Anchoring at the button's BOTTOM
    // edge instead (y: 0, not bounds.maxY) keeps the menu entirely within
    // on-screen space, growing downward from below the button.
    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = getContextMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
    }

    func showHideSeparatorsAndAlwayHideArea() {
        Preferences.areSeparatorsHidden ? self.showSeparators() : self.hideSeparators()

        if self.isCollapsed {self.expandMenubar()}
    }

    private func showSeparators() {
        Preferences.areSeparatorsHidden = false

        if !self.isCollapsed {
            menuBarEngine.expand()
        }
        menuBarEngine.updateAlwaysHiddenSection(enabled: Preferences.alwaysHiddenSectionEnabled, separatorHidden: false)
    }

    private func hideSeparators() {
        guard self.isBtnAlwaysHiddenValidPosition else {return}

        Preferences.areSeparatorsHidden = true

        if !self.isCollapsed {
            menuBarEngine.expand()
        }
        menuBarEngine.updateAlwaysHiddenSection(enabled: Preferences.alwaysHiddenSectionEnabled, separatorHidden: true)
    }

    func expandCollapseIfNeeded() {
        //prevented rapid click cause icon show many in Dock
        if isToggle {return}
        isToggle = true
        if self.isCollapsed {
            self.expandMenubar()
        } else {
            self.collapseMenuBar { [weak self] result in
                if result == .unavailable {
                    self?.autoCollapseCoordinator.handleUnavailable()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isToggle = false
        }
    }

    private func collapseMenuBar(completion: ((CollapseResult) -> Void)? = nil) {
        guard !self.isCollapsed else {
            autoCollapseCoordinator.didCollapse()
            completion?(.collapsed)
            return
        }
        guard menuBarEngine.isArrangementValid else {
            autoCollapseCoordinator.armIfNeeded()
            completion?(.unavailable)
            return
        }

        menuBarEngine.collapse { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .collapsed:
                self.didCollapseMenuBar()
                self.autoCollapseCoordinator.didCollapse()
            case .unavailable:
                self.didFailToCollapseMenuBar()
            }
            completion?(result)
        }
    }

    // Nothing was hidden (the engine cannot hide on this system, or is waiting for
    // a permission), so show the bar as expanded, and restore the activation
    // policy in case the UI had already switched to collapsed.
    private func didFailToCollapseMenuBar() {
        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
        }
        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func didCollapseMenuBar() {
        if let button = btnExpandCollapse.button {
            button.image = Assets.expandImage
        }
        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }
    }

    private func expandMenubar() {
        guard self.isCollapsed else {return}
        menuBarEngine.expand()
        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
        }
        autoCollapseCoordinator.didExpand()

        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

        }
    }

    // Expand/collapse skips the policy change when the option is off, so sync it on toggle.
    @objc private func syncActivationPolicyWithFullStatusBar() {
        let wantsRegular = Preferences.useFullStatusBarOnExpandEnabled && !isCollapsed
        let policy: NSApplication.ActivationPolicy = wantsRegular ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        let keyWindow = NSApp.isActive ? NSApp.keyWindow : nil
        NSApp.setActivationPolicy(policy)
        if wantsRegular {
            NSApp.activate(ignoringOtherApps: true)
        } else if let keyWindow {
            // Dropping to .accessory deactivates the app, so bring back the window in use.
            DispatchQueue.main.async { keyWindow.bringToFront() }
        }
    }

    @objc private func handleMenuDidBeginTracking() {
        activeMenuTrackingCount += 1
    }

    @objc private func handleMenuDidEndTracking() {
        activeMenuTrackingCount = max(0, activeMenuTrackingCount - 1)
        if activeMenuTrackingCount == 0 {
            DispatchQueue.main.async { [weak self] in
                self?.autoCollapseCoordinator.didBecomeIdleFromMenuOrPrefs()
            }
        }
    }

    @objc private func handleWindowWillClose() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.isPreferencesWindowVisible {
                self.autoCollapseCoordinator.didBecomeIdleFromMenuOrPrefs()
            }
        }
    }

    private func notifyAccessibilityPermissionNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted else {
                DispatchQueue.main.async {
                    self?.presentAccessibilityAlertFallback()
                }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Accessibility Permission Required".localized
            content.body = "Enable Hidden Bar in System Settings > Privacy & Security > Accessibility to auto-collapse menu bar icons.".localized
            let request = UNNotificationRequest(identifier: "com.mgabs.hiddenbar.accessibility", content: content, trigger: nil)
            center.add(request)
        }
    }

    private func presentAccessibilityAlertFallback() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Accessibility Permission Required".localized
        alert.informativeText = "Enable Hidden Bar in System Settings > Privacy & Security > Accessibility to auto-collapse menu bar icons.".localized
        alert.addButton(withTitle: "Open System Settings".localized)
        alert.addButton(withTitle: "OK".localized)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // Built fresh on every call (see showContextMenu(from:)), so every field
    // below reflects state as of THIS presentation - no separate "patch the
    // title after the fact" step is needed for the auto-collapse item.
    private func getContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Notch overflow menu item (only on notch Macs, and only when enabled)
        if NotchOverflowController.hasNotch && Preferences.notchOverflowEnabled {
            let overflowItem = NSMenuItem(title: "Show Notch Items".localized, action: #selector(showNotchOverflow), keyEquivalent: "")
            overflowItem.target = self
            menu.addItem(overflowItem)
            menu.addItem(NSMenuItem.separator())
        }

        let prefItem = NSMenuItem(title: "Preferences...".localized, action: #selector(openPreferenceViewControllerIfNeeded), keyEquivalent: "P")
        prefItem.target = self
        menu.addItem(prefItem)

        let toggleAutoHideTitle = Preferences.isAutoHide ? "Disable Auto Collapse" : "Enable Auto Collapse"
        let toggleAutoHideItem = NSMenuItem(title: toggleAutoHideTitle.localized, action: #selector(toggleAutoHide), keyEquivalent: "t")
        toggleAutoHideItem.target = self
        menu.addItem(toggleAutoHideItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc func updateAutoHide() {
        autoCollapseCoordinator.preferencesChanged()
    }

    @objc func openPreferenceViewControllerIfNeeded() {
        Util.showPrefWindow()
    }

    @objc func showNotchOverflow() {
        notchOverflowController.showOverflowMenuFromSeparator(near: btnExpandCollapse)
    }

    @objc func toggleAutoHide() {
        Preferences.isAutoHide.toggle()
    }
}


//MARK: - Alway hide feature
extension StatusBarController {
    private func setupAlwayHideStatusBar() {
        NotificationCenter.default.addObserver(self, selector: #selector(alwaysHiddenSectionToggled), name: .alwayHideToggle, object: nil)
        toggleStatusBarIfNeeded()
    }

    // Turning the section on shows its separator so it can be ⌘-dragged into
    // place; the saved "hide separators" state is reset to match, or the next
    // Option-click would only flip the preference and appear to do nothing.
    @objc private func alwaysHiddenSectionToggled() {
        if Preferences.alwaysHiddenSectionEnabled {
            Preferences.areSeparatorsHidden = false
        }
        toggleStatusBarIfNeeded()
    }

    private func toggleStatusBarIfNeeded() {
        if Preferences.alwaysHiddenSectionEnabled {
            if let existing = self.btnAlwaysHidden {
                NSStatusBar.system.removeStatusItem(existing)
            }
            self.btnAlwaysHidden = NSStatusBar.system.statusItem(withLength: 0)
            if let button = btnAlwaysHidden?.button {
                button.image = self.imgIconLine
                button.appearsDisabled = true
            }
            self.btnAlwaysHidden?.autosaveName = "hiddenbar_terminate"
            self.btnAlwaysHidden?.isVisible = true
            // Last, so the engine decides whether the new item stays in the bar.
            menuBarEngine.updateAlwaysHiddenSection(enabled: true, separatorHidden: false)
        } else {
            if let existing = self.btnAlwaysHidden {
                NSStatusBar.system.removeStatusItem(existing)
            }
            self.btnAlwaysHidden = nil
        }
    }
}
