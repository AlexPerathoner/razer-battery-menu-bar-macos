//
//  razer_battery_menu_barApp.swift
//  razer-battery-menu-bar
//
//  Created by Alex Perathoner on 26/11/24.
//
//  AppKit status item rather than SwiftUI's MenuBarExtra: MenuBarExtra, ImageRenderer
//  and ImageRenderer.nsImage are all macOS 13+, and this app targets macOS 12.
//

import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let batteryMonitor = BatteryMonitor()
    private var statusItem: NSStatusItem?

    private let levelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let chargingItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let errorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    /// Composed icons keyed by battery bucket. There are only six distinct appearances,
    /// and resolving the symbol plus compositing it is pointless to repeat per render.
    private var iconCache: [String: NSImage] = [:]
    private var currentIconKey: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(levelItem)
        menu.addItem(chargingItem)
        menu.addItem(errorItem)
        menu.addItem(NSMenuItem(title: "Update", action: #selector(updateNow), keyEquivalent: "", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "By Alex Pera", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q", target: self))
        statusItem.menu = menu
        self.statusItem = statusItem

        batteryMonitor.onChange = { [weak self] in
            self?.render()
        }
        render()
    }

    /// Refresh whenever the menu is opened, so a reading is never more than a click stale.
    func menuWillOpen(_ menu: NSMenu) {
        // Paint current state first: if a read is already in flight, updateBatteryLevel()
        // returns immediately and would otherwise leave the menu unrepainted.
        render()
        batteryMonitor.updateBatteryLevel()
    }

    @objc private func updateNow() {
        // Explicit user request: always hit the hardware, debounce or not.
        batteryMonitor.updateBatteryLevel(force: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func render() {
        let level = batteryMonitor.batteryLevel

        levelItem.title = level.map { "\($0)%" } ?? "Battery unknown"

        if let isCharging = batteryMonitor.isCharging {
            chargingItem.title = isCharging ? "Charging" : "Discharging"
            chargingItem.isHidden = false
        } else {
            chargingItem.isHidden = true
        }

        errorItem.title = batteryMonitor.errorMessage
        errorItem.isHidden = batteryMonitor.errorMessage.isEmpty

        let names = symbolNames(for: level)
        let key = names.joined(separator: "|")
        if key != currentIconKey {
            let image = iconCache[key] ?? composedImage(names: names)
            iconCache[key] = image
            statusItem?.button?.image = image
            currentIconKey = key
        }
        statusItem?.button?.toolTip = levelItem.title
    }

    // MARK: - Icon

    /// SF Symbols 4 renamed the battery symbols. The `*percent` names do not exist before
    /// macOS 13, so each bucket falls back to its macOS 12 name.
    private func symbolNames(for level: Int?) -> [String] {
        // A missing reading is drawn the same as an empty battery.
        switch level ?? 0 {
        case 91...100: return ["battery.100percent", "battery.100"]
        case 71...90:  return ["battery.75percent", "battery.75"]
        case 46...70:  return ["battery.50percent", "battery.50", "battery.75"]
        case 21...45:  return ["battery.25percent", "battery.25"]
        default:       return ["battery.0percent", "battery.0"]
        }
    }

    private func symbolImage(names: [String]) -> NSImage? {
        for name in names {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                return image
            }
        }
        return nil
    }

    /// Draws the logo and the battery symbol side by side, replacing the SwiftUI
    /// ImageRenderer used before.
    private func composedImage(names: [String]) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let symbol = symbolImage(names: names)?.withSymbolConfiguration(config) else {
            return nil
        }

        let height: CGFloat = 16
        let spacing: CGFloat = 2

        // One source of truth for "is there a logo to draw, and how wide is it".
        let logo = NSImage(named: "Image")
        let logoWidth: CGFloat? = logo.flatMap { logo in
            logo.size.height > 0 ? logo.size.width * (height / logo.size.height) : nil
        }

        let symbolSize = symbol.size
        let symbolX = logoWidth.map { $0 + spacing } ?? 0
        let total = CGSize(width: symbolX + symbolSize.width, height: max(height, symbolSize.height))
        guard total.width > 0 else { return nil }

        let image = NSImage(size: total)
        image.lockFocus()
        if let logo, let logoWidth {
            logo.draw(in: NSRect(
                x: 0,
                y: (total.height - height) / 2,
                width: logoWidth,
                height: height
            ))
        }
        symbol.draw(in: NSRect(
            x: symbolX,
            y: (total.height - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        ))
        image.unlockFocus()
        // Template rendering lets the menu bar tint the icon for light/dark automatically,
        // replacing the hardcoded .colorScheme(.dark) the SwiftUI version needed.
        image.isTemplate = true
        return image
    }
}

private extension NSMenuItem {
    /// Menu items are useless without a target; setting it at construction keeps the two
    /// together instead of relying on a later pass over `menu.items`.
    convenience init(title: String, action: Selector?, keyEquivalent: String, target: AnyObject?) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}
