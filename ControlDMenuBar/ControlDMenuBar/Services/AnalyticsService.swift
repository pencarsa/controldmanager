import Foundation
import Combine

/// Service for tracking usage analytics and insights
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    @Published var dailyStats: DailyStats = DailyStats()
    @Published var weeklyStats: WeeklyStats = WeeklyStats()
    @Published var profileUsageStats: [String: ProfileUsageStats] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let analyticsKey = "ControlDAnalytics"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadAnalytics()
        setupDailyReset()
    }
    
    // MARK: - Data Models
    
    struct DailyStats: Codable {
        var date: String = ""
        var totalDisables: Int = 0
        var totalEnables: Int = 0
        var totalDuration: TimeInterval = 0
        var averageDuration: TimeInterval = 0
        var mostUsedProfile: String = ""
        var connectionAttempts: Int = 0
        var successfulConnections: Int = 0
        var errorCount: Int = 0
        
        var connectionSuccessRate: Double {
            guard connectionAttempts > 0 else { return 0 }
            return Double(successfulConnections) / Double(connectionAttempts) * 100
        }
    }
    
    struct WeeklyStats: Codable {
        var weekStartDate: String = ""
        var totalDisables: Int = 0
        var totalEnables: Int = 0
        var totalDuration: TimeInterval = 0
        var averageDuration: TimeInterval = 0
        var mostActiveDay: String = ""
        var mostUsedProfile: String = ""
        var dailyBreakdown: [String: DailyStats] = [:]
        
        var averageDailyUsage: TimeInterval {
            guard !dailyBreakdown.isEmpty else { return 0 }
            return totalDuration / Double(dailyBreakdown.count)
        }
    }
    
    struct ProfileUsageStats: Codable {
        var profileName: String
        var totalDisables: Int = 0
        var totalEnables: Int = 0
        var totalDuration: TimeInterval = 0
        var averageDuration: TimeInterval = 0
        var lastUsed: Date?
        var favoriteDuration: TimeInterval = 0
        var usageFrequency: Int = 0
        
        var usageScore: Double {
            // Calculate usage score based on frequency and duration
            let frequencyScore = Double(usageFrequency) * 0.3
            let durationScore = (totalDuration / 3600) * 0.7 // Convert to hours
            return frequencyScore + durationScore
        }
    }
    
    struct UsageInsight: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let type: InsightType
        let actionable: Bool
        let actionTitle: String?
        
        enum InsightType {
            case efficiency, pattern, recommendation, warning
        }
    }
    
    // MARK: - Event Tracking
    
    func trackProfileDisable(profileName: String, duration: TimeInterval) {
        let today = getCurrentDateString()
        
        // Update daily stats
        if dailyStats.date != today {
            resetDailyStats()
        }
        
        dailyStats.totalDisables += 1
        dailyStats.totalDuration += duration
        
        // Update profile stats
        updateProfileStats(profileName: profileName, duration: duration, action: .disable)
        
        // Update weekly stats
        updateWeeklyStats()
        
        saveAnalytics()
        
        print("📊 Analytics: Profile '\(profileName)' disabled for \(formatDuration(duration))")
    }
    
    func trackProfileEnable(profileName: String) {
        let today = getCurrentDateString()
        
        // Update daily stats
        if dailyStats.date != today {
            resetDailyStats()
        }
        
        dailyStats.totalEnables += 1
        
        // Update profile stats
        updateProfileStats(profileName: profileName, duration: 0, action: .enable)
        
        // Update weekly stats
        updateWeeklyStats()
        
        saveAnalytics()
        
        print("📊 Analytics: Profile '\(profileName)' enabled")
    }
    
    func trackConnectionAttempt(success: Bool) {
        let today = getCurrentDateString()
        
        if dailyStats.date != today {
            resetDailyStats()
        }
        
        dailyStats.connectionAttempts += 1
        if success {
            dailyStats.successfulConnections += 1
        } else {
            dailyStats.errorCount += 1
        }
        
        saveAnalytics()
    }
    
    func trackError(_ error: Error, context: String) {
        let today = getCurrentDateString()
        
        if dailyStats.date != today {
            resetDailyStats()
        }
        
        dailyStats.errorCount += 1
        
        // Log error details for debugging
        print("📊 Analytics Error: \(context) - \(error.localizedDescription)")
        
        saveAnalytics()
    }
    
    // MARK: - Insights Generation
    
    func generateInsights() -> [UsageInsight] {
        var insights: [UsageInsight] = []
        
        // Efficiency insights
        if dailyStats.averageDuration > 0 {
            let avgHours = dailyStats.averageDuration / 3600
            if avgHours > 4 {
                insights.append(UsageInsight(
                    title: "Long Disable Sessions",
                    description: "You typically disable profiles for \(String(format: "%.1f", avgHours)) hours. Consider shorter sessions for better productivity.",
                    type: .efficiency,
                    actionable: true,
                    actionTitle: "Set Quick Presets"
                ))
            }
        }
        
        // Pattern insights
        if dailyStats.totalDisables > 5 {
            insights.append(UsageInsight(
                title: "Active User",
                description: "You've disabled profiles \(dailyStats.totalDisables) times today. You're making good use of ControlD!",
                type: .pattern,
                actionable: false,
                actionTitle: nil
            ))
        }
        
        // Connection insights
        if dailyStats.connectionSuccessRate < 90 && dailyStats.connectionAttempts > 3 {
            insights.append(UsageInsight(
                title: "Connection Issues",
                description: "Your connection success rate is \(String(format: "%.1f", dailyStats.connectionSuccessRate))%. Check your internet connection.",
                type: .warning,
                actionable: true,
                actionTitle: "Test Connection"
            ))
        }
        
        // Profile usage insights
        let sortedProfiles = profileUsageStats.values.sorted { $0.usageScore > $1.usageScore }
        if let mostUsed = sortedProfiles.first, mostUsed.usageScore > 10 {
            insights.append(UsageInsight(
                title: "Most Used Profile",
                description: "You use '\(mostUsed.profileName)' most frequently. Consider setting it as your default.",
                type: .recommendation,
                actionable: true,
                actionTitle: "Set as Default"
            ))
        }
        
        return insights
    }
    
    // MARK: - Helper Methods
    
    private enum ActionType {
        case disable, enable
    }
    
    private func updateProfileStats(profileName: String, duration: TimeInterval, action: ActionType) {
        if profileUsageStats[profileName] == nil {
            profileUsageStats[profileName] = ProfileUsageStats(profileName: profileName)
        }
        
        guard var stats = profileUsageStats[profileName] else { return }
        
        switch action {
        case .disable:
            stats.totalDisables += 1
            stats.totalDuration += duration
            stats.usageFrequency += 1
            stats.lastUsed = Date()
            
            // Update favorite duration (most common)
            if duration > stats.favoriteDuration {
                stats.favoriteDuration = duration
            }
            
        case .enable:
            stats.totalEnables += 1
        }
        
        stats.averageDuration = stats.totalDisables > 0 ? stats.totalDuration / Double(stats.totalDisables) : 0
        profileUsageStats[profileName] = stats
    }
    
    private func updateWeeklyStats() {
        let weekStart = getWeekStartDate()
        let weekStartString = DateFormatter.weekFormatter.string(from: weekStart)
        
        if weeklyStats.weekStartDate != weekStartString {
            resetWeeklyStats()
        }
        
        weeklyStats.totalDisables = dailyStats.totalDisables
        weeklyStats.totalEnables = dailyStats.totalEnables
        weeklyStats.totalDuration = dailyStats.totalDuration
        weeklyStats.averageDuration = dailyStats.averageDuration
        weeklyStats.dailyBreakdown[dailyStats.date] = dailyStats
        
        // Find most used profile
        let mostUsed = profileUsageStats.max { $0.value.usageScore < $1.value.usageScore }
        weeklyStats.mostUsedProfile = mostUsed?.key ?? ""
    }
    
    private func resetDailyStats() {
        dailyStats = DailyStats()
        dailyStats.date = getCurrentDateString()
    }
    
    private func resetWeeklyStats() {
        weeklyStats = WeeklyStats()
        weeklyStats.weekStartDate = DateFormatter.weekFormatter.string(from: getWeekStartDate())
    }
    
    private func getCurrentDateString() -> String {
        return DateFormatter.dateFormatter.string(from: Date())
    }
    
    private func getWeekStartDate() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2 // Monday = 2, Sunday = 1
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
    }
    
    private func setupDailyReset() {
        // Reset daily stats at midnight
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            let now = Date()
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            if hour == 0 && minute == 0 {
                self?.resetDailyStats()
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Persistence
    
    private func saveAnalytics() {
        let analyticsData = AnalyticsData(
            dailyStats: dailyStats,
            weeklyStats: weeklyStats,
            profileUsageStats: profileUsageStats
        )
        
        if let encoded = try? JSONEncoder().encode(analyticsData) {
            userDefaults.set(encoded, forKey: analyticsKey)
        }
    }
    
    private func loadAnalytics() {
        guard let data = userDefaults.data(forKey: analyticsKey),
              let analyticsData = try? JSONDecoder().decode(AnalyticsData.self, from: data) else {
            resetDailyStats()
            return
        }
        
        dailyStats = analyticsData.dailyStats
        weeklyStats = analyticsData.weeklyStats
        profileUsageStats = analyticsData.profileUsageStats
        
        // Reset if it's a new day
        if dailyStats.date != getCurrentDateString() {
            resetDailyStats()
        }
    }
    
    func clearAllAnalytics() {
        userDefaults.removeObject(forKey: analyticsKey)
        resetDailyStats()
        resetWeeklyStats()
        profileUsageStats.removeAll()
    }
}

// MARK: - Supporting Types

private struct AnalyticsData: Codable {
    let dailyStats: AnalyticsService.DailyStats
    let weeklyStats: AnalyticsService.WeeklyStats
    let profileUsageStats: [String: AnalyticsService.ProfileUsageStats]
}

extension DateFormatter {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-'W'ww"
        return formatter
    }()
}
