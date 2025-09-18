import Foundation
import Combine

/// Service for managing custom timer options and countdown functionality
class TimerService: ObservableObject {
    static let shared = TimerService()
    
    @Published var activeTimers: [String: TimerInfo] = [:]
    @Published var quickPresets: [TimerPreset] = []
    @Published var customDuration: TimeInterval = 3600 // Default 1 hour
    
    private var timer: Timer?
    private let userDefaults = UserDefaults.standard
    private let timerKey = "ControlDTimers"
    private let presetsKey = "ControlDPresets"
    
    private init() {
        loadQuickPresets()
        loadActiveTimers()
        startTimerUpdates()
    }
    
    // MARK: - Data Models
    
    struct TimerInfo: Codable, Identifiable {
        let id = UUID()
        let profileName: String
        let startTime: Date
        let duration: TimeInterval
        let expirationTime: Date
        var isActive: Bool = true
        
        var timeRemaining: TimeInterval {
            let now = Date()
            return max(0, expirationTime.timeIntervalSince(now))
        }
        
        var progress: Double {
            let elapsed = Date().timeIntervalSince(startTime)
            return min(1.0, elapsed / duration)
        }
        
        var formattedTimeRemaining: String {
            let remaining = timeRemaining
            let hours = Int(remaining) / 3600
            let minutes = Int(remaining) % 3600 / 60
            let seconds = Int(remaining) % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
    }
    
    struct TimerPreset: Codable, Identifiable {
        let id = UUID()
        let name: String
        let duration: TimeInterval
        let icon: String
        var isDefault: Bool = false
        
        var formattedDuration: String {
            let hours = Int(duration) / 3600
            let minutes = Int(duration) % 3600 / 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }
    
    // MARK: - Timer Management
    
    func startTimer(for profileName: String, duration: TimeInterval) {
        let timerInfo = TimerInfo(
            profileName: profileName,
            startTime: Date(),
            duration: duration,
            expirationTime: Date().addingTimeInterval(duration)
        )
        
        activeTimers[profileName] = timerInfo
        
        // Schedule notification
        NotificationService.shared.scheduleTimerExpirationNotification(
            profileName: profileName,
            expirationTime: timerInfo.expirationTime
        )
        
        // Track analytics
        AnalyticsService.shared.trackProfileDisable(profileName: profileName, duration: duration)
        
        saveActiveTimers()
        
        print("⏰ Timer started for '\(profileName)': \(formatDuration(duration))")
    }
    
    func stopTimer(for profileName: String) {
        guard let timerInfo = activeTimers[profileName] else { return }
        
        // Clear notification
        NotificationService.shared.clearNotifications(for: profileName)
        
        // Track analytics
        AnalyticsService.shared.trackProfileEnable(profileName: profileName)
        
        activeTimers.removeValue(forKey: profileName)
        saveActiveTimers()
        
        print("⏰ Timer stopped for '\(profileName)'")
    }
    
    func extendTimer(for profileName: String, additionalDuration: TimeInterval) {
        guard var timerInfo = activeTimers[profileName] else { return }
        
        timerInfo.expirationTime = timerInfo.expirationTime.addingTimeInterval(additionalDuration)
        activeTimers[profileName] = timerInfo
        
        // Reschedule notification
        NotificationService.shared.clearNotifications(for: profileName)
        NotificationService.shared.scheduleTimerExpirationNotification(
            profileName: profileName,
            expirationTime: timerInfo.expirationTime
        )
        
        saveActiveTimers()
        
        print("⏰ Timer extended for '\(profileName)': +\(formatDuration(additionalDuration))")
    }
    
    func getTimerInfo(for profileName: String) -> TimerInfo? {
        return activeTimers[profileName]
    }
    
    func isTimerActive(for profileName: String) -> Bool {
        return activeTimers[profileName]?.isActive ?? false
    }
    
    // MARK: - Quick Presets
    
    func loadQuickPresets() {
        if let data = userDefaults.data(forKey: presetsKey),
           let presets = try? JSONDecoder().decode([TimerPreset].self, from: data) {
            quickPresets = presets
        } else {
            // Create default presets
            createDefaultPresets()
        }
    }
    
