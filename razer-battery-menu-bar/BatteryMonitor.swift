//
//  BatteryMonitor.swift
//  razer-battery-menu-bar
//
//  Created by Alex Perathoner on 26/11/24.
//

import Foundation
import UserNotifications
import Cocoa

class BatteryMonitor {
    // nil means "no reading yet / last read failed" - distinct from a real percentage,
    // so a failed read can never be displayed as a confident 100%.
    private(set) var batteryLevel: Int?
    private(set) var errorMessage = ""
    private(set) var isCharging: Bool?
    private var sentNotification: Bool = false

    /// Called on the main thread after every reading. The UI layer is plain AppKit,
    /// so there is no SwiftUI observation to lean on.
    var onChange: (() -> Void)?

    private var timer: Timer?
    private var isReading = false
    private var lastReadAt: Date?
    /// A read walks the whole USB device tree and opens every Razer peripheral, so
    /// reopening the menu repeatedly should not trigger one enumeration per open.
    private let minimumReadInterval: TimeInterval = 15
    // An LSUIElement app is eligible for App Nap, which defers the poll timer
    // indefinitely while the app sits idle in the background.
    private var activity: NSObjectProtocol?

    init() {
        activity = ProcessInfo.processInfo.beginActivity(
            options: .background,
            reason: "Polling Razer mouse battery"
        )
        startMonitoringBattery()
        requestNotificationAuthorization()
    }

    deinit {
        timer?.invalidate()
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
    }

    func startMonitoringBattery() {
        let timer = Timer(timeInterval: 120, repeats: true) { [weak self] _ in
            self?.updateBatteryLevel()
        }
        timer.tolerance = 10
        // .common so the timer keeps firing while the menu bar menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        updateBatteryLevel()
    }

    /// - Parameter force: bypass the debounce, for an explicit user-requested refresh.
    func updateBatteryLevel(force: Bool = false) {
        // USB I/O blocks - never run it on the main thread, and never overlap two reads.
        guard !isReading else { return }
        if !force, let lastReadAt, Date().timeIntervalSince(lastReadAt) < minimumReadInterval {
            return
        }
        isReading = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var charging: Int32 = -1
            let level = get_battery_status(&charging)

            DispatchQueue.main.async {
                guard let self else { return }
                self.isReading = false
                self.lastReadAt = Date()
                self.apply(level: level, charging: charging)
            }
        }
    }

    private func apply(level: Int32, charging: Int32) {
        defer { onChange?() }

        guard level != -1 else {
            // Surface the failure instead of leaving a stale value on screen.
            batteryLevel = nil
            isCharging = nil
            errorMessage = "Could not read the mouse battery. Is it connected and awake?"
            return
        }

        errorMessage = ""
        batteryLevel = Int(level)

        isCharging = (charging == -1) ? nil : (charging != 0)
        if isCharging == true {
            sentNotification = false
        }

        if level < 20 && isCharging != true && !sentNotification {
            sendLowBatteryNotification()
        }
    }

    func sendLowBatteryNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Battery is low"
        content.subtitle = "Razer Mouse battery is under 20%"
        content.sound = UNNotificationSound.defaultCritical
        content.interruptionLevel = .critical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
        self.sentNotification = true
    }

    func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]

        center.requestAuthorization(options: options) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    NSApplication.shared.registerForRemoteNotifications()
                    print("Registered for remote notifications")
                }
            } else {
                print("Notification authorization denied")
            }
        }
    }
}
