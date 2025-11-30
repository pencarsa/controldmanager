import Foundation
import Combine

/// Background refresh service for keeping data up-to-date
final class BackgroundRefreshService: ObservableObject {
    
    // MARK: - Refresh Configuration
    
    struct Configuration {
        let interval: TimeInterval
        let refreshOnAppear: Bool
        let refreshOnNetworkChange: Bool
        
        static let `default` = Configuration(
            interval: 60, // 1 minute
            refreshOnAppear: true,
            refreshOnNetworkChange: true
        )
        
        static let frequent = Configuration(
            interval: 30, // 30 seconds
            refreshOnAppear: true,
            refreshOnNetworkChange: true
        )
        
        static let infrequent = Configuration(
            interval: 300, // 5 minutes
            refreshOnAppear: false,
            refreshOnNetworkChange: false
        )
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var lastRefreshTime: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshError: Error?
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private var timer: Timer?
    private var networkMonitorCancellable: AnyCancellable?
    private let refreshHandler: () async throws -> Void
    
    // MARK: - Initialization
    
    init(
        configuration: Configuration = .default,
        refreshHandler: @escaping () async throws -> Void
    ) {
        self.configuration = configuration
        self.refreshHandler = refreshHandler
        
        setupAutoRefresh()
        setupNetworkMonitoring()
    }
    
    deinit {
        stopAutoRefresh()
        networkMonitorCancellable?.cancel()
    }
    
    // MARK: - Manual Refresh
    
    /// Manually trigger a refresh
    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        refreshError = nil
        
        do {
            try await refreshHandler()
            lastRefreshTime = Date()
        } catch {
            refreshError = error
        }
        
        isRefreshing = false
    }
    
    /// Force refresh (even if currently refreshing)
    @MainActor
    func forceRefresh() async {
        isRefreshing = true
        refreshError = nil
        
        do {
            try await refreshHandler()
            lastRefreshTime = Date()
        } catch {
            refreshError = error
        }
        
        isRefreshing = false
    }
    
    // MARK: - Auto Refresh
    
    private func setupAutoRefresh() {
        guard configuration.interval > 0 else { return }
        
        timer = Timer.scheduledTimer(
            withTimeInterval: configuration.interval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.refresh()
            }
        }
    }
    
    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Restart auto-refresh with new interval
    func updateRefreshInterval(_ interval: TimeInterval) {
        stopAutoRefresh()
        if interval > 0 {
            timer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: true
            ) { [weak self] _ in
                Task {
                    await self?.refresh()
                }
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        guard configuration.refreshOnNetworkChange else { return }
        
        networkMonitorCancellable = NetworkMonitor.shared.$status
            .dropFirst() // Skip initial value
            .filter { $0.isConnected }
            .sink { [weak self] _ in
                Task {
                    await self?.refresh()
                }
            }
    }
    
    // MARK: - State Management
    
    /// Pause auto-refresh
    func pause() {
        stopAutoRefresh()
    }
    
    /// Resume auto-refresh
    func resume() {
        setupAutoRefresh()
    }
    
    /// Check if data is stale
    func isDataStale(maxAge: TimeInterval = 60) -> Bool {
        guard let lastRefresh = lastRefreshTime else {
            return true
        }
        return Date().timeIntervalSince(lastRefresh) > maxAge
    }
}

// MARK: - App Lifecycle Integration

extension BackgroundRefreshService {
    /// Call when app becomes active
    func onAppBecameActive() {
        if configuration.refreshOnAppear {
            Task {
                await refresh()
            }
        }
    }
    
    /// Call when app will resign active
    func onAppWillResignActive() {
        // Optional: Could implement background task here
    }
}

