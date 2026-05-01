//
//  QuotaManager.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 01.05.26.
//

import Foundation
import Combine

// MARK: - JSON Models
struct QuotaResponse: Codable {
    let userStatus: UserStatus?
}
struct UserStatus: Codable {
    let cascadeModelConfigData: CascadeModelConfigData?
}
struct CascadeModelConfigData: Codable {
    let clientModelConfigs: [ClientModelConfig]?
}
struct ClientModelConfig: Codable {
    let label: String?
    let displayName: String?
    let quotaInfo: QuotaInfo?
}
struct QuotaInfo: Codable {
    let remainingFraction: Double?
    let resetTime: String?
}

// MARK: - UI Models
struct ModelQuota: Identifiable {
    let id: String
    let name: String
    let percentage: Int
    let resetTime: Date?
}

// MARK: - Quota Buckets
struct QuotaBucket: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var models: [String]
}

struct ServerConfig {
    let ports: [Int]
    let token: String
}

@MainActor
class QuotaManager: ObservableObject {
    @Published var modelQuotas: [ModelQuota] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date = Date()
    @Published var errorMessage: String? = nil
    
    // Debug info directly in the app
    @Published var rawResponse: String = "Initializing..."
    
    // MARK: - Grouping Settings
    @Published var isGroupingEnabled: Bool = false {
        didSet { UserDefaults.standard.set(isGroupingEnabled, forKey: "isGroupingEnabled") }
    }
    @Published var buckets: [QuotaBucket] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(buckets) {
                UserDefaults.standard.set(data, forKey: "savedBuckets")
            }
        }
    }
    
    var menuBarIcon: String {
        let lowestPercentage = modelQuotas.map { $0.percentage }.min() ?? 100
        switch lowestPercentage {
        case 50...100: return "gauge.with.dots.needle.bottom.50percent"
        case 20..<50: return "gauge.with.dots.needle.bottom.50percent.badge.minus"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    private var timer: Timer?
    
    init() {
        // Load Settings
        self.isGroupingEnabled = UserDefaults.standard.bool(forKey: "isGroupingEnabled")
            
        if let data = UserDefaults.standard.data(forKey: "savedBuckets"),
            let saved = try? JSONDecoder().decode([QuotaBucket].self, from: data) {
            self.buckets = saved
        } else {
            // First Launch Default Buckets
            self.buckets = [
                QuotaBucket(name: "Gemini 3.1 Pro", models:["Gemini 3.1 Pro (High)", "Gemini 3.1 Pro (Low)"]),
                QuotaBucket(name: "Claude Thinking & GPT 120B", models:["Claude Sonnet 4.6 (Thinking)", "Claude Opus 4.6 (Thinking)", "GPT-OSS 120B (Medium)"]),
                QuotaBucket(name: "Gemini 3 Flash", models: ["Gemini 3 Flash"])
            ]
        }
            
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { await self?.fetchQuota() }
        }
        Task { await fetchQuota() }
    }
    
    // MARK: - Core Fetch Logic
    func fetchQuota() async {
        isLoading = true
        errorMessage = nil
        rawResponse = "🔍 Scanning for language_server PID...\n"
        
        let serverInfo = await Task.detached { self.getProcessInfo() }.value
        
        guard let info = serverInfo else {
            self.errorMessage = "IDE Server Offline"
            self.rawResponse += "❌ Could not find language_server process or CSRF token."
            self.isLoading = false
            return
        }
        
        self.rawResponse += "✅ Found CSRF Token: \(info.token.prefix(6))...\n"
        self.rawResponse += "🔍 Found Ports: \(info.ports)\n\n"
        
        var fetchSuccess = false
        
        for port in info.ports {
            self.rawResponse += "➡️ Probing Port: \(port)...\n"
            
            let endpointString = "http://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/GetUserStatus"
            guard let url = URL(string: endpointString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            request.setValue(info.token, forHTTPHeaderField: "X-Codeium-Csrf-Token")
            
            let payload: [String: Any] = [
                "metadata":[
                    "ideName": "antigravity",
                    "extensionName": "antigravity",
                    "locale": "en"
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            request.timeoutInterval = 2.0
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                
                if let rawString = String(data: data, encoding: .utf8) {
                    if statusCode != 200 || !rawString.contains("userStatus") {
                        continue
                    }
                }
                
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(QuotaResponse.self, from: data)
                
                if let modelConfigs = decoded.userStatus?.cascadeModelConfigData?.clientModelConfigs {
                    var newQuotas:[ModelQuota] = []
                    
                    // NEW: Formatter to parse the ISO8601 string from Antigravity
                    let isoFormatter = ISO8601DateFormatter()
                    // Antigravity sometimes returns fractional seconds, so we handle that format
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let fallbackFormatter = ISO8601DateFormatter() // Fallback for standard ISO without fractions
                    
                    for model in modelConfigs {
                        let name = model.label ?? model.displayName ?? "Unknown Model"
                        if let fraction = model.quotaInfo?.remainingFraction, fraction >= 0 {
                            
                            var parsedDate: Date? = nil
                            if let timeString = model.quotaInfo?.resetTime {
                                parsedDate = isoFormatter.date(from: timeString) ?? fallbackFormatter.date(from: timeString)
                            }
                            
                            newQuotas.append(ModelQuota(id: name, name: name, percentage: Int(fraction * 100), resetTime: parsedDate))
                        }
                    }
                    
                    if !newQuotas.isEmpty {
                        self.modelQuotas = newQuotas.sorted { $0.percentage < $1.percentage }
                        self.lastUpdated = Date()
                        self.rawResponse += "\n✅ SUCCESS! Loaded \(newQuotas.count) models from port \(port)."
                        fetchSuccess = true
                        break
                    }
                }
                
            } catch {
                self.rawResponse += "Error on port \(port): \(error.localizedDescription)\n"
            }
        }
        
        if !fetchSuccess {
            self.errorMessage = "Failed to fetch data"
        }
        
        isLoading = false
    }
    
    // MARK: - Process Scanning (Direct Translation of repo logic)
    nonisolated private func getProcessInfo() -> ServerConfig? {
        let psProcess = Process()
        let psPipe = Pipe()
        
        // 1. ps aux | grep language_server | grep -v grep
        psProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
        psProcess.arguments = ["-c", "ps aux | grep language_server | grep -v grep"]
        psProcess.standardOutput = psPipe
        psProcess.standardError = FileHandle.nullDevice
        
        try? psProcess.run()
        psProcess.waitUntilExit()
        
        let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
        guard let psOutput = String(data: psData, encoding: .utf8), !psOutput.isEmpty else {
            return nil
        }
        
        let lines = psOutput.components(separatedBy: .newlines)
        guard let firstLine = lines.first(where: { !$0.isEmpty }) else { return nil }
        
        // Split by whitespace
        let components = firstLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if components.count < 2 { return nil }
        
        // PID is the second column in `ps aux`
        let pid = components[1]
        
        // Extract CSRF token
        var csrfToken: String? = nil
        let csrfRegex1 = try? NSRegularExpression(pattern: "--csrf_token\\s+([^\\s]+)")
        let csrfRegex2 = try? NSRegularExpression(pattern: "--csrf_token=([^\\s]+)")
        
        if let match = csrfRegex1?.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)),
           let range = Range(match.range(at: 1), in: firstLine) {
            csrfToken = String(firstLine[range])
        } else if let match = csrfRegex2?.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)),
                  let range = Range(match.range(at: 1), in: firstLine) {
            csrfToken = String(firstLine[range])
        }
        
        guard let token = csrfToken else { return nil }
        
        // 2. lsof -nP -a -p PID -iTCP -sTCP:LISTEN
        let lsofProcess = Process()
        let lsofPipe = Pipe()
        lsofProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
        lsofProcess.arguments = ["-c", "lsof -nP -a -p \(pid) -iTCP -sTCP:LISTEN"]
        lsofProcess.standardOutput = lsofPipe
        lsofProcess.standardError = FileHandle.nullDevice
        
        try? lsofProcess.run()
        lsofProcess.waitUntilExit()
        
        let lsofData = lsofPipe.fileHandleForReading.readDataToEndOfFile()
        guard let lsofOutput = String(data: lsofData, encoding: .utf8) else { return nil }
        
        var ports: [Int] = []
        let portRegex = try? NSRegularExpression(pattern: ":(\\d+)\\s+\\(LISTEN\\)")
        
        if let regex = portRegex {
            let matches = regex.matches(in: lsofOutput, range: NSRange(lsofOutput.startIndex..., in: lsofOutput))
            for match in matches {
                if let range = Range(match.range(at: 1), in: lsofOutput), let port = Int(lsofOutput[range]) {
                    ports.append(port)
                }
            }
        }
        
        // Remove duplicates
        let uniquePorts = Array(Set(ports))
        
        if uniquePorts.isEmpty { return nil }
        return ServerConfig(ports: uniquePorts, token: token)
    }
}
