import Foundation
import Combine

/// Service for advanced profile management including favorites, groups, and bulk operations
class ProfileManagementService: ObservableObject {
    static let shared = ProfileManagementService()
    
    @Published var profiles: [EnhancedProfile] = []
    @Published var favoriteProfiles: [String] = []
    @Published var profileGroups: [ProfileGroup] = []
    @Published var recentProfiles: [String] = []
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "ControlDFavoriteProfiles"
    private let groupsKey = "ControlDProfileGroups"
    private let recentKey = "ControlDRecentProfiles"
    private let maxRecentProfiles = 5
    
    private init() {
        loadFavorites()
        loadProfileGroups()
        loadRecentProfiles()
    }
    
    // MARK: - Data Models
    
    struct EnhancedProfile: Identifiable, Codable {
        let id: String
        let name: String
        let originalProfile: ControlDService.Profile
        var isFavorite: Bool = false
        var customName: String?
        var groupId: String?
        var lastUsed: Date?
        var usageCount: Int = 0
        var averageDuration: TimeInterval = 0
        var notes: String = ""
        
        var displayName: String {
            return customName ?? name
        }
        
        var isDisabled: Bool {
            return originalProfile.disable_ttl != nil && originalProfile.disable_ttl! > 0
        }
        
        var disableTimeRemaining: TimeInterval? {
            guard let disable_ttl = originalProfile.disable_ttl else { return nil }
            let currentTime = Int(Date().timeIntervalSince1970)
            return max(0, TimeInterval(disable_ttl - currentTime))
        }
    }
    
    struct ProfileGroup: Identifiable, Codable {
        let id = UUID()
        let name: String
        let icon: String
        let color: String
        var profileIds: [String] = []
        var isDefault: Bool = false
        
        var profileCount: Int {
            return profileIds.count
        }
    }
    
    struct BulkOperation: Identifiable {
        let id = UUID()
        let operation: BulkOperationType
        let profileIds: [String]
        let duration: TimeInterval?
        let timestamp: Date
        
        enum BulkOperationType {
            case disable, enable, extend
        }
    }
    
    // MARK: - Profile Management
    
    func loadProfiles(from controlDProfiles: [ControlDService.Profile]) {
        isLoading = true
        
        profiles = controlDProfiles.map { profile in
            let existingEnhanced = profiles.first { $0.id == profile.PK }
            
            return EnhancedProfile(
                id: profile.PK,
                name: profile.name,
                originalProfile: profile,
                isFavorite: existingEnhanced?.isFavorite ?? favoriteProfiles.contains(profile.PK),
                customName: existingEnhanced?.customName,
                groupId: existingEnhanced?.groupId,
                lastUsed: existingEnhanced?.lastUsed,
                usageCount: existingEnhanced?.usageCount ?? 0,
                averageDuration: existingEnhanced?.averageDuration ?? 0,
                notes: existingEnhanced?.notes ?? ""
            )
        }
        
        isLoading = false
        saveProfiles()
    }
    
