import Foundation
import CloudKit
import Combine

/// Service for backup, sync, and data management across devices
class BackupSyncService: ObservableObject {
    static let shared = BackupSyncService()
    
    @Published var isCloudAvailable = false
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var backupStatus: BackupStatus = .none
    
    private let container = CKContainer.default()
    private let privateDatabase: CKDatabase
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    private let lastSyncKey = "ControlDLastCloudSync"
    private let backupEnabledKey = "ControlDCloudBackupEnabled"
    
    private init() {
        privateDatabase = container.privateCloudDatabase
        checkCloudAvailability()
        loadSyncSettings()
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
    
    enum BackupStatus {
        case none
        case inProgress
        case completed(Date)
        case failed(String)
        
        var description: String {
            switch self {
            case .none:
                return "No backup"
            case .inProgress:
                return "Backing up..."
            case .completed(let date):
                return "Backed up \(formatDate(date))"
            case .failed(let error):
                return "Backup failed: \(error)"
            }
        }
    }
    
    struct BackupData: Codable {
        let profiles: [ProfileBackupData]
        let settings: SettingsBackupData
        let analytics: AnalyticsBackupData
        let timestamp: Date
        let version: String
        
        struct ProfileBackupData: Codable {
            let id: String
            let name: String
            let isFavorite: Bool
            let customName: String?
            let groupId: String?
            let notes: String
            let usageCount: Int
            let averageDuration: TimeInterval
        }
        
        struct SettingsBackupData: Codable {
            let selectedProfileId: String
            let selectedProfileName: String
            let securityLevel: String
            let syncInterval: TimeInterval
            let notificationEnabled: Bool
        }
        
        struct AnalyticsBackupData: Codable {
            let dailyStats: [String: Any]
            let weeklyStats: [String: Any]
            let profileUsageStats: [String: Any]
        }
    }
    
    struct SyncConflict: Identifiable {
        let id = UUID()
        let recordType: String
        let localData: Data
        let cloudData: Data
        let conflictType: ConflictType
        let timestamp: Date
        
        enum ConflictType {
            case dataMismatch
            case timestampConflict
            case versionConflict
        }
    }
    
    // MARK: - Cloud Availability
    
    private func checkCloudAvailability() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isCloudAvailable = true
                case .noAccount, .restricted, .couldNotDetermine:
                    self?.isCloudAvailable = false
                @unknown default:
                    self?.isCloudAvailable = false
                }
            }
        }
    }
    
    // MARK: - Backup Operations
    
    func createBackup() async -> Bool {
        guard isCloudAvailable else {
            await MainActor.run {
                backupStatus = .failed("iCloud not available")
            }
            return false
        }
        
        await MainActor.run {
            backupStatus = .inProgress
        }
        
        do {
            let backupData = await createBackupData()
            let success = await uploadBackupToCloud(backupData)
            
            if success {
                await MainActor.run {
                    backupStatus = .completed(Date())
                }
                
                // Log security event
                EnhancedSecurityService.shared.logSecurityEvent(
                    .dataExported,
                    details: "Backup created and uploaded to iCloud",
                    success: true
                )
                
                return true
            } else {
                await MainActor.run {
                    backupStatus = .failed("Upload failed")
                }
                return false
            }
            
        } catch {
            await MainActor.run {
                backupStatus = .failed(error.localizedDescription)
            }
            return false
        }
    }
    
    private func createBackupData() async -> BackupData {
        // Collect profile data
        let profileData = ProfileManagementService.shared.profiles.map { profile in
            BackupData.ProfileBackupData(
                id: profile.id,
                name: profile.name,
                isFavorite: profile.isFavorite,
                customName: profile.customName,
                groupId: profile.groupId,
                notes: profile.notes,
                usageCount: profile.usageCount,
                averageDuration: profile.averageDuration
            )
        }
        
        // Collect settings data
        let settingsData = BackupData.SettingsBackupData(
            selectedProfileId: SettingsManager().selectedProfileId,
            selectedProfileName: SettingsManager().selectedProfileName,
            securityLevel: EnhancedSecurityService.shared.securityLevel.description,
            syncInterval: BackgroundSyncService.shared.syncInterval,
            notificationEnabled: NotificationService.shared.isAuthorized
        )
        
        // Collect analytics data (simplified)
        let analyticsData = BackupData.AnalyticsBackupData(
            dailyStats: [:],
            weeklyStats: [:],
            profileUsageStats: [:]
        )
        
        return BackupData(
            profiles: profileData,
            settings: settingsData,
            analytics: analyticsData,
            timestamp: Date(),
            version: "1.0"
        )
    }
    
    private func uploadBackupToCloud(_ backupData: BackupData) async -> Bool {
        do {
            let record = CKRecord(recordType: "ControlDBackup")
            record["data"] = try JSONEncoder().encode(backupData)
            record["timestamp"] = backupData.timestamp
            record["version"] = backupData.version
            
            _ = try await privateDatabase.save(record)
            
            await MainActor.run {
                lastSyncTime = Date()
                saveSyncSettings()
            }
            
            return true
            
        } catch {
            print("❌ Failed to upload backup to iCloud: \(error)")
            return false
        }
    }
    
    // MARK: - Restore Operations
    
    func restoreFromBackup() async -> Bool {
        guard isCloudAvailable else {
            return false
        }
        
        do {
            let backupData = try await downloadBackupFromCloud()
            let success = await applyBackupData(backupData)
            
            if success {
                // Log security event
                EnhancedSecurityService.shared.logSecurityEvent(
                    .dataImported,
                    details: "Data restored from iCloud backup",
                    success: true
                )
            }
            
            return success
            
        } catch {
            print("❌ Failed to restore from backup: \(error)")
            return false
        }
    }
    
    private func downloadBackupFromCloud() async throws -> BackupData {
        let query = CKQuery(recordType: "ControlDBackup", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let records = try await privateDatabase.records(matching: query)
        
        guard let record = records.matchResults.first?.1,
              case .success(let ckRecord) = record,
              let data = ckRecord["data"] as? Data else {
            throw BackupError.noBackupFound
        }
        
        return try JSONDecoder().decode(BackupData.self, from: data)
    }
    
    private func applyBackupData(_ backupData: BackupData) async -> Bool {
        // Restore profile data
        for profileBackup in backupData.profiles {
            if let existingProfile = ProfileManagementService.shared.getProfile(by: profileBackup.id) {
                var updatedProfile = existingProfile
                updatedProfile.isFavorite = profileBackup.isFavorite
                updatedProfile.customName = profileBackup.customName
                updatedProfile.groupId = profileBackup.groupId
                updatedProfile.notes = profileBackup.notes
                updatedProfile.usageCount = profileBackup.usageCount
                updatedProfile.averageDuration = profileBackup.averageDuration
                
                ProfileManagementService.shared.updateProfile(updatedProfile)
            }
        }
        
        // Restore settings
        let settingsManager = SettingsManager()
        settingsManager.saveSelectedProfile(
            id: backupData.settings.selectedProfileId,
            name: backupData.settings.selectedProfileName
        )
        
        return true
    }
    
    // MARK: - Sync Operations
    
    func performSync() async {
        guard isCloudAvailable else {
            await MainActor.run {
                syncStatus = .failed("iCloud not available")
            }
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
        }
        
        do {
            // Check for conflicts
            let conflicts = try await checkForConflicts()
            
            if conflicts.isEmpty {
                // No conflicts, proceed with sync
                let success = await syncData()
                
                await MainActor.run {
                    syncStatus = success ? .success : .failed("Sync failed")
                    lastSyncTime = Date()
                }
                
            } else {
                // Handle conflicts
                await handleConflicts(conflicts)
            }
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error.localizedDescription)
            }
        }
        
        await MainActor.run {
            isSyncing = false
        }
        
        saveSyncSettings()
    }
    
    private func syncData() async -> Bool {
        // Upload local changes
        let uploadSuccess = await uploadLocalChanges()
        
        // Download remote changes
        let downloadSuccess = await downloadRemoteChanges()
        
        return uploadSuccess && downloadSuccess
    }
    
    private func uploadLocalChanges() async -> Bool {
        // Implementation would upload local data changes to iCloud
        return true
    }
    
    private func downloadRemoteChanges() async -> Bool {
        // Implementation would download remote changes from iCloud
        return true
    }
    
    private func checkForConflicts() async throws -> [SyncConflict] {
        // Implementation would check for sync conflicts
        return []
    }
    
    private func handleConflicts(_ conflicts: [SyncConflict]) async {
        // Implementation would handle sync conflicts
        // For now, we'll use local data as the source of truth
        print("🔄 Handling \(conflicts.count) sync conflicts")
    }
    
    // MARK: - Export/Import
    
    func exportData() -> String {
        let exportData = ExportData(
            profiles: ProfileManagementService.shared.profiles,
            settings: getExportSettings(),
            analytics: getExportAnalytics(),
            timestamp: Date(),
            version: "1.0"
        )
        
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            // Log security event
            EnhancedSecurityService.shared.logSecurityEvent(
                .dataExported,
                details: "Data exported to JSON",
                success: true
            )
            
            return jsonString
            
        } catch {
            print("❌ Failed to export data: \(error)")
            return ""
        }
    }
    
    func importData(from jsonString: String) -> Bool {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return false
        }
        
        do {
            let exportData = try JSONDecoder().decode(ExportData.self, from: jsonData)
            
            // Apply imported data
            applyImportedData(exportData)
            
            // Log security event
            EnhancedSecurityService.shared.logSecurityEvent(
                .dataImported,
                details: "Data imported from JSON",
                success: true
            )
            
            return true
            
        } catch {
            print("❌ Failed to import data: \(error)")
            return false
        }
    }
    
    private func applyImportedData(_ exportData: ExportData) {
        // Apply imported profile data
        for profile in exportData.profiles {
            ProfileManagementService.shared.updateProfile(profile)
        }
        
        // Apply imported settings
        let settingsManager = SettingsManager()
        settingsManager.saveSelectedProfile(
            id: exportData.settings.selectedProfileId,
            name: exportData.settings.selectedProfileName
        )
    }
    
    // MARK: - Supporting Types
    
    private struct ExportData: Codable {
        let profiles: [ProfileManagementService.EnhancedProfile]
        let settings: ExportSettings
        let analytics: ExportAnalytics
        let timestamp: Date
        let version: String
    }
    
    private struct ExportSettings: Codable {
        let selectedProfileId: String
        let selectedProfileName: String
    }
    
    private struct ExportAnalytics: Codable {
        let dailyStats: String
        let weeklyStats: String
    }
    
    private func getExportSettings() -> ExportSettings {
        let settingsManager = SettingsManager()
        return ExportSettings(
            selectedProfileId: settingsManager.selectedProfileId,
            selectedProfileName: settingsManager.selectedProfileName
        )
    }
    
    private func getExportAnalytics() -> ExportAnalytics {
        return ExportAnalytics(
            dailyStats: "{}",
            weeklyStats: "{}"
        )
    }
    
    // MARK: - Settings Management
    
    func enableCloudBackup(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: backupEnabledKey)
        
        if enabled {
            // Start automatic backups
            startAutomaticBackups()
        } else {
            // Stop automatic backups
            stopAutomaticBackups()
        }
    }
    
    func isCloudBackupEnabled() -> Bool {
        return userDefaults.bool(forKey: backupEnabledKey)
    }
    
    private func startAutomaticBackups() {
        // Schedule automatic backups every 24 hours
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task {
                await self.createBackup()
            }
        }
    }
    
    private func stopAutomaticBackups() {
        // Implementation would stop automatic backup timers
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func saveSyncSettings() {
        userDefaults.set(lastSyncTime, forKey: lastSyncKey)
    }
    
    private func loadSyncSettings() {
        lastSyncTime = userDefaults.object(forKey: lastSyncKey) as? Date
    }
    
    // MARK: - Error Handling
    
    enum BackupError: LocalizedError {
        case noBackupFound
        case cloudUnavailable
        case uploadFailed
        case downloadFailed
        case invalidData
        
        var errorDescription: String? {
            switch self {
            case .noBackupFound:
                return "No backup found in iCloud"
            case .cloudUnavailable:
                return "iCloud is not available"
            case .uploadFailed:
                return "Failed to upload backup"
            case .downloadFailed:
                return "Failed to download backup"
            case .invalidData:
                return "Invalid backup data"
            }
        }
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
    
    func getBackupStatusInfo() -> String {
        return backupStatus.description
    }
}
