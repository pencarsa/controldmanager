import Foundation
import Network
import Combine

/// Monitor network connectivity status
final class NetworkMonitor: ObservableObject {
    
    // MARK: - Network Status
    
    enum Status {
        case connected(ConnectionType)
        case disconnected
        case unknown
        
        var isConnected: Bool {
            if case .connected = self {
                return true
            }
            return false
        }
    }
    
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case other
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var status: Status = .unknown
    @Published private(set) var isExpensive: Bool = false
    @Published private(set) var isConstrained: Bool = false
    
    // MARK: - Properties
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.controld.menubar.networkmonitor")
    private var isMonitoring = false
    
    // Singleton
    static let shared = NetworkMonitor()
    
    // MARK: - Initialization
    
    init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateStatus(path: path)
        }
        
        monitor.start(queue: queue)
        isMonitoring = true
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitor.cancel()
        isMonitoring = false
    }
    
    private func updateStatus(path: NWPath) {
        let newStatus: Status
        
        switch path.status {
        case .satisfied:
            newStatus = .connected(connectionType(from: path))
        case .unsatisfied, .requiresConnection:
            newStatus = .disconnected
        @unknown default:
            newStatus = .unknown
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.status = newStatus
            self?.isExpensive = path.isExpensive
            self?.isConstrained = path.isConstrained
        }
    }
    
    private func connectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .other
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Wait for network to become available
    func waitForConnection(timeout: TimeInterval = 30) async throws {
        guard !status.isConnected else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var timedOut = false
            
            // Set up timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if !timedOut {
                    timedOut = true
                    cancellable?.cancel()
                    continuation.resume(throwing: AppError.networkTimeout)
                }
            }
            
            // Wait for connection
            cancellable = $status
                .filter { $0.isConnected }
                .sink { _ in
                    if !timedOut {
                        timedOut = true
                        continuation.resume()
                    }
                }
        }
    }
}

