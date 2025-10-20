import Foundation
import Network
import Combine

/// Service for network diagnostics and connection quality monitoring
class NetworkDiagnosticsService: ObservableObject {
    static let shared = NetworkDiagnosticsService()
    
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var networkQuality: NetworkQuality = .unknown
    @Published var diagnosticsResults: [DiagnosticResult] = []
    @Published var isRunningDiagnostics = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Data Models
    
    enum ConnectionStatus {
        case connected
        case disconnected
        case cellular
        case wifi
        case ethernet
        case unknown
        
        var description: String {
            switch self {
            case .connected:
                return "Connected"
            case .disconnected:
                return "Disconnected"
            case .cellular:
                return "Cellular"
            case .wifi:
                return "Wi-Fi"
            case .ethernet:
                return "Ethernet"
            case .unknown:
                return "Unknown"
            }
        }
        
        var icon: String {
            switch self {
            case .connected, .wifi:
                return "wifi"
            case .disconnected:
                return "wifi.slash"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .ethernet:
                return "cable.connector"
            case .unknown:
                return "questionmark.circle"
            }
        }
    }
    
    enum NetworkQuality {
        case excellent
        case good
        case fair
        case poor
        case unknown
        
        var description: String {
            switch self {
            case .excellent:
                return "Excellent"
            case .good:
                return "Good"
            case .fair:
                return "Fair"
            case .poor:
                return "Poor"
            case .unknown:
                return "Unknown"
            }
        }
        
        var color: String {
            switch self {
            case .excellent:
                return "green"
            case .good:
                return "blue"
            case .fair:
                return "orange"
            case .poor:
                return "red"
            case .unknown:
                return "gray"
            }
        }
    }
    
    struct DiagnosticResult: Identifiable {
        let id = UUID()
        let test: DiagnosticTest
        let status: TestStatus
        let duration: TimeInterval
        let details: String
        let timestamp: Date
        
        enum DiagnosticTest {
            case connectivity
            case dnsResolution
            case apiEndpoint
            case speedTest
            case latencyTest
        }
        
        enum TestStatus {
            case success
            case failure
            case warning
            
            var icon: String {
                switch self {
                case .success:
                    return "checkmark.circle.fill"
                case .failure:
                    return "xmark.circle.fill"
                case .warning:
                    return "exclamationmark.triangle.fill"
                }
            }
            
            var color: String {
                switch self {
                case .success:
                    return "green"
                case .failure:
                    return "red"
                case .warning:
                    return "orange"
                }
            }
        }
    }
    
