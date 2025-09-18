import Foundation
import UserNotifications
import AppKit

/// Service for managing system notifications and status alerts
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var lastNotificationTime: Date?
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if let error = error {
                    print("❌ Notification authorization error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Profile Status Notifications
    
    func notifyProfileDisabled(profileName: String, duration: TimeInterval) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "ControlD Profile Disabled"
        content.body = "\(profileName) has been disabled for \(formatDuration(duration))"
        content.sound = .default
        content.categoryIdentifier = "PROFILE_STATUS"
        
        // Add action buttons
        content.userInfo = [
            "action": "profile_disabled",
            "profile": profileName,
            "duration": duration
        ]
        
        let request = UNNotificationRequest(
            identifier: "profile_disabled_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.lastNotificationTime = Date()
                }
            }
        }
    }
    
    func notifyProfileEnabled(profileName: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "ControlD Profile Enabled"
        content.body = "\(profileName) has been re-enabled"
        content.sound = .default
        content.categoryIdentifier = "PROFILE_STATUS"
        
        content.userInfo = [
            "action": "profile_enabled",
            "profile": profileName
        ]
        
        let request = UNNotificationRequest(
            identifier: "profile_enabled_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.lastNotificationTime = Date()
                }
            }
        }
    }
    
    func notifyTimerExpiring(profileName: String, timeRemaining: TimeInterval) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "ControlD Timer Expiring"
        content.body = "\(profileName) will be re-enabled in \(formatDuration(timeRemaining))"
        content.sound = .default
        content.categoryIdentifier = "TIMER_WARNING"
        
        content.userInfo = [
            "action": "timer_expiring",
            "profile": profileName,
            "timeRemaining": timeRemaining
        ]
        
        let request = UNNotificationRequest(
            identifier: "timer_expiring_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send timer notification: \(error)")
            }
        }
    }
    
    // MARK: - Connection Status Notifications
    
    func notifyConnectionLost() {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "ControlD Connection Lost"
        content.body = "Unable to connect to ControlD API. Please check your internet connection."
        content.sound = .default
        content.categoryIdentifier = "CONNECTION_STATUS"
        
        let request = UNNotificationRequest(
            identifier: "connection_lost_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send connection notification: \(error)")
            }
        }
    }
    
    func notifyConnectionRestored() {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "ControlD Connection Restored"
        content.body = "Successfully reconnected to ControlD API"
        content.sound = .default
        content.categoryIdentifier = "CONNECTION_STATUS"
        
        let request = UNNotificationRequest(
            identifier: "connection_restored_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send connection notification: \(error)")
            }
        }
    }
    
    // MARK: - Scheduled Notifications
    
    func scheduleTimerExpirationNotification(profileName: String, expirationTime: Date) {
        guard isAuthorized else { return }
        
        // Schedule notification 5 minutes before expiration
        let triggerTime = expirationTime.addingTimeInterval(-300) // 5 minutes before
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: triggerTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let content = UNMutableNotificationContent()
        content.title = "ControlD Timer Expiring Soon"
        content.body = "\(profileName) will be re-enabled in 5 minutes"
        content.sound = .default
        content.categoryIdentifier = "TIMER_EXPIRATION"
        
        content.userInfo = [
            "action": "timer_expiration",
            "profile": profileName,
            "expirationTime": expirationTime.timeIntervalSince1970
        ]
        
        let request = UNNotificationRequest(
            identifier: "timer_expiration_\(profileName)_\(expirationTime.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule timer notification: \(error)")
            }
        }
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
    
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    func clearNotifications(for profileName: String) {
        center.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.compactMap { request in
                if let profile = request.content.userInfo["profile"] as? String,
                   profile == profileName {
                    return request.identifier
                }
                return nil
            }
            
            self.center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
}

// MARK: - Notification Categories

extension NotificationService {
    func setupNotificationCategories() {
        let profileStatusCategory = UNNotificationCategory(
            identifier: "PROFILE_STATUS",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_STATUS",
                    title: "View Status",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let timerCategory = UNNotificationCategory(
            identifier: "TIMER_WARNING",
            actions: [
                UNNotificationAction(
                    identifier: "EXTEND_TIMER",
                    title: "Extend Timer",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "ENABLE_NOW",
                    title: "Enable Now",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([profileStatusCategory, timerCategory])
    }
}
