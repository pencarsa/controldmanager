import Foundation
import os.log

/// Audit logger for security-sensitive operations
final class AuditLogger {
    
    // MARK: - Audit Event
    
    struct AuditEvent: Codable {
        let timestamp: Date
        let event: EventType
        let userId: String?
        let success: Bool
        let details: [String: String]
        let ipAddress: String?
        
        enum EventType: String, Codable {
            case apiKeyAdded = "API_KEY_ADDED"
            case apiKeyUpdated = "API_KEY_UPDATED"
            case apiKeyRemoved = "API_KEY_REMOVED"
            case apiKeyValidated = "API_KEY_VALIDATED"
            case profileSelected = "PROFILE_SELECTED"
            case profileDisabled = "PROFILE_DISABLED"
            case profileEnabled = "PROFILE_ENABLED"
            case settingsReset = "SETTINGS_RESET"
            case authenticationAttempt = "AUTHENTICATION_ATTEMPT"
            case authenticationSuccess = "AUTHENTICATION_SUCCESS"
            case authenticationFailure = "AUTHENTICATION_FAILURE"
            case unauthorizedAccess = "UNAUTHORIZED_ACCESS"
        }
    }
    
    // MARK: - Properties
    
    private let logger: Logger
    private let queue = DispatchQueue(label: "com.controld.menubar.audit", qos: .utility)
    private var events: [AuditEvent] = []
    private let maxEvents = 1000
    private let storageURL: URL?
    
    // Singleton
    static let shared = AuditLogger()
    
    // MARK: - Initialization
    
    init() {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.controld.menubar",
                            category: "Audit")
        
        // Set up storage
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let auditDir = appSupport.appendingPathComponent("ControlD/Audit")
            try? FileManager.default.createDirectory(at: auditDir, withIntermediateDirectories: true)
            self.storageURL = auditDir.appendingPathComponent("audit.log")
        } else {
            self.storageURL = nil
        }
        
        // Load existing events
        loadEvents()
    }
    
    // MARK: - Logging
    
    func log(
        event: AuditEvent.EventType,
        success: Bool,
        details: [String: String] = [:],
        userId: String? = nil
    ) {
        let auditEvent = AuditEvent(
            timestamp: Date(),
            event: event,
            userId: userId,
            success: success,
            details: details,
            ipAddress: nil // Could be populated if needed
        )
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Log to system
            self.logger.log(level: success ? .info : .error,
                          "[\(event.rawValue)] success=\(success) details=\(details)")
            
            // Store event
            self.events.append(auditEvent)
            
            // Trim if needed
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
            
            // Persist to disk
            self.saveEvents()
        }
    }
    
    // MARK: - Convenience Methods
    
    func logApiKeyChange(action: String, success: Bool) {
        let eventType: AuditEvent.EventType
        switch action {
        case "added":
            eventType = .apiKeyAdded
        case "updated":
            eventType = .apiKeyUpdated
        case "removed":
            eventType = .apiKeyRemoved
        default:
            eventType = .apiKeyValidated
        }
        
        log(event: eventType, success: success, details: ["action": action])
    }
    
    func logProfileAction(action: String, profileId: String, profileName: String, success: Bool) {
        let eventType: AuditEvent.EventType
        switch action {
        case "selected":
            eventType = .profileSelected
        case "disabled":
            eventType = .profileDisabled
        case "enabled":
            eventType = .profileEnabled
        default:
            eventType = .profileSelected
        }
        
        log(event: eventType, success: success, details: [
            "action": action,
            "profileId": profileId,
            "profileName": profileName
        ])
    }
    
    func logAuthentication(method: String, success: Bool) {
        let eventType: AuditEvent.EventType = success ? .authenticationSuccess : .authenticationFailure
        log(event: eventType, success: success, details: ["method": method])
    }
    
    // MARK: - Retrieval
    
    func getRecentEvents(limit: Int = 100) -> [AuditEvent] {
        queue.sync {
            Array(events.suffix(limit))
        }
    }
    
    func getEvents(since date: Date) -> [AuditEvent] {
        queue.sync {
            events.filter { $0.timestamp >= date }
        }
    }
    
    func getEvents(ofType type: AuditEvent.EventType) -> [AuditEvent] {
        queue.sync {
            events.filter { $0.event == type }
        }
    }
    
    // MARK: - Persistence
    
    private func saveEvents() {
        guard let storageURL = storageURL else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(events)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save audit events: \(error.localizedDescription)")
        }
    }
    
    private func loadEvents() {
        guard let storageURL = storageURL,
              FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            events = try decoder.decode([AuditEvent].self, from: data)
        } catch {
            logger.error("Failed to load audit events: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Export
    
    func exportAuditLog() -> String {
        let events = getRecentEvents(limit: maxEvents)
        var log = "ControlD Audit Log\n"
        log += "Generated: \(Date())\n"
        log += "Total Events: \(events.count)\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        for event in events {
            log += "[\(dateFormatter.string(from: event.timestamp))] "
            log += "\(event.event.rawValue) - "
            log += "\(event.success ? "SUCCESS" : "FAILURE")\n"
            if !event.details.isEmpty {
                log += "  Details: \(event.details)\n"
            }
            log += "\n"
        }
        
        return log
    }
}

