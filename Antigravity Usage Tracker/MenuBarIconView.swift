//
//  MenuBarIconView.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 04.05.26.
//

import SwiftUI

struct MenuBarIconView: View {
    let mode: MenuBarDisplayMode
    let quotaManager: QuotaManager
    
    var body: some View {
        switch mode {
        case .staticIcon:
            Image(systemName: quotaManager.menuBarIcon)
                .font(.system(size: 14, weight: .medium))
        case .modelCount:
            ModelCountView(quotaManager: quotaManager)
        case .donutCircle(let modelID):
            if let quota = quotaManager.modelQuotas.first(where: { $0.id == modelID }) {
                DonutCircleView(percentage: quota.percentage)
            } else {
                Image(systemName: "questionmark.circle")
            }
        case .progressBar(let modelID):
            if let quota = quotaManager.modelQuotas.first(where: { $0.id == modelID }) {
                MenuBarProgressBarView(quota: quota)
            } else {
                Image(systemName: "questionmark.square")
            }
        }
    }
}

struct ModelCountView: View {
    @ObservedObject var quotaManager: QuotaManager
    
    var body: some View {
        let total = quotaManager.modelQuotas.count
        let remaining = quotaManager.modelQuotas.filter { $0.percentage > 0 }.count
        
        HStack(spacing: 2) {
            Image(systemName: "cpu")
                .font(.system(size: 10))
            Text("\(remaining)/\(total)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
    }
}

struct DonutCircleView: View {
    let percentage: Int
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2.5)
                .frame(width: 18, height: 18)
            
            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100.0)
                .stroke(colorForPercentage(percentage), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(-90))
            
            Text("\(percentage)")
                .font(.system(size: 7, weight: .black))
        }
        .frame(width: 22, height: 22)
    }
    
    private func colorForPercentage(_ percentage: Int) -> Color {
        if percentage >= 50 { return .blue }
        if percentage >= 20 { return .orange }
        return .red
    }
}

struct MenuBarProgressBarView: View {
    let quota: ModelQuota
    
    var body: some View {
        VStack(spacing: 0) {
            // Quota Bar (Remaining Quota)
            let remainingPercentage = quota.percentage
            
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 38, height: 7)
                
                // Remaining Bar
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(colorForPercentage(remainingPercentage))
                    .frame(width: CGFloat(remainingPercentage) / 100.0 * 38, height: 7)
                
                // Reset Time Marker (The "Time Cursor")
                if let resetTime = quota.resetTime {
                    let timeProgress = calculateTimeProgress(resetTime: resetTime)
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 1.2, height: 11)
                        .offset(x: (CGFloat(timeProgress) * 38) - 0.6)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                }
            }
            .frame(height: 12)
            
            Text("\(remainingPercentage)%")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .opacity(0.8)
        }
        .frame(height: 22)
    }
    
    private func colorForPercentage(_ percentage: Int) -> Color {
        if percentage >= 50 { return .blue }
        if percentage >= 20 { return .orange }
        return .red
    }
    
    private func calculateTimeProgress(resetTime: Date) -> Double {
        let now = Date()
        if resetTime <= now { return 1.0 }
        
        // Assume 3-hour window for visualization if not known
        let windowSeconds: TimeInterval = 3 * 3600 
        let remaining = resetTime.timeIntervalSince(now)
        
        let progress = 1.0 - (remaining / windowSeconds)
        return max(0, min(1, progress))
    }
}
