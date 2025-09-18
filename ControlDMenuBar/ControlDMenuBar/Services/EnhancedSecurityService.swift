import Foundation
import LocalAuthentication
import Security
import Combine

/// Enhanced security service with biometric authentication and audit logging
class EnhancedSecurityService: ObservableObject {
    static let shared = EnhancedSecurityService()
    
    @Published var isBiometricAvailable = false
    @Published var biometricType: LABiometryType = .none
    @Published var isAuthenticated = false
    @Published var auditLog: [AuditLogEntry] = []
    @Published var securityLevel: SecurityLevel = .standard
    
    private let context = LAContext()
    private let userDefaults = UserDefaults.standard
    private let auditLogKey = "ControlDAuditLog"
    private let maxAuditEntries = 1000
    
    private init() {
        checkBiometricAvailability()
        loadAuditLog()
        setupSecurityMonitoring()
    }
    
    // MARK: - Data Models
    
    enum SecurityLevel {
        case basic
        case standard
        case enhanced
        case maximum
        
        var description: String {
            switch self {
            case .basic:
                return "Basic"
            case .standard:
                return "Standard"
            case .enhanced:
                return "Enhanced"
            case .maximum:
                return "Maximum"
            }
        }
        
        var requiresBiometric: Bool {
            switch self {
            case .basic, .standard:
                return false
            case .enhanced, .maximum:
                return true
            }
        }
    }
    
    struct AuditLogEntry: Identifiable, Codable {
        let id = UUID()
        let timestamp: Date
        let action: SecurityAction
        let details: String
        let success: Bool
        let userAgent: String
        let ipAddress: String?
        
