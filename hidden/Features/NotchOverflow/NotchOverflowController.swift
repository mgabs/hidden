//
//  NotchOverflowController.swift
//  Hidden Bar
//
//  Created by Nadir on 2026/03/30.
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import AppKit
import ApplicationServices

// MARK: - Menu Bar Extra Info

struct MenuBarExtraInfo {
  let element: AXUIElement
  let appName: String
  let appIcon: NSImage?
  let title: String?
  let position: CGPoint
  let size: CGSize
}

// MARK: - Notch Geometry

/// Pure geometry: where the notch is and which X coordinates on the menu-bar
/// row it makes unreachable. Kept free of NSScreen/AppKit calls so it can be
/// unit-tested with synthetic screen values instead of live hardware.
struct NotchBoundary: Equatable {
  let hasNotch: Bool
  /// The leftmost X, in screen coordinates, at which a status item is
  /// guaranteed clear of the notch. Items positioned left of this are
  /// either under the notch or squeezed off past its left edge.
  let overflowThresholdX: CGFloat
}

enum NotchGeometry {
  // Matches the pre-fix behavior's default (half of a common 1728pt-wide
  // screen) so a screen that unexpectedly can't report safeAreaInsets still
  // gets a sane threshold instead of 0.
  static let fallbackThresholdX: CGFloat = 972

  /// - Parameters:
  ///   - screenFrame: the candidate screen's full frame (`NSScreen.frame`).
  ///   - safeAreaInsetsTop: `NSScreen.safeAreaInsets.top`; > 0 on notched Macs.
  ///   - auxiliaryTopRightAreaMinX: `NSScreen.auxiliaryTopRightArea?.minX`,
  ///     Apple's own safe-rect boundary for content right of the notch.
  static func computeBoundary(
    screenFrame: CGRect,
    safeAreaInsetsTop: CGFloat,
    auxiliaryTopRightAreaMinX: CGFloat?
  ) -> NotchBoundary {
    let hasNotch = safeAreaInsetsTop > 0
    guard hasNotch, let thresholdX = auxiliaryTopRightAreaMinX else {
      return NotchBoundary(hasNotch: hasNotch, overflowThresholdX: fallbackThresholdX)
    }
    return NotchBoundary(hasNotch: true, overflowThresholdX: thresholdX)
  }
}

// MARK: - Extras Classification

/// Pure classification of already-fetched extras against a boundary. Split
/// from AX enumeration so the sorting/filtering rules are testable without
/// a live Accessibility permission or other running apps.
enum MenuBarExtraClassifier {
  static func classify(
    _ extras: [MenuBarExtraInfo],
    boundary: CGFloat
  ) -> (hidden: [MenuBarExtraInfo], visible: [MenuBarExtraInfo]) {
    let renderable = extras.filter { $0.size.width > 0 && $0.size.height > 0 }
    let hidden = renderable
      .filter { $0.position.x < boundary }
      .sorted { $0.position.x > $1.position.x }
    let visible = renderable
      .filter { $0.position.x >= boundary }
      .sorted { $0.position.x > $1.position.x }
    return (hidden, visible)
  }
}

// MARK: - NotchOverflowController

class NotchOverflowController: NSObject {

  // MARK: - Notch Detection

