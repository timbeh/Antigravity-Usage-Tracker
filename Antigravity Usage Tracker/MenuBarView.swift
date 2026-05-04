//
//  MenuBarView.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 01.05.26.
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var quotaManager: QuotaManager
    @State private var isHoveringSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Antigravity Usage")
                    .font(.headline)
                
                if quotaManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(height: 10)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                // Settings Icon in Top Right
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(isHoveringSettings ? .primary : .secondary)
                }
                .keyboardShortcut(",", modifiers: .command)
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringSettings = hovering
                }
                .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in
                    // 1. Close the popover immediately so it doesn't block other windows
                    NotificationCenter.default.post(name: NSNotification.Name("CloseMenuBarPopover"), object: nil)
                    
                    // 2. Force app activation and then request surfacing
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: NSNotification.Name("RequestSettingsSurface"), object: nil)
                })
                // Adds a little padding so the click target is easier to hit
                .padding(.trailing, 2)
            }
            Divider()
            
            if let error = quotaManager.errorMessage {
                HStack {
                    Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                    Text(error).font(.subheadline).foregroundColor(.secondary)
                }
                
                ScrollView {
                    Text(quotaManager.rawResponse)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(4)
                }
                .frame(height: 150)
                .background(Color.black.opacity(0.1))
                .cornerRadius(6)
                
            } else if quotaManager.modelQuotas.isEmpty {
                Text("No model quotas found.").font(.subheadline).foregroundColor(.secondary)
            } else {
                
                // MARK: - Quota Rendering Logic
                if quotaManager.isGroupingEnabled {
                    renderGroupedQuotas()
                } else {
                    ForEach(quotaManager.modelQuotas) { quota in
                        QuotaRowView(name: formatModelName(quota.name), percentage: quota.percentage, resetDate: quota.resetTime)
                    }
                }
                
                Text("Last updated: \(quotaManager.lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            
            Divider()
            
            // Footer Controls
            HStack {
                Button("Refresh") { Task { await quotaManager.fetchQuota() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                            
                Spacer()
                            
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    // MARK: - Rendering Helpers
    @ViewBuilder
    private func renderGroupedQuotas() -> some View {
        // Find all models that are inside ANY bucket (lowercased for safety)
        let groupedModelNames = Set(quotaManager.buckets.flatMap { bucket in
            bucket.models.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        })
            
        // 1. Render Defined Buckets
        ForEach(quotaManager.buckets) { bucket in
            // Make the search entirely case-insensitive
            if let matchedQuota = quotaManager.modelQuotas.first(where: { liveQuota in
                bucket.models.contains { targetModel in
                    targetModel.lowercased().trimmingCharacters(in: .whitespaces) == liveQuota.name.lowercased()
                }
            }) {
                QuotaRowView(name: bucket.name, percentage: matchedQuota.percentage, resetDate: matchedQuota.resetTime)
            }
        }
        
        // 2. Render Leftover (Ungrouped) Models
        let leftoverModels = quotaManager.modelQuotas.filter { liveQuota in
            !groupedModelNames.contains(liveQuota.name.lowercased())
        }
        
        if !leftoverModels.isEmpty {
            if !quotaManager.buckets.isEmpty { Divider().padding(.vertical, 4) }
            
            ForEach(leftoverModels) { quota in
                QuotaRowView(name: formatModelName(quota.name), percentage: quota.percentage, resetDate: quota.resetTime)
            }
        }
    }
    
    private func formatModelName(_ name: String) -> String {
        return name.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

struct QuotaRowView: View {
    let name: String
    let percentage: Int
    let resetDate: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.subheadline).fontWeight(.medium)
                Spacer()
                Text("\(percentage)%").bold().foregroundColor(colorForPercentage(percentage))
            }
            ProgressView(value: Double(percentage), total: 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: colorForPercentage(percentage)))
                .padding(.bottom, 2)
            
            if let resetDate = resetDate {
                Text(formatResetTime(resetDate)).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorForPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 50...100: return .green
        case 20..<50: return .orange
        default: return .red
        }
    }
    
    private func formatResetTime(_ date: Date) -> String {
        if date < Date() { return "Reset available" }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Resets at' h:mm a"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = "'Resets tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "'Resets' EEE 'at' h:mm a"
        }
        return formatter.string(from: date)
    }
}
