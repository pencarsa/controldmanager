import Foundation
import Combine
import AppKit

/// Service for background synchronization and automatic updates
class BackgroundSyncService: ObservableObject {
    static let shared = BackgroundSyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var connectionHealth: ConnectionHealth = .unknown
    
    private var syncTimer: Timer?
    private var healthCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private let healthCheckInterval: TimeInterval = 60 // 1 minute
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "ControlDLastSync"
    
    private init() {
        loadLastSyncTime()
        startBackgroundSync()
        startHealthMonitoring()
        setupSleepWakeNotifications()
    }
    
    // MARK: - Data Models
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(String)
        
        var description: String {
            switch self {
            case .idle:
                return "Ready"
            case .syncing:
                return "Syncing..."
            case .success:
                return "Synced"
            case .failed(let error):
                return "Sync failed: \(error)"
            }
        }
    }
    
    enum ConnectionHealth {
        case excellent
        case good
        case poor
        case offline
        case unknown
        
        var description: String {
            switch self {
            case .excellent:
                return "Excellent"
            case .good:
                return "Good"
            case .poor:
                return "Poor"
            case .offline:
                return "Offline"
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
            case .poor:
                return "orange"
            case .offline:
                return "red"
            case .unknown:
                return "gray"
            }
        }
    }
    
    struct SyncResult {
        let success: Bool
        let profilesUpdated: Int
        let errors: [String]
        let duration: TimeInterval
        let timestamp: Date
    }
    
    // MARK: - Background Sync
    
    private func startBackgroundSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performBackgroundSync()
            }
        }
        
        // Perform initial sync
        Task {
            await performBackgroundSync()
        }
    }
    
    func performBackgroundSync() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
        }
        
        let startTime = Date()
        var profilesUpdated = 0
        var errors: [String] = []
        
        do {
            // Sync profile statuses
            let profiles = try await syncProfileStatuses()
            profilesUpdated = profiles.count
            
            // Update connection health
            await updateConnectionHealth(success: true)
            
            await MainActor.run {
                syncStatus = .success
                lastSyncTime = Date()
                saveLastSyncTime()
            }
            
            print("🔄 Background sync completed: \(profilesUpdated) profiles updated")
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error.localizedDescription)
            }
            
            await updateConnectionHealth(success: false)
            errors.append(error.localizedDescription)
            
            print("❌ Background sync failed: \(error)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
        
        // Track analytics
        let result = SyncResult(
            success: errors.isEmpty,
            profilesUpdated: profilesUpdated,
            errors: errors,
            duration: Date().timeIntervalSince(startTime),
            timestamp: Date()
        )
        
        trackSyncResult(result)
    }
    
    private func syncProfileStatuses() async throws -> [ControlDService.Profile] {
        // This would integrate with your existing ControlDService
        // For now, we'll simulate the sync
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // In a real implementation, this would:
        // 1. Fetch current profile statuses from ControlD API
        // 2. Update local cache
        // 3. Notify UI of changes
        // 4. Handle timer synchronization
        
        return []
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() async {
        let startTime = Date()
        
        do {
            // Perform a quick API health check
            let isHealthy = try await checkAPIHealth()
            
            await MainActor.run {
                if isHealthy {
                    let responseTime = Date().timeIntervalSince(startTime)
                    if responseTime < 1.0 {
                        connectionHealth = .excellent
                    } else if responseTime < 3.0 {
                        connectionHealth = .good
                    } else {
                        connectionHealth = .poor
                    }
                } else {
                    connectionHealth = .offline
                }
            }
            
        } catch {
            await MainActor.run {
                connectionHealth = .offline
            }
            
            // Notify about connection issues
            NotificationService.shared.notifyConnectionLost()
        }
    }
    
    private func checkAPIHealth() async throws -> Bool {
        // Simulate API health check
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // In a real implementation, this would:
        // 1. Make a lightweight API call
        // 2. Check response time
        // 3. Validate response format
        
        return true // Simulate healthy connection
    }
    
    private func updateConnectionHealth(success: Bool) async {
        await MainActor.run {
            if success {
                if connectionHealth == .offline {
                    NotificationService.shared.notifyConnectionRestored()
                }
            } else {
                connectionHealth = .offline
            }
        }
    }
    
    // MARK: - Sleep/Wake Handling
    
    private func setupSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }
    
    @objc private func systemDidWake() {
        print("💤 System woke up - performing immediate sync")
        
        // Perform immediate sync after wake
        Task {
            await performBackgroundSync()
        }
    }
    
    @objc private func systemWillSleep() {
        print("💤 System going to sleep - stopping timers")
        
        // Stop timers to save battery
        syncTimer?.invalidate()
        healthCheckTimer?.invalidate()
        
        // Restart timers when system wakes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.startBackgroundSync()
            self.startHealthMonitoring()
        }
    }
    
    // MARK: - Manual Sync
    
    func forceSync() async {
        print("🔄 Manual sync requested")
        await performBackgroundSync()
    }
    
    func syncOnDemand() async -> SyncResult {
        let startTime = Date()
        var profilesUpdated = 0
        var errors: [String] = []
        var success = true
        
        do {
            let profiles = try await syncProfileStatuses()
            profilesUpdated = profiles.count
        } catch {
            success = false
            errors.append(error.localizedDescription)
        }
        
        let result = SyncResult(
            success: success,
            profilesUpdated: profilesUpdated,
            errors: errors,
            duration: Date().timeIntervalSince(startTime),
            timestamp: Date()
        )
        
        trackSyncResult(result)
        return result
    }
    
    // MARK: - Analytics Integration
    
    private func trackSyncResult(_ result: SyncResult) {
        AnalyticsService.shared.trackConnectionAttempt(success: result.success)
        
        if !result.success {
            for error in result.errors {
                AnalyticsService.shared.trackError(
                    NSError(domain: "BackgroundSync", code: -1, userInfo: [NSLocalizedDescriptionKey: error]),
                    context: "Background Sync"
                )
            }
        }
    }
    
    // MARK: - Configuration
    
    func updateSyncInterval(_ interval: TimeInterval) {
        syncTimer?.invalidate()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.performBackgroundSync()
            }
        }
    }
    
    func enableBackgroundSync(_ enabled: Bool) {
        if enabled {
            startBackgroundSync()
            startHealthMonitoring()
        } else {
            syncTimer?.invalidate()
            healthCheckTimer?.invalidate()
        }
    }
    
    // MARK: - Persistence
    
    private func saveLastSyncTime() {
        userDefaults.set(lastSyncTime, forKey: lastSyncKey)
    }
    
    private func loadLastSyncTime() {
        lastSyncTime = userDefaults.object(forKey: lastSyncKey) as? Date
    }
    
    // MARK: - Status Information
    
    func getSyncStatusInfo() -> String {
        guard let lastSync = lastSyncTime else {
            return "Never synced"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
    }
    
    func getConnectionHealthInfo() -> String {
        return "Connection: \(connectionHealth.description)"
    }
    
    deinit {
        syncTimer?.invalidate()
        healthCheckTimer?.invalidate()
        
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