    func updateProfile(_ profile: EnhancedProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
        }
    }
    
    func getProfile(by id: String) -> EnhancedProfile? {
        return profiles.first { $0.id == id }
    }
    
    func getProfile(by name: String) -> EnhancedProfile? {
        return profiles.first { $0.name == name || $0.displayName == name }
    }
    
    // MARK: - Favorites Management
    
    func toggleFavorite(_ profileId: String) {
        if favoriteProfiles.contains(profileId) {
            favoriteProfiles.removeAll { $0 == profileId }
            if let index = profiles.firstIndex(where: { $0.id == profileId }) {
                profiles[index].isFavorite = false
            }
        } else {
            favoriteProfiles.append(profileId)
            if let index = profiles.firstIndex(where: { $0.id == profileId }) {
                profiles[index].isFavorite = true
            }
        }
        
        saveFavorites()
        saveProfiles()
    }
    
    func addToFavorites(_ profileId: String) {
        if !favoriteProfiles.contains(profileId) {
            favoriteProfiles.append(profileId)
            if let index = profiles.firstIndex(where: { $0.id == profileId }) {
                profiles[index].isFavorite = true
            }
            saveFavorites()
            saveProfiles()
        }
    }
    
    func removeFromFavorites(_ profileId: String) {
        favoriteProfiles.removeAll { $0 == profileId }
        if let index = profiles.firstIndex(where: { $0.id == profileId }) {
            profiles[index].isFavorite = false
        }
        saveFavorites()
        saveProfiles()
    }
    
    func getFavoriteProfiles() -> [EnhancedProfile] {
        return profiles.filter { favoriteProfiles.contains($0.id) }
    }
    
    // MARK: - Recent Profiles
    
    func addToRecent(_ profileId: String) {
        // Remove if already exists
        recentProfiles.removeAll { $0 == profileId }
        
        // Add to beginning
        recentProfiles.insert(profileId, at: 0)
        
        // Limit to max recent profiles
        if recentProfiles.count > maxRecentProfiles {
            recentProfiles = Array(recentProfiles.prefix(maxRecentProfiles))
        }
        
        // Update profile last used
        if let index = profiles.firstIndex(where: { $0.id == profileId }) {
            profiles[index].lastUsed = Date()
            profiles[index].usageCount += 1
        }
        
        saveRecentProfiles()
        saveProfiles()
    }
    
    func getRecentProfiles() -> [EnhancedProfile] {
        return recentProfiles.compactMap { profileId in
            profiles.first { $0.id == profileId }
        }
    }
    
    // MARK: - Profile Groups
    
    func createGroup(name: String, icon: String, color: String) -> ProfileGroup {
        let group = ProfileGroup(name: name, icon: icon, color: color)
        profileGroups.append(group)
        saveProfileGroups()
        return group
    }
    
    func addProfileToGroup(_ profileId: String, groupId: String) {
        if let groupIndex = profileGroups.firstIndex(where: { $0.id.uuidString == groupId }) {
            if !profileGroups[groupIndex].profileIds.contains(profileId) {
                profileGroups[groupIndex].profileIds.append(profileId)
                
                // Update profile
                if let profileIndex = profiles.firstIndex(where: { $0.id == profileId }) {
                    profiles[profileIndex].groupId = groupId
                }
                
                saveProfileGroups()
                saveProfiles()
            }
        }
    }
    
    func removeProfileFromGroup(_ profileId: String, groupId: String) {
        if let groupIndex = profileGroups.firstIndex(where: { $0.id.uuidString == groupId }) {
            profileGroups[groupIndex].profileIds.removeAll { $0 == profileId }
            
            // Update profile
            if let profileIndex = profiles.firstIndex(where: { $0.id == profileId }) {
                profiles[profileIndex].groupId = nil
            }
            
            saveProfileGroups()
            saveProfiles()
        }
    }
    
    func deleteGroup(_ groupId: String) {
        // Remove group
        profileGroups.removeAll { $0.id.uuidString == groupId }
        
        // Clear group reference from profiles
        for index in profiles.indices {
            if profiles[index].groupId == groupId {
                profiles[index].groupId = nil
            }
        }
        
        saveProfileGroups()
        saveProfiles()
    }
    
    func getProfilesInGroup(_ groupId: String) -> [EnhancedProfile] {
        return profiles.filter { $0.groupId == groupId }
    }
    
    // MARK: - Bulk Operations
    
    func performBulkDisable(profileIds: [String], duration: TimeInterval) async -> BulkOperation {
        let operation = BulkOperation(
            operation: .disable,
            profileIds: profileIds,
            duration: duration,
            timestamp: Date()
        )
        
        // Track analytics for each profile
        for profileId in profileIds {
            if let profile = getProfile(by: profileId) {
                AnalyticsService.shared.trackProfileDisable(
                    profileName: profile.displayName,
                    duration: duration
                )
            }
        }
        
        print("🔄 Bulk disable operation: \(profileIds.count) profiles for \(formatDuration(duration))")
        return operation
    }
    
    func performBulkEnable(profileIds: [String]) async -> BulkOperation {
        let operation = BulkOperation(
            operation: .enable,
            profileIds: profileIds,
            duration: nil,
            timestamp: Date()
        )
        
        // Track analytics for each profile
        for profileId in profileIds {
            if let profile = getProfile(by: profileId) {
                AnalyticsService.shared.trackProfileEnable(profileName: profile.displayName)
            }
        }
        
        print("🔄 Bulk enable operation: \(profileIds.count) profiles")
        return operation
    }
    
    func performBulkExtend(profileIds: [String], additionalDuration: TimeInterval) async -> BulkOperation {
        let operation = BulkOperation(
            operation: .extend,
            profileIds: profileIds,
            duration: additionalDuration,
            timestamp: Date()
        )
        
        print("🔄 Bulk extend operation: \(profileIds.count) profiles by \(formatDuration(additionalDuration))")
        return operation
    }
    
    // MARK: - Search and Filtering
    
    func searchProfiles(query: String) -> [EnhancedProfile] {
        guard !query.isEmpty else { return profiles }
        
        let lowercaseQuery = query.lowercased()
        return profiles.filter { profile in
            profile.name.lowercased().contains(lowercaseQuery) ||
            profile.displayName.lowercased().contains(lowercaseQuery) ||
            profile.notes.lowercased().contains(lowercaseQuery)
        }
    }
    
    func filterProfilesByStatus(_ status: ProfileStatus) -> [EnhancedProfile] {
        switch status {
        case .all:
            return profiles
        case .enabled:
            return profiles.filter { !$0.isDisabled }
        case .disabled:
            return profiles.filter { $0.isDisabled }
        case .favorites:
            return getFavoriteProfiles()
        case .recent:
            return getRecentProfiles()
        }
    }
    
    enum ProfileStatus {
        case all, enabled, disabled, favorites, recent
    }
    
    // MARK: - Profile Statistics
    
    func getProfileStatistics() -> ProfileStatistics {
        let totalProfiles = profiles.count
        let enabledProfiles = profiles.filter { !$0.isDisabled }.count
        let disabledProfiles = profiles.filter { $0.isDisabled }.count
        let favoriteCount = favoriteProfiles.count
        let recentCount = recentProfiles.count
        
        let totalUsage = profiles.reduce(0) { $0 + $1.usageCount }
        let averageUsage = totalProfiles > 0 ? Double(totalUsage) / Double(totalProfiles) : 0
        
        return ProfileStatistics(
            totalProfiles: totalProfiles,
            enabledProfiles: enabledProfiles,
            disabledProfiles: disabledProfiles,
            favoriteProfiles: favoriteCount,
            recentProfiles: recentCount,
            totalUsage: totalUsage,
            averageUsage: averageUsage
        )
    }
    
    struct ProfileStatistics {
        let totalProfiles: Int
        let enabledProfiles: Int
        let disabledProfiles: Int
        let favoriteProfiles: Int
        let recentProfiles: Int
        let totalUsage: Int
        let averageUsage: Double
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
    
    // MARK: - Persistence
    
    private func saveFavorites() {
        userDefaults.set(favoriteProfiles, forKey: favoritesKey)
    }
    
    private func loadFavorites() {
        favoriteProfiles = userDefaults.stringArray(forKey: favoritesKey) ?? []
    }
    
    private func saveProfileGroups() {
        if let encoded = try? JSONEncoder().encode(profileGroups) {
            userDefaults.set(encoded, forKey: groupsKey)
        }
    }
    
    private func loadProfileGroups() {
        if let data = userDefaults.data(forKey: groupsKey),
           let groups = try? JSONDecoder().decode([ProfileGroup].self, from: data) {
            profileGroups = groups
        } else {
            // Create default groups
            createDefaultGroups()
        }
    }
    
    private func createDefaultGroups() {
        profileGroups = [
            ProfileGroup(name: "Work", icon: "briefcase", color: "blue", isDefault: true),
            ProfileGroup(name: "Personal", icon: "house", color: "green", isDefault: true),
            ProfileGroup(name: "Travel", icon: "airplane", color: "orange", isDefault: true)
        ]
        saveProfileGroups()
    }
    
    private func saveRecentProfiles() {
        userDefaults.set(recentProfiles, forKey: recentKey)
    }
    
    private func loadRecentProfiles() {
        recentProfiles = userDefaults.stringArray(forKey: recentKey) ?? []
    }
    
    private func saveProfiles() {
        // Profiles are automatically saved through the main service
        // This method can be used for additional persistence if needed
    }
    
    func clearAllData() {
        favoriteProfiles.removeAll()
        recentProfiles.removeAll()
        profileGroups.removeAll()
        profiles.removeAll()
        
        userDefaults.removeObject(forKey: favoritesKey)
        userDefaults.removeObject(forKey: groupsKey)
        userDefaults.removeObject(forKey: recentKey)
    }
}