        enum SecurityAction: String, Codable {
            case login = "LOGIN"
            case logout = "LOGOUT"
            case apiKeyChanged = "API_KEY_CHANGED"
            case profileDisabled = "PROFILE_DISABLED"
            case profileEnabled = "PROFILE_ENABLED"
            case settingsChanged = "SETTINGS_CHANGED"
            case biometricAuth = "BIOMETRIC_AUTH"
            case securityLevelChanged = "SECURITY_LEVEL_CHANGED"
            case auditLogViewed = "AUDIT_LOG_VIEWED"
            case dataExported = "DATA_EXPORTED"
            case dataImported = "DATA_IMPORTED"
        }
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: timestamp)
        }
    }
    
    struct SecuritySettings: Codable {
        var requireBiometricForSettings: Bool = false
        var requireBiometricForProfileChanges: Bool = false
        var auditLoggingEnabled: Bool = true
        var sessionTimeout: TimeInterval = 1800 // 30 minutes
        var maxFailedAttempts: Int = 3
        var lockoutDuration: TimeInterval = 900 // 15 minutes
        var autoLogout: Bool = true
    }
    
    // MARK: - Biometric Authentication
    
    private func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            biometricType = context.biometryType
        } else {
            isBiometricAvailable = false
            biometricType = .none
        }
    }
    
    func authenticateWithBiometrics(reason: String = "Authenticate to access ControlD settings") async -> Bool {
        guard isBiometricAvailable else {
            logSecurityEvent(.biometricAuth, details: "Biometric authentication attempted but not available", success: false)
            return false
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            await MainActor.run {
                isAuthenticated = result
            }
            
            logSecurityEvent(.biometricAuth, details: "Biometric authentication \(result ? "succeeded" : "failed")", success: result)
            
            return result
            
        } catch {
            await MainActor.run {
                isAuthenticated = false
            }
            
            logSecurityEvent(.biometricAuth, details: "Biometric authentication error: \(error.localizedDescription)", success: false)
            
            return false
        }
    }
    
    func authenticateWithPasscode(reason: String = "Enter your passcode to continue") async -> Bool {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                let result = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )
                
                await MainActor.run {
                    isAuthenticated = result
                }
                
                logSecurityEvent(.biometricAuth, details: "Passcode authentication \(result ? "succeeded" : "failed")", success: result)
                
                return result
                
            } catch {
                await MainActor.run {
                    isAuthenticated = false
                }
                
                logSecurityEvent(.biometricAuth, details: "Passcode authentication error: \(error.localizedDescription)", success: false)
                
                return false
            }
        }
        
        return false
    }
    
    // MARK: - Security Level Management
    
    func setSecurityLevel(_ level: SecurityLevel) {
        let previousLevel = securityLevel
        securityLevel = level
        
        logSecurityEvent(.securityLevelChanged, details: "Security level changed from \(previousLevel.description) to \(level.description)", success: true)
        
        // Apply security level settings
        applySecurityLevelSettings(level)
    }
    
    private func applySecurityLevelSettings(_ level: SecurityLevel) {
        var settings = getSecuritySettings()
        
        switch level {
        case .basic:
            settings.requireBiometricForSettings = false
            settings.requireBiometricForProfileChanges = false
            settings.sessionTimeout = 3600 // 1 hour
            
        case .standard:
            settings.requireBiometricForSettings = false
            settings.requireBiometricForProfileChanges = false
            settings.sessionTimeout = 1800 // 30 minutes
            
        case .enhanced:
            settings.requireBiometricForSettings = true
            settings.requireBiometricForProfileChanges = true
            settings.sessionTimeout = 900 // 15 minutes
            
        case .maximum:
            settings.requireBiometricForSettings = true
            settings.requireBiometricForProfileChanges = true
            settings.sessionTimeout = 300 // 5 minutes
            settings.maxFailedAttempts = 2
            settings.lockoutDuration = 1800 // 30 minutes
        }
        
        saveSecuritySettings(settings)
    }
    
    // MARK: - Audit Logging
    
    func logSecurityEvent(_ action: AuditLogEntry.SecurityAction, details: String, success: Bool) {
        let entry = AuditLogEntry(
            timestamp: Date(),
            action: action,
            details: details,
            success: success,
            userAgent: getUserAgent(),
            ipAddress: getLocalIPAddress()
        )
        
        await MainActor.run {
            auditLog.insert(entry, at: 0)
            
            // Limit audit log size
            if auditLog.count > maxAuditEntries {
                auditLog = Array(auditLog.prefix(maxAuditEntries))
            }
        }
        
        saveAuditLog()
        
        print("🔒 Security Event: \(action.rawValue) - \(details) (\(success ? "SUCCESS" : "FAILURE"))")
    }
    
    func getAuditLogForPeriod(_ period: AuditPeriod) -> [AuditLogEntry] {
        let now = Date()
        let calendar = Calendar.current
        
        let startDate: Date
        switch period {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .all:
            return auditLog
        }
        
        return auditLog.filter { $0.timestamp >= startDate }
    }
    
    enum AuditPeriod {
        case today, week, month, all
    }
    
    func exportAuditLog() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        
        var export = "ControlD Security Audit Log\n"
        export += "Generated: \(formatter.string(from: Date()))\n"
        export += "Total Entries: \(auditLog.count)\n\n"
        
        for entry in auditLog {
            export += "[\(entry.formattedTimestamp)] \(entry.action.rawValue): \(entry.details) (\(entry.success ? "SUCCESS" : "FAILURE"))\n"
        }
        
        logSecurityEvent(.dataExported, details: "Audit log exported", success: true)
        
        return export
    }
    
    // MARK: - Session Management
    
    private var sessionTimer: Timer?
    private var sessionStartTime: Date?
    
    func startSession() {
        sessionStartTime = Date()
        
        // Start session timeout timer
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: getSecuritySettings().sessionTimeout, repeats: false) { [weak self] _ in
            self?.endSession()
        }
        
        logSecurityEvent(.login, details: "User session started", success: true)
    }
    
    func endSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        await MainActor.run {
            isAuthenticated = false
        }
        
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            logSecurityEvent(.logout, details: "User session ended after \(formatDuration(duration))", success: true)
        }
        
        sessionStartTime = nil
    }
    
    func extendSession() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: getSecuritySettings().sessionTimeout, repeats: false) { [weak self] _ in
            self?.endSession()
        }
    }
    
    // MARK: - Security Monitoring
    
    private func setupSecurityMonitoring() {
        // Monitor for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        // Check if session is still valid
        if let startTime = sessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > getSecuritySettings().sessionTimeout {
                endSession()
            }
        }
    }
    
    @objc private func appWillResignActive() {
        // Optionally end session when app becomes inactive
        if getSecuritySettings().autoLogout {
            endSession()
        }
    }
    
    // MARK: - Security Settings
    
    func getSecuritySettings() -> SecuritySettings {
        if let data = userDefaults.data(forKey: "ControlDSecuritySettings"),
           let settings = try? JSONDecoder().decode(SecuritySettings.self, from: data) {
            return settings
        }
        
        return SecuritySettings() // Default settings
    }
    
    func saveSecuritySettings(_ settings: SecuritySettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: "ControlDSecuritySettings")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getUserAgent() -> String {
        return "ControlD-MenuBar/1.0 (\(ProcessInfo.processInfo.operatingSystemVersionString))"
    }
    
    private func getLocalIPAddress() -> String? {
        // Get local IP address (simplified implementation)
        return "127.0.0.1" // In real implementation, get actual local IP
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
    
    private func saveAuditLog() {
        if let encoded = try? JSONEncoder().encode(auditLog) {
            userDefaults.set(encoded, forKey: auditLogKey)
        }
    }
    
    private func loadAuditLog() {
        if let data = userDefaults.data(forKey: auditLogKey),
           let log = try? JSONDecoder().decode([AuditLogEntry].self, from: data) {
            auditLog = log
        }
    }
    
    func clearAuditLog() {
        auditLog.removeAll()
        userDefaults.removeObject(forKey: auditLogKey)
        
        logSecurityEvent(.auditLogViewed, details: "Audit log cleared", success: true)
    }
    
    // MARK: - Security Recommendations
    
    func getSecurityRecommendations() -> [SecurityRecommendation] {
        var recommendations: [SecurityRecommendation] = []
        
        // Biometric recommendations
        if !isBiometricAvailable {
            recommendations.append(SecurityRecommendation(
                title: "Enable Biometric Authentication",
                description: "Add an extra layer of security with Touch ID or Face ID.",
                priority: .medium,
                action: "Enable Biometrics"
            ))
        }
        
        // Security level recommendations
        if securityLevel == .basic {
            recommendations.append(SecurityRecommendation(
                title: "Increase Security Level",
                description: "Consider upgrading to Standard or Enhanced security for better protection.",
                priority: .medium,
                action: "Upgrade Security"
            ))
        }
        
        // Session timeout recommendations
        let settings = getSecuritySettings()
        if settings.sessionTimeout > 1800 { // More than 30 minutes
            recommendations.append(SecurityRecommendation(
                title: "Reduce Session Timeout",
                description: "Consider reducing session timeout for better security.",
                priority: .low,
                action: "Adjust Timeout"
            ))
        }
        
        // Audit log recommendations
        if auditLog.count > 500 {
            recommendations.append(SecurityRecommendation(
                title: "Clean Audit Log",
                description: "Your audit log is getting large. Consider cleaning old entries.",
                priority: .low,
                action: "Clean Log"
            ))
        }
        
        return recommendations
    }
    
    struct SecurityRecommendation: Identifiable {
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
        sessionTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