  private static func currentBoundary() -> NotchBoundary {
    guard let screen = NSScreen.main else {
      return NotchBoundary(hasNotch: false, overflowThresholdX: NotchGeometry.fallbackThresholdX)
    }
    let safeAreaTop: CGFloat
    let auxRightMinX: CGFloat?
    if #available(macOS 12.0, *) {
      safeAreaTop = screen.safeAreaInsets.top
      auxRightMinX = screen.auxiliaryTopRightArea?.minX
    } else {
      safeAreaTop = 0
      auxRightMinX = nil
    }
    return NotchGeometry.computeBoundary(
      screenFrame: screen.frame,
      safeAreaInsetsTop: safeAreaTop,
      auxiliaryTopRightAreaMinX: auxRightMinX
    )
  }

  static var hasNotch: Bool {
    currentBoundary().hasNotch
  }

  /// Show overflow menu anchored to a status item (called from StatusBarController)
  func showOverflowMenuFromSeparator(near item: NSStatusItem) {
    guard ensureAccessibility() else { return }
    fetchMenuBarExtras { [weak self, weak item] extras in
      guard let self = self, let item = item else { return }
      let menu = self.buildOverflowMenu(extras: extras)
      item.menu = menu
      item.button?.performClick(nil)
      DispatchQueue.main.async {
        item.menu = nil
      }
    }
  }

  // MARK: - Menu Building

  func buildOverflowMenu(
    extras: [MenuBarExtraInfo]? = nil,
    boundary: CGFloat? = nil
  ) -> NSMenu {
    let allExtras = extras ?? getAllMenuBarExtras()
    let resolvedBoundary = boundary ?? Self.currentBoundary().overflowThresholdX
    let (hiddenExtras, visibleExtras) = MenuBarExtraClassifier.classify(allExtras, boundary: resolvedBoundary)

    let menu = NSMenu()
    menu.autoenablesItems = false

    // Title
    menu.addItem(makeSectionHeader(title: "Notch Overflow".localized, fontSize: 12))
    menu.addItem(NSMenuItem.separator())

    // Hidden section
    if !hiddenExtras.isEmpty {
      menu.addItem(makeSectionHeader(title: String(format: "Hidden Behind Notch (%d)".localized, hiddenExtras.count)))
      menu.addItem(NSMenuItem.separator())

      for info in hiddenExtras {
        menu.addItem(makeMenuItem(for: info, hidden: true))
      }
    }

    // Visible section
    if !visibleExtras.isEmpty {
      if !hiddenExtras.isEmpty { menu.addItem(NSMenuItem.separator()) }
      menu.addItem(makeSectionHeader(title: String(format: "Visible (%d)".localized, visibleExtras.count)))
      menu.addItem(NSMenuItem.separator())

      for info in visibleExtras {
        menu.addItem(makeMenuItem(for: info, hidden: false))
      }
    }

    // Empty state
    if hiddenExtras.isEmpty && visibleExtras.isEmpty {
      let emptyItem = NSMenuItem(
        title: "No items found (grant Accessibility permission)".localized,
        action: nil, keyEquivalent: "")
      emptyItem.isEnabled = false
      menu.addItem(emptyItem)
    }

    return menu
  }

  // Disabled, non-interactive label. Bold + labelColor (full contrast) rather
  // than secondaryLabelColor/AppKit's default disabled-item dimming, which
  // read poorly against a dark selection highlight.
  private func makeSectionHeader(title: String, fontSize: CGFloat = 13) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    item.attributedTitle = NSAttributedString(
      string: title,
      attributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.labelColor
      ])
    return item
  }

  private func makeMenuItem(for info: MenuBarExtraInfo, hidden: Bool = false) -> NSMenuItem {
    let item = NSMenuItem()
    let displayTitle = (info.title?.isEmpty == false) ? info.title! : info.appName

    if hidden {
      // Color alone isn't an accessible way to convey "hidden" (colorblind
      // users get nothing from it, and systemOrange reads poorly against a
      // dark selection highlight). A glyph + bold weight works in any theme.
      item.attributedTitle = NSAttributedString(
        string: "\u{26A0}\u{FE0F} \(displayTitle)",
        attributes: [
          .font: NSFont.boldSystemFont(ofSize: 13),
          .foregroundColor: NSColor.labelColor
        ])
    } else {
      item.title = displayTitle
    }

    if let icon = info.appIcon {
      item.image = hidden ? icon.resizedForMenu(tinted: true) : icon.resizedForMenu()
    }
    item.representedObject = info
    item.target = self
    item.action = #selector(activateItem(_:))
    return item
  }

  @objc private func activateItem(_ sender: NSMenuItem) {
    guard let info = sender.representedObject as? MenuBarExtraInfo else { return }
    AXUIElementPerformAction(info.element, kAXPressAction as CFString)
  }

  // MARK: - Accessibility

  private func ensureAccessibility() -> Bool {
    if AXIsProcessTrusted() { return true }
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(opts)
    return false
  }

  // MARK: - AX Enumeration

  private static let axMessagingTimeout: Float = 0.1

  private static func runningAppEntries() -> [(pid: pid_t, name: String, app: NSRunningApplication)] {
    let myPID = ProcessInfo.processInfo.processIdentifier
    return NSWorkspace.shared.runningApplications
      .filter { $0.processIdentifier != myPID && $0.bundleURL?.pathExtension == "app" }
      .map { (pid: $0.processIdentifier, name: $0.localizedName ?? "Unknown", app: $0) }
  }

  private func fetchMenuBarExtras(completion: @escaping ([MenuBarExtraInfo]) -> Void) {
    let apps = Self.runningAppEntries()
    DispatchQueue.global(qos: .userInitiated).async {
      let extras = Self.menuBarExtras(of: apps)
      DispatchQueue.main.async { completion(extras) }
    }
  }

  private func getAllMenuBarExtras() -> [MenuBarExtraInfo] {
    return Self.menuBarExtras(of: Self.runningAppEntries())
  }

  private static func menuBarExtras(
    of apps: [(pid: pid_t, name: String, app: NSRunningApplication)]
  ) -> [MenuBarExtraInfo] {
    var perApp = [[MenuBarExtraInfo]](repeating: [], count: apps.count)
    let lock = NSLock()
    DispatchQueue.concurrentPerform(iterations: apps.count) { index in
      let found = menuBarExtras(of: apps[index])
      lock.lock()
      perApp[index] = found
      lock.unlock()
    }
    return perApp.flatMap { $0 }
  }

  private static func menuBarExtras(
    of entry: (pid: pid_t, name: String, app: NSRunningApplication)
  ) -> [MenuBarExtraInfo] {
    let axApp = AXUIElementCreateApplication(entry.pid)
    AXUIElementSetMessagingTimeout(axApp, axMessagingTimeout)
    var extrasRef: AnyObject?
    guard AXUIElementCopyAttributeValue(axApp, "AXExtrasMenuBar" as CFString, &extrasRef) == .success,
          let extrasBar = extrasRef else { return [] }

    var childrenRef: AnyObject?
    guard AXUIElementCopyAttributeValue(
      extrasBar as! AXUIElement,
      kAXChildrenAttribute as CFString,
      &childrenRef
    ) == .success, let children = childrenRef as? [AXUIElement] else { return [] }

    var items: [MenuBarExtraInfo] = []
    var cachedIcon: NSImage??
    for child in children {
      var sizeRef: AnyObject?
      AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef)
      var size = CGSize.zero
      if let sv = sizeRef { AXValueGetValue(sv as! AXValue, .cgSize, &size) }
      guard size.width > 0, size.height > 0 else { continue }

      var titleRef: AnyObject?
      AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)

      var posRef: AnyObject?
      AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &posRef)
      var pos = CGPoint.zero
      if let pv = posRef { AXValueGetValue(pv as! AXValue, .cgPoint, &pos) }

      let icon = cachedIcon ?? {
        let loaded = entry.app.icon
        cachedIcon = loaded
        return loaded
      }()

      items.append(MenuBarExtraInfo(
        element: child,
        appName: entry.name,
        appIcon: icon,
        title: titleRef as? String,
        position: pos,
        size: size
      ))
    }
    return items
  }

}

// MARK: - NSImage Extension

private extension NSImage {
  func resizedForMenu(tinted: Bool = false) -> NSImage {
    let target = NSSize(width: 18, height: 18)
    return NSImage(size: target, flipped: false) { rect in
      self.draw(in: rect,
                from: NSRect(origin: .zero, size: self.size),
                operation: .sourceOver, fraction: tinted ? 0.5 : 1.0)
      return true
    }
  }
}
