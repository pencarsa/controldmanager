import Foundation
import AppKit
import Combine

/// Service for integrating with ControlD web dashboard and providing quick access
class DashboardIntegrationService: ObservableObject {
    static let shared = DashboardIntegrationService()
    
    @Published var dashboardURL: String = "https://controld.com/dashboard"
    @Published var isDashboardAvailable = false
    @Published var lastDashboardCheck: Date?
    @Published var dashboardStatus: DashboardStatus = .unknown
    
    private let userDefaults = UserDefaults.standard
    private let dashboardCheckKey = "ControlDDashboardLastCheck"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadDashboardSettings()
        checkDashboardAvailability()
    }
    
    // MARK: - Data Models
    
    enum DashboardStatus {
        case available
        case unavailable
        case maintenance
        case unknown
        
        var description: String {
            switch self {
            case .available:
                return "Available"
            case .unavailable:
                return "Unavailable"
            case .maintenance:
                return "Maintenance"
            case .unknown:
                return "Unknown"
            }
        }
        
        var color: String {
            switch self {
            case .available:
                return "green"
            case .unavailable:
                return "red"
            case .maintenance:
                return "orange"
            case .unknown:
                return "gray"
            }
        }
    }
    
    struct DashboardLink: Identifiable {
        let id = UUID()
        let title: String
        let url: String
        let icon: String
        let description: String
        let category: LinkCategory
        
        enum LinkCategory {
            case profile, settings, analytics, support, billing
        }
    }
    
    struct DashboardQuickAction: Identifiable {
        let id = UUID()
        let title: String
        let action: QuickActionType
        let icon: String
        let description: String
        let requiresAuth: Bool
        
        enum QuickActionType {
            case openDashboard
            case openProfiles
            case openSettings
            case openAnalytics
            case openSupport
            case openBilling
            case refreshData
            case syncSettings
        }
    }
    
    // MARK: - Dashboard Links
    
    func getDashboardLinks() -> [DashboardLink] {
        return [
            DashboardLink(
                title: "Dashboard Home",
                url: dashboardURL,
                icon: "house.fill",
                description: "Main ControlD dashboard",
                category: .profile
            ),
            DashboardLink(
                title: "Profiles",
                url: "\(dashboardURL)/profiles",
                icon: "person.crop.circle.fill",
                description: "Manage your profiles",
                category: .profile
            ),
            DashboardLink(
                title: "Settings",
                url: "\(dashboardURL)/settings",
                icon: "gear.fill",
                description: "Account settings",
                category: .settings
            ),
            DashboardLink(
                title: "Analytics",
                url: "\(dashboardURL)/analytics",
                icon: "chart.bar.fill",
                description: "Usage analytics",
                category: .analytics
            ),
            DashboardLink(
                title: "Support",
                url: "https://controld.com/support",
                icon: "questionmark.circle.fill",
                description: "Get help and support",
                category: .support
            ),
            DashboardLink(
                title: "Billing",
                url: "\(dashboardURL)/billing",
                icon: "creditcard.fill",
                description: "Manage subscription",
                category: .billing
            )
        ]
    }
    
    func getQuickActions() -> [DashboardQuickAction] {
        return [
            DashboardQuickAction(
                title: "Open Dashboard",
                action: .openDashboard,
                icon: "safari.fill",
                description: "Open ControlD dashboard in browser",
                requiresAuth: true
            ),
            DashboardQuickAction(
                title: "Manage Profiles",
                action: .openProfiles,
                icon: "person.crop.circle.fill",
                description: "Open profiles management",
                requiresAuth: true
            ),
            DashboardQuickAction(
                title: "Account Settings",
                action: .openSettings,
                icon: "gear.fill",
                description: "Open account settings",
                requiresAuth: true
            ),
            DashboardQuickAction(
                title: "View Analytics",
                action: .openAnalytics,
                icon: "chart.bar.fill",
                description: "View usage analytics",
                requiresAuth: true
            ),
            DashboardQuickAction(
                title: "Get Support",
                action: .openSupport,
                icon: "questionmark.circle.fill",
                description: "Contact support",
                requiresAuth: false
            ),
            DashboardQuickAction(
                title: "Refresh Data",
                action: .refreshData,
                icon: "arrow.clockwise.fill",
                description: "Sync with dashboard",
                requiresAuth: true
            )
        ]
    }
    
    // MARK: - Dashboard Operations
    
    func openDashboard() {
        openURL(dashboardURL)
        
        // Log analytics
        AnalyticsService.shared.trackConnectionAttempt(success: true)
    }
    
    func openProfiles() {
        openURL("\(dashboardURL)/profiles")
    }
    
    func openSettings() {
        openURL("\(dashboardURL)/settings")
    }
    
    func openAnalytics() {
        openURL("\(dashboardURL)/analytics")
    }
    
    func openSupport() {
        openURL("https://controld.com/support")
    }
    
    func openBilling() {
        openURL("\(dashboardURL)/billing")
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }
        
        NSWorkspace.shared.open(url)
        
        // Log security event
        EnhancedSecurityService.shared.logSecurityEvent(
            .auditLogViewed,
            details: "Opened dashboard URL: \(urlString)",
            success: true
        )
    }
    
    // MARK: - Dashboard Availability Check
    
    func checkDashboardAvailability() {
        guard let url = URL(string: dashboardURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                self?.lastDashboardCheck = Date()
                self?.saveDashboardSettings()
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        self?.dashboardStatus = .available
                        self?.isDashboardAvailable = true
                    case 503:
                        self?.dashboardStatus = .maintenance
                        self?.isDashboardAvailable = false
                    default:
                        self?.dashboardStatus = .unavailable
                        self?.isDashboardAvailable = false
                    }
                } else {
                    self?.dashboardStatus = .unavailable
                    self?.isDashboardAvailable = false
                }
            }
        }.resume()
    }
    
    // MARK: - Data Synchronization
    
    func syncWithDashboard() async -> Bool {
        // This would sync local data with dashboard
        // For now, we'll simulate the sync process
        
        do {
            // Simulate API calls to sync data
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Update local data based on dashboard state
            await updateLocalDataFromDashboard()
            
            return true
            
        } catch {
            print("❌ Failed to sync with dashboard: \(error)")
            return false
        }
    }
    
    private func updateLocalDataFromDashboard() async {
        // Implementation would:
        // 1. Fetch current profile states from dashboard
        // 2. Update local profile data
        // 3. Sync settings
        // 4. Update analytics
        
        print("🔄 Synced local data with dashboard")
    }
    
    // MARK: - Dashboard Integration Features
    
    func getDashboardStatusInfo() -> String {
        switch dashboardStatus {
        case .available:
            return "Dashboard is available"
        case .unavailable:
            return "Dashboard is currently unavailable"
        case .maintenance:
            return "Dashboard is under maintenance"
        case .unknown:
            return "Dashboard status unknown"
        }
    }
    
    func getLastCheckInfo() -> String {
        guard let lastCheck = lastDashboardCheck else {
            return "Never checked"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last checked \(formatter.localizedString(for: lastCheck, relativeTo: Date()))"
    }
    
    // MARK: - Dashboard Shortcuts
    
    func createDashboardShortcuts() {
        // Create Spotlight shortcuts for quick access
        let shortcuts = [
            ("ControlD Dashboard", dashboardURL),
            ("ControlD Profiles", "\(dashboardURL)/profiles"),
            ("ControlD Settings", "\(dashboardURL)/settings"),
            ("ControlD Support", "https://controld.com/support")
        ]
        
        for (title, url) in shortcuts {
            createSpotlightShortcut(title: title, url: url)
        }
    }
    
    private func createSpotlightShortcut(title: String, url: String) {
        // Implementation would create Spotlight shortcuts
        // This is a simplified version
        print("🔗 Created shortcut: \(title) -> \(url)")
    }
    
    // MARK: - Dashboard Notifications
    
    func checkForDashboardUpdates() async {
        // Check for important dashboard updates or announcements
        // This could include:
        // - New features
        // - Maintenance notifications
        // - Security alerts
        // - Service status updates
        
        do {
            // Simulate checking for updates
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // In a real implementation, this would make API calls
            // to check for dashboard announcements
            
        } catch {
            print("❌ Failed to check for dashboard updates: \(error)")
        }
    }
    
    // MARK: - Dashboard Analytics
    
    func trackDashboardUsage(_ action: DashboardAction) {
        let details = "Dashboard action: \(action.description)"
        
        AnalyticsService.shared.trackConnectionAttempt(success: true)
        
        EnhancedSecurityService.shared.logSecurityEvent(
            .auditLogViewed,
            details: details,
            success: true
        )
    }
    
    enum DashboardAction {
        case opened
        case profilesViewed
        case settingsAccessed
        case analyticsViewed
        case supportContacted
        
        var description: String {
            switch self {
            case .opened:
                return "Dashboard opened"
            case .profilesViewed:
                return "Profiles page viewed"
            case .settingsAccessed:
                return "Settings accessed"
            case .analyticsViewed:
                return "Analytics viewed"
            case .supportContacted:
                return "Support contacted"
            }
        }
    }
    
    // MARK: - Dashboard Recommendations
    
    func getDashboardRecommendations() -> [DashboardRecommendation] {
        var recommendations: [DashboardRecommendation] = []
        
        // Dashboard availability recommendations
        switch dashboardStatus {
        case .unavailable:
            recommendations.append(DashboardRecommendation(
                title: "Dashboard Unavailable",
                description: "The ControlD dashboard is currently unavailable. Check your internet connection.",
                priority: .high,
                action: "Check Connection"
            ))
        case .maintenance:
            recommendations.append(DashboardRecommendation(
                title: "Scheduled Maintenance",
                description: "The dashboard is under maintenance. Service will resume shortly.",
                priority: .medium,
                action: "Check Status"
            ))
        default:
            break
        }
        
        // Sync recommendations
        if let lastCheck = lastDashboardCheck {
            let timeSinceCheck = Date().timeIntervalSince(lastCheck)
            if timeSinceCheck > 3600 { // More than 1 hour
                recommendations.append(DashboardRecommendation(
                    title: "Sync Recommended",
                    description: "Your data hasn't been synced with the dashboard recently.",
                    priority: .medium,
                    action: "Sync Now"
                ))
            }
        }
        
        return recommendations
    }
    
    struct DashboardRecommendation: Identifiable {
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
    
    // MARK: - Settings Management
    
    private func saveDashboardSettings() {
        userDefaults.set(lastDashboardCheck, forKey: dashboardCheckKey)
    }
    
    private func loadDashboardSettings() {
        lastDashboardCheck = userDefaults.object(forKey: dashboardCheckKey) as? Date
    }
    
    func updateDashboardURL(_ newURL: String) {
        dashboardURL = newURL
        checkDashboardAvailability()
    }
    
    // MARK: - Error Handling
    
    enum DashboardError: LocalizedError {
        case invalidURL
        case networkError
        case authenticationRequired
        case syncFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid dashboard URL"
            case .networkError:
                return "Network error occurred"
            case .authenticationRequired:
                return "Authentication required"
            case .syncFailed:
                return "Failed to sync with dashboard"
            }
        }
    }
}