    private func createDefaultPresets() {
        quickPresets = [
            TimerPreset(name: "Quick Break", duration: 900, icon: "cup.and.saucer", isDefault: true), // 15 min
            TimerPreset(name: "Short Focus", duration: 1800, icon: "timer", isDefault: true), // 30 min
            TimerPreset(name: "Work Session", duration: 3600, icon: "clock", isDefault: true), // 1 hour
            TimerPreset(name: "Long Session", duration: 7200, icon: "clock.badge", isDefault: true), // 2 hours
            TimerPreset(name: "Extended", duration: 14400, icon: "clock.badge.checkmark", isDefault: true) // 4 hours
        ]
        saveQuickPresets()
    }
    
    func addCustomPreset(name: String, duration: TimeInterval, icon: String) {
        let preset = TimerPreset(name: name, duration: duration, icon: icon)
        quickPresets.append(preset)
        saveQuickPresets()
    }
    
    func removePreset(_ preset: TimerPreset) {
        quickPresets.removeAll { $0.id == preset.id }
        saveQuickPresets()
    }
    
    func setDefaultPreset(_ preset: TimerPreset) {
        // Remove default from all presets
        for i in quickPresets.indices {
            quickPresets[i].isDefault = false
        }
        
        // Set new default
        if let index = quickPresets.firstIndex(where: { $0.id == preset.id }) {
            quickPresets[index].isDefault = true
        }
        
        saveQuickPresets()
    }
    
    private func saveQuickPresets() {
        if let encoded = try? JSONEncoder().encode(quickPresets) {
            userDefaults.set(encoded, forKey: presetsKey)
        }
    }
    
    // MARK: - Timer Updates
    
    private func startTimerUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimers()
        }
    }
    
    private func updateTimers() {
        let now = Date()
        var expiredTimers: [String] = []
        
        for (profileName, timerInfo) in activeTimers {
            if timerInfo.expirationTime <= now {
                expiredTimers.append(profileName)
            }
        }
        
        // Handle expired timers
        for profileName in expiredTimers {
            handleTimerExpiration(profileName: profileName)
        }
        
        // Update published property to trigger UI updates
        objectWillChange.send()
    }
    
    private func handleTimerExpiration(profileName: String) {
        guard let timerInfo = activeTimers[profileName] else { return }
        
        // Send notification
        NotificationService.shared.notifyProfileEnabled(profileName: profileName)
        
        // Track analytics
        AnalyticsService.shared.trackProfileEnable(profileName: profileName)
        
        // Remove timer
        activeTimers.removeValue(forKey: profileName)
        saveActiveTimers()
        
        print("⏰ Timer expired for '\(profileName)' - profile should be re-enabled")
    }
    
    // MARK: - Custom Duration
    
    func setCustomDuration(_ duration: TimeInterval) {
        customDuration = max(60, min(86400, duration)) // Between 1 minute and 24 hours
    }
    
    func incrementCustomDuration(by increment: TimeInterval) {
        setCustomDuration(customDuration + increment)
    }
    
    func decrementCustomDuration(by decrement: TimeInterval) {
        setCustomDuration(customDuration - decrement)
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    func getFormattedCustomDuration() -> String {
        return formatDuration(customDuration)
    }
    
    // MARK: - Persistence
    
    private func saveActiveTimers() {
        if let encoded = try? JSONEncoder().encode(activeTimers) {
            userDefaults.set(encoded, forKey: timerKey)
        }
    }
    
    private func loadActiveTimers() {
        guard let data = userDefaults.data(forKey: timerKey),
              let timers = try? JSONDecoder().decode([String: TimerInfo].self, from: data) else {
            return
        }
        
        // Filter out expired timers
        let now = Date()
        activeTimers = timers.filter { $0.value.expirationTime > now }
        
        // Reschedule notifications for active timers
        for (profileName, timerInfo) in activeTimers {
            NotificationService.shared.scheduleTimerExpirationNotification(
                profileName: profileName,
                expirationTime: timerInfo.expirationTime
            )
        }
    }
    
    func clearAllTimers() {
        activeTimers.removeAll()
        userDefaults.removeObject(forKey: timerKey)
        
        // Clear all notifications
        NotificationService.shared.clearAllNotifications()
    }
    
    deinit {
        timer?.invalidate()
    }
}
