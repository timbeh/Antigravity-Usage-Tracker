//
//  SettingsView.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 01.05.26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var quotaManager: QuotaManager
    @State private var newBucketName: String = ""
    
    var body: some View {
        TabView {
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
            }
            .padding()
            .tabItem {
                Label("Grouping", systemImage: "folder.fill")
            }
        }
        .frame(width: 480, height: 500)
    }
}
