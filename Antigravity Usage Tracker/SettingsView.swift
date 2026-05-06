//
//  SettingsView.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 01.05.26.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var quotaManager: QuotaManager
    @State private var newBucketName: String = ""
    
    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 20) {
                Text("General Settings")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Refresh Frequency")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Refresh Every", selection: $quotaManager.refreshInterval) {
                        Text("90 Seconds").tag(TimeInterval(90))
                        Text("5 Minutes").tag(TimeInterval(300))
                        Text("15 Minutes").tag(TimeInterval(900))
                        Text("30 Minutes").tag(TimeInterval(1800))
                        Text("1 Hour").tag(TimeInterval(3600))
                    }
                    .pickerStyle(.radioGroup)
                    .padding(.leading, 4)
                    
                    Text("How often the app checks for new quota data from your IDE.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Divider()
                
                HStack {
                    Text("Antigravity Usage Tracker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(30)
            .tabItem {
                Label("General", systemImage: "gear")
            }

            VStack(alignment: .leading, spacing: 16) {
                
                Toggle("Enable Quota Grouping", isOn: $quotaManager.isGroupingEnabled)
                    .font(.headline)
                
                Text("When enabled, models placed in the same bucket will display as a single progress bar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // The Live ID Cheat Sheet
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Model IDs (Copy & Paste these below):")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if quotaManager.modelQuotas.isEmpty {
                                Text("No models detected yet. Open your IDE first.")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            } else {
                                ForEach(quotaManager.modelQuotas) { quota in
                                    Text(quota.name)
                                        .font(.system(.caption2, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                        .textSelection(.enabled) // Allows user to highlight and copy
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
                
                Divider()
                
                // Edit Buckets List
                List {
                    ForEach($quotaManager.buckets) { $bucket in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Bucket Name (e.g. Gemini Pro)", text: $bucket.name)
                                .font(.headline)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            // Convert array of strings to a comma-separated string back and forth
                            TextField("Model IDs (comma separated)", text: Binding(
                                get: { bucket.models.joined(separator: ", ") },
                                set: { newValue in
                                    bucket.models = newValue.components(separatedBy: ",")
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                }
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { indexSet in
                        quotaManager.buckets.remove(atOffsets: indexSet)
                    }
                    .onMove { indices, newOffset in
                        quotaManager.buckets.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .listStyle(.bordered)
                
                // Add New Bucket
                HStack {
                    TextField("New bucket name...", text: $newBucketName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add Bucket") {
                        guard !newBucketName.isEmpty else { return }
                        let newBucket = QuotaBucket(name: newBucketName, models: [String]())
                        quotaManager.buckets.append(newBucket)
                        newBucketName = ""
                    }
                }
                
                Text("Drag to reorder • Swipe left to delete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding()
            .tabItem {
                Label("Grouping", systemImage: "folder.fill")
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Menu Bar Items")
                    .font(.headline)
                
                Text("Configure what information to show in your macOS menu bar. You can add multiple icons.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                List {
                    ForEach($quotaManager.menuBarItems) { $item in
                        MenuBarItemRow(item: $item, quotaManager: quotaManager)
                    }
                    .onDelete { indexSet in
                        quotaManager.menuBarItems.remove(atOffsets: indexSet)
                    }
                    .onMove { indices, newOffset in
                        quotaManager.menuBarItems.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .listStyle(.bordered)
                
                Button(action: {
                    quotaManager.menuBarItems.append(MenuBarItemConfiguration(mode: .staticIcon))
                }) {
                    Label("Add Item", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Text("Drag to reorder • Swipe left to delete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding()
            .tabItem {
                Label("Menu Bar", systemImage: "menubar.rectangle")
            }
        }
        .frame(width: 550, height: 500)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
            updateCollectionBehavior()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            handleWindowFocus(notification.object as? NSWindow)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            handleAppActivation()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RequestSettingsSurface"))) { _ in
            handleAppActivation()
        }
    }
    
    private func handleWindowFocus(_ window: NSWindow?) {
        guard let window = window else { return }
        let isSettings = window.title.contains("Settings") || 
                       window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
        
        if isSettings {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            repositionWindowIfNeeded(window)
        }
    }
    
    private func handleAppActivation() {
        // Multi-stage surfacing to ensure we win over any system-level window management
        for delay in [0.05, 0.2, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                for window in NSApp.windows {
                    // Search for window by title, identifier, or if it contains our view type
                    let looksLikeSettings = window.title.contains("Settings") || 
                                          window.identifier?.rawValue.contains("Settings") == true ||
                                          String(describing: window.contentView).contains("SettingsView")
                    
                    if window.isVisible && looksLikeSettings {
                        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                        window.orderFrontRegardless()
                        window.makeKeyAndOrderFront(nil)
                        repositionWindowIfNeeded(window)
                    }
                }
            }
        }
    }
    
    private func updateCollectionBehavior() {
        for window in NSApp.windows {
            if window.title.contains("Settings") || window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" {
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
        }
    }
    
    private func repositionWindowIfNeeded(_ window: NSWindow) {
        // Find the screen containing the mouse cursor (where the menu bar click happened)
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        guard let currentScreen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else { return }
        
        // Reposition to the center of the current screen
        let screenFrame = currentScreen.visibleFrame
        let windowFrame = window.frame
        
        let newX = screenFrame.midX - (windowFrame.width / 2)
        let newY = screenFrame.midY - (windowFrame.height / 2)
        
        window.setFrameOrigin(NSPoint(x: newX, y: newY))
        window.makeKeyAndOrderFront(nil)
    }
}

struct MenuBarItemRow: View {
    @Binding var item: MenuBarItemConfiguration
    @ObservedObject var quotaManager: QuotaManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Display Type", selection: Binding(
                get: { 
                    switch item.mode {
                    case .staticIcon: return 0
                    case .modelCount: return 1
                    case .donutCircle: return 2
                    case .progressBar: return 3
                    }
                },
                set: { newValue in
                    switch newValue {
                    case 0: item.mode = .staticIcon
                    case 1: item.mode = .modelCount
                    case 2: item.mode = .donutCircle(targetID: quotaManager.modelQuotas.first?.id ?? "", isBucket: false)
                    case 3: item.mode = .progressBar(targetID: quotaManager.modelQuotas.first?.id ?? "", isBucket: false)
                    default: break
                    }
                }
            )) {
                Text("Icon").tag(0)
                Text("Count").tag(1)
                Text("Donut").tag(2)
                Text("Bar").tag(3)
            }
            .pickerStyle(.segmented)
            
            if case .donutCircle(let targetID, let isBucket) = item.mode {
                TargetSelectionPicker(targetID: targetID, isBucket: isBucket, quotaManager: quotaManager) { newID, newIsBucket in
                    item.mode = .donutCircle(targetID: newID, isBucket: newIsBucket)
                }
            }
            
            if case .progressBar(let targetID, let isBucket) = item.mode {
                TargetSelectionPicker(targetID: targetID, isBucket: isBucket, quotaManager: quotaManager) { newID, newIsBucket in
                    item.mode = .progressBar(targetID: newID, isBucket: newIsBucket)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct TargetSelectionPicker: View {
    let targetID: String
    let isBucket: Bool
    @ObservedObject var quotaManager: QuotaManager
    let onUpdate: (String, Bool) -> Void
    
    var body: some View {
        HStack {
            Picker("Type", selection: Binding(
                get: { isBucket },
                set: { newValue in
                    let newID = newValue ? (quotaManager.buckets.first?.id.uuidString ?? "") : (quotaManager.modelQuotas.first?.id ?? "")
                    onUpdate(newID, newValue)
                }
            )) {
                Text("Model").tag(false)
                Text("Bucket").tag(true)
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .labelsHidden()
            
            Picker("Target", selection: Binding(
                get: { targetID },
                set: { onUpdate($0, isBucket) }
            )) {
                if isBucket {
                    if quotaManager.buckets.isEmpty {
                        Text("No buckets defined").tag("")
                    } else {
                        ForEach(quotaManager.buckets) { bucket in
                            Text(bucket.name).tag(bucket.id.uuidString)
                        }
                    }
                } else {
                    if quotaManager.modelQuotas.isEmpty {
                        Text("No models detected").tag("")
                    } else {
                        ForEach(quotaManager.modelQuotas) { quota in
                            Text(quota.name).tag(quota.id)
                        }
                    }
                }
            }
            .labelsHidden()
        }
        .controlSize(.small)
    }
}

