//
//  Antigravity_Usage_TrackerApp.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 01.05.26.
//

import SwiftUI

@main
struct Antigravity_Usage_TrackerApp: App {
    @StateObject private var quotaManager = QuotaManager()

    var body: some Scene {
        // "gauge.with.dots.needle.bottom.50percent" gives us a nice meter icon
        MenuBarExtra("Antigravity Quota", systemImage: quotaManager.menuBarIcon) {
            MenuBarView(quotaManager: quotaManager)
        }
        .menuBarExtraStyle(.window) // Allows for a custom popover instead of a standard list menu
    }
}
