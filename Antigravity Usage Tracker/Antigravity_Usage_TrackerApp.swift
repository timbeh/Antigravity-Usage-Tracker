//
//  Antigravity_Usage_TrackerApp.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 01.05.26.
//

import SwiftUI

@main
struct Antigravity_Usage_TrackerApp: App {
    @StateObject private var quotaManager: QuotaManager
    private let menuBarManager: MenuBarManager
    
    init() {
        let qm = QuotaManager()
        self._quotaManager = StateObject(wrappedValue: qm)
        self.menuBarManager = MenuBarManager(quotaManager: qm)
    }

    var body: some Scene {
        Settings {
            SettingsView(quotaManager: quotaManager)
        }
    }
}
