//
//  MenuBarView.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 01.05.26.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var quotaManager: QuotaManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Antigravity Usage")
                    .font(.headline)
                Spacer()
                if quotaManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(height: 10)
                }
            }
            
            Divider()
            
            if let error = quotaManager.errorMessage {
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                Text("No model quotas found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(quotaManager.modelQuotas) { quota in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(formatModelName(quota.name))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(quota.percentage)%")
                                .bold()
                                .foregroundColor(colorForPercentage(quota.percentage))
                        }
                        
                        ProgressView(value: Double(quota.percentage), total: 100.0)
                            .progressViewStyle(LinearProgressViewStyle(
                                tint: colorForPercentage(quota.percentage)
                            ))
                            .padding(.bottom, 2)
                        
                        // NEW: Show Reset Time
                        if let resetDate = quota.resetTime {
                            Text(formatResetTime(resetDate))
                                .font(.system(size: 10)) // Tiny font so it doesn't clutter
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Text("Last updated: \(quotaManager.lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            
            Divider()
            
            // Footer Controls
            HStack {
                Button("Refresh") {
                    Task { await quotaManager.fetchQuota() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    private func colorForPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 50...100: return .green
        case 20..<50: return .orange
        default: return .red
        }
    }
    
    private func formatModelName(_ name: String) -> String {
        return name.replacingOccurrences(of: "-", with: " ").capitalized
    }
    
    // NEW: Helper to format the Date into "Resets at 4:00 PM" or "Resets Tomorrow"
    private func formatResetTime(_ date: Date) -> String {
        // If the date has already passed, the server just hasn't generated a new one yet
        if date < Date() {
            return "Reset available"
        }
        
        let formatter = DateFormatter()
        
        // If the reset happens today, just show time. If it's a weekly reset, show day + time.
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Resets at' h:mm a"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = "'Resets tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "'Resets' EEE 'at' h:mm a" // e.g. "Resets Mon at 4:00 PM"
        }
        
        return formatter.string(from: date)
    }
}