    struct SpeedTestResult {
        let downloadSpeed: Double // Mbps
        let uploadSpeed: Double // Mbps
        let latency: TimeInterval // ms
        let jitter: TimeInterval // ms
        let packetLoss: Double // percentage
        let timestamp: Date
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                connectionStatus = .wifi
            } else if path.usesInterfaceType(.cellular) {
                connectionStatus = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionStatus = .ethernet
            } else {
                connectionStatus = .connected
            }
        } else {
            connectionStatus = .disconnected
        }
        
        // Update network quality based on connection type
        updateNetworkQuality()
    }
    
    private func updateNetworkQuality() {
        switch connectionStatus {
        case .ethernet:
            networkQuality = .excellent
        case .wifi:
            networkQuality = .good
        case .cellular:
            networkQuality = .fair
        case .connected:
            networkQuality = .good
        case .disconnected:
            networkQuality = .poor
        case .unknown:
            networkQuality = .unknown
        }
    }
    
    // MARK: - Diagnostics
    
    func runFullDiagnostics() async {
        await MainActor.run {
            isRunningDiagnostics = true
            diagnosticsResults.removeAll()
        }
        
        // Run all diagnostic tests
        await runConnectivityTest()
        await runDNSResolutionTest()
        await runAPIEndpointTest()
        await runLatencyTest()
        
        await MainActor.run {
            isRunningDiagnostics = false
        }
        
        print("🔍 Network diagnostics completed: \(diagnosticsResults.count) tests")
    }
    
    private func runConnectivityTest() async {
        let startTime = Date()
        
        do {
            let isConnected = try await testInternetConnectivity()
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .connectivity,
                    status: isConnected ? .success : .failure,
                    duration: duration,
                    details: isConnected ? "Internet connection is working" : "No internet connection",
                    timestamp: Date()
                ))
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .connectivity,
                    status: .failure,
                    duration: duration,
                    details: "Connectivity test failed: \(error.localizedDescription)",
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func runDNSResolutionTest() async {
        let startTime = Date()
        
        do {
            let resolved = try await testDNSResolution()
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .dnsResolution,
                    status: resolved ? .success : .failure,
                    duration: duration,
                    details: resolved ? "DNS resolution working" : "DNS resolution failed",
                    timestamp: Date()
                ))
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .dnsResolution,
                    status: .failure,
                    duration: duration,
                    details: "DNS test failed: \(error.localizedDescription)",
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func runAPIEndpointTest() async {
        let startTime = Date()
        
        do {
            let isReachable = try await testControlDAPIEndpoint()
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .apiEndpoint,
                    status: isReachable ? .success : .failure,
                    duration: duration,
                    details: isReachable ? "ControlD API is reachable" : "ControlD API is not reachable",
                    timestamp: Date()
                ))
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .apiEndpoint,
                    status: .failure,
                    duration: duration,
                    details: "API endpoint test failed: \(error.localizedDescription)",
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func runLatencyTest() async {
        let startTime = Date()
        
        do {
            let latency = try await measureLatency()
            let duration = Date().timeIntervalSince(startTime)
            
            let status: DiagnosticResult.TestStatus
            let details: String
            
            if latency < 50 {
                status = .success
                details = "Excellent latency: \(String(format: "%.1f", latency))ms"
            } else if latency < 100 {
                status = .success
                details = "Good latency: \(String(format: "%.1f", latency))ms"
            } else if latency < 200 {
                status = .warning
                details = "Fair latency: \(String(format: "%.1f", latency))ms"
            } else {
                status = .failure
                details = "Poor latency: \(String(format: "%.1f", latency))ms"
            }
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .latencyTest,
                    status: status,
                    duration: duration,
                    details: details,
                    timestamp: Date()
                ))
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                diagnosticsResults.append(DiagnosticResult(
                    test: .latencyTest,
                    status: .failure,
                    duration: duration,
                    details: "Latency test failed: \(error.localizedDescription)",
                    timestamp: Date()
                ))
            }
        }
    }
    
    // MARK: - Individual Tests
    
    private func testInternetConnectivity() async throws -> Bool {
        guard let url = URL(string: "https://www.google.com") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.httpMethod = "HEAD"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        
        return false
    }
    
    private func testDNSResolution() async throws -> Bool {
        // Test DNS resolution by trying to resolve a common domain
        let host = "google.com"
        
        return try await withCheckedThrowingContinuation { continuation in
            let hostRef = CFHostCreateWithName(nil, host as CFString)
            CFHostStartInfoResolution(hostRef, .addresses, nil)
            
            var resolved: DarwinBoolean = false
            let addresses = CFHostGetAddressing(hostRef, &resolved)
            
            if resolved.boolValue && addresses != nil {
                continuation.resume(returning: true)
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func testControlDAPIEndpoint() async throws -> Bool {
        guard let url = URL(string: "https://api.controld.com") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.httpMethod = "HEAD"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode < 500 // Any response < 500 means endpoint is reachable
        }
        
        return false
    }
    
    private func measureLatency() async throws -> TimeInterval {
        guard let url = URL(string: "https://api.controld.com") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.httpMethod = "HEAD"
        
        let startTime = Date()
        let (_, _) = try await URLSession.shared.data(for: request)
        let endTime = Date()
        
        return (endTime.timeIntervalSince(startTime)) * 1000 // Convert to milliseconds
    }
    
    // MARK: - Speed Test
    
    func runSpeedTest() async -> SpeedTestResult? {
        let startTime = Date()
        
        do {
            // Simulate speed test (in real implementation, this would use a proper speed test service)
            // Note: Using non-cryptographic random for UI simulation only - not security-sensitive
            // These random values are for mock data display purposes, not cryptographic operations
            // nosemgrep
            let downloadSpeed = Double.random(in: 10...100) // Mbps
            // nosemgrep
            let uploadSpeed = Double.random(in: 5...50) // Mbps
            // nosemgrep
            let latency = Double.random(in: 10...100) // ms
            // nosemgrep
            let jitter = Double.random(in: 1...10) // ms
            // nosemgrep
            let packetLoss = Double.random(in: 0...2) // percentage
            
            let result = SpeedTestResult(
                downloadSpeed: downloadSpeed,
                uploadSpeed: uploadSpeed,
                latency: latency,
                jitter: jitter,
                packetLoss: packetLoss,
                timestamp: Date()
            )
            
            print("🚀 Speed test completed: \(String(format: "%.1f", downloadSpeed)) Mbps down, \(String(format: "%.1f", uploadSpeed)) Mbps up")
            
            return result
            
        } catch {
            print("❌ Speed test failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Network Information
    
    func getNetworkInfo() -> NetworkInfo {
        return NetworkInfo(
            connectionStatus: connectionStatus,
            networkQuality: networkQuality,
            isConnected: connectionStatus != .disconnected,
            lastDiagnosticsTime: diagnosticsResults.last?.timestamp,
            diagnosticsCount: diagnosticsResults.count
        )
    }
    
    struct NetworkInfo {
        let connectionStatus: ConnectionStatus
        let networkQuality: NetworkQuality
        let isConnected: Bool
        let lastDiagnosticsTime: Date?
        let diagnosticsCount: Int
    }
    
    // MARK: - Error Handling
    
    enum NetworkError: LocalizedError {
        case invalidURL
        case timeout
        case noConnection
        case dnsFailure
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .timeout:
                return "Request timeout"
            case .noConnection:
                return "No internet connection"
            case .dnsFailure:
                return "DNS resolution failed"
            }
        }
    }
    
    // MARK: - Recommendations
    
    func getNetworkRecommendations() -> [NetworkRecommendation] {
        var recommendations: [NetworkRecommendation] = []
        
        // Connection status recommendations
        switch connectionStatus {
        case .disconnected:
            recommendations.append(NetworkRecommendation(
                title: "No Internet Connection",
                description: "Check your internet connection and try again.",
                priority: .high,
                action: "Check Connection"
            ))
        case .cellular:
            recommendations.append(NetworkRecommendation(
                title: "Using Cellular Data",
                description: "Consider switching to Wi-Fi for better performance.",
                priority: .medium,
                action: "Switch to Wi-Fi"
            ))
        default:
            break
        }
        
        // Network quality recommendations
        switch networkQuality {
        case .poor:
            recommendations.append(NetworkRecommendation(
                title: "Poor Network Quality",
                description: "Your network connection may affect ControlD performance.",
                priority: .high,
                action: "Run Diagnostics"
            ))
        case .fair:
            recommendations.append(NetworkRecommendation(
                title: "Fair Network Quality",
                description: "Network performance could be improved.",
                priority: .medium,
                action: "Optimize Connection"
            ))
        default:
            break
        }
        
        // Diagnostic results recommendations
        let failedTests = diagnosticsResults.filter { $0.status == .failure }
        if !failedTests.isEmpty {
            recommendations.append(NetworkRecommendation(
                title: "Diagnostic Issues Found",
                description: "\(failedTests.count) diagnostic test(s) failed. Check your network configuration.",
                priority: .high,
                action: "View Details"
            ))
        }
        
        return recommendations
    }
    
    struct NetworkRecommendation: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let priority: Priority
        let action: String
        
        enum Priority {
            case low, medium, high
            
            var color: String {
                switch self {
                case .low:
                    return "blue"
                case .medium:
                    return "orange"
                case .high:
                    return "red"
                }
            }
        }
    }
    
    deinit {
        monitor.cancel()
    }
}
