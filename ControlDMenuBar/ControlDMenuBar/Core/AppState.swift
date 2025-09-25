import Foundation
import Combine

/// Centralized application state management using Redux-like pattern
@MainActor
class AppState: ObservableObject {
    
    // MARK: - Published State
    
    @Published var profiles: ProfilesState = .idle
    @Published var settings: SettingsState = .idle
    @Published var timers: TimersState = .idle
    @Published var network: NetworkState = .idle
    @Published var ui: UIState = .idle
    @Published var errors: ErrorState = .idle
    
    // MARK: - State Definitions
    
    enum ProfilesState: Equatable {
        case idle
        case loading
        case loaded([Profile])
        case refreshing([Profile])
        case error(AppError)
        
        var profiles: [Profile] {
            switch self {
            case .loaded(let profiles), .refreshing(let profiles):
                return profiles
            default:
                return []
            }
        }
        
        var isLoading: Bool {
            switch self {
            case .loading, .refreshing:
                return true
            default:
                return false
            }
        }
    }
    
    enum SettingsState: Equatable {
        case idle
        case validating
        case valid(ApiKeyInfo)
        case invalid(String)
        case saving
        case saved
        case error(AppError)
        
        var isValidating: Bool {
            if case .validating = self { return true }
            return false
        }
        
        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
        
        var apiKeyInfo: ApiKeyInfo? {
            if case .valid(let info) = self { return info }
            return nil
        }
    }
    
    enum TimersState: Equatable {
        case idle
        case active([String: TimerInfo])
        case updating(String) // profileId being updated
        
        var activeTimers: [String: TimerInfo] {
            if case .active(let timers) = self { return timers }
            return [:]
        }
        
        var isUpdating: Bool {
            if case .updating = self { return true }
            return false
        }
    }
    
    enum NetworkState: Equatable {
        case idle
        case connecting
        case connected
        case disconnected
        case error(AppError)
        
        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
        
        var isConnecting: Bool {
            if case .connecting = self { return true }
            return false
        }
    }
    
    enum UIState: Equatable {
        case idle
        case showingSettings
        case showingError(AppError)
        case showingSuccess(String)
        case loading(String) // operation description
        
        var isShowingSettings: Bool {
            if case .showingSettings = self { return true }
            return false
        }
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        var loadingMessage: String? {
            if case .loading(let message) = self { return message }
            return nil
        }
    }
    
    enum ErrorState: Equatable {
        case idle
        case error(AppError)
        case recovered
        
        var currentError: AppError? {
            if case .error(let error) = self { return error }
            return nil
        }
        
        var hasError: Bool {
            if case .error = self { return true }
            return false
        }
    }
    
    // MARK: - Data Models
    
    struct Profile: Codable, Identifiable, Equatable {
        let id: String
        let name: String
        let updated: Int
        let disableTTL: Int?
        let isSelected: Bool
        
        enum CodingKeys: String, CodingKey {
            case id = "PK"
            case name
            case updated
            case disableTTL = "disable_ttl"
            case isSelected
        }
        
        var isDisabled: Bool {
            guard let ttl = disableTTL else { return false }
            return ttl > Int(Date().timeIntervalSince1970)
        }
        
        var statusDescription: String {
            return isDisabled ? "Disabled" : "Enabled"
        }
    }
    
    struct ApiKeyInfo: Equatable {
        let isValid: Bool
        let lastValidated: Date
        let profileCount: Int?
        
        var isExpired: Bool {
            return Date().timeIntervalSince(lastValidated) > 3600 // 1 hour
        }
    }
    
    struct TimerInfo: Codable, Identifiable, Equatable {
        let id = UUID()
        let profileId: String
        let profileName: String
        let startTime: Date
        let duration: TimeInterval
        let expirationTime: Date
        
        var timeRemaining: TimeInterval {
            return max(0, expirationTime.timeIntervalSince(Date()))
        }
        
        var isExpired: Bool {
            return timeRemaining <= 0
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
    
    // MARK: - Computed Properties
    
    var selectedProfile: Profile? {
        return profiles.profiles.first { $0.isSelected }
    }
    
    var hasValidConfiguration: Bool {
        return settings.isValid && selectedProfile != nil
    }
    
    var needsConfiguration: Bool {
        return !hasValidConfiguration
    }
    
    var isOperationInProgress: Bool {
        return profiles.isLoading || settings.isValidating || timers.isUpdating || network.isConnecting || ui.isLoading
    }
    
    // MARK: - Initialization
    
    init() {
        setupStateObservation()
    }
    
    private func setupStateObservation() {
        // Monitor state changes for debugging
        $profiles.sink { state in
            print("🔄 Profiles state changed: \(state)")
        }.store(in: &cancellables)
        
        $settings.sink { state in
            print("⚙️ Settings state changed: \(state)")
        }.store(in: &cancellables)
        
        $timers.sink { state in
            print("⏰ Timers state changed: \(state)")
        }.store(in: &cancellables)
        
        $network.sink { state in
            print("🌐 Network state changed: \(state)")
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - State Mutations

extension AppState {
    
    // MARK: - Profiles Actions
    
    func setProfilesLoading() {
        profiles = .loading
    }
    
    func setProfilesLoaded(_ profileList: [Profile]) {
        profiles = .loaded(profileList)
    }
    
    func setProfilesRefreshing(_ currentProfiles: [Profile]) {
        profiles = .refreshing(currentProfiles)
    }
    
    func setProfilesError(_ error: AppError) {
        profiles = .error(error)
        errors = .error(error)
    }
    
    func selectProfile(_ profileId: String) {
        guard case .loaded(let currentProfiles) = profiles else { return }
        
        let updatedProfiles = currentProfiles.map { profile in
            var updatedProfile = profile
            updatedProfile.isSelected = (profile.id == profileId)
            return updatedProfile
        }
        
        profiles = .loaded(updatedProfiles)
    }
    
    // MARK: - Settings Actions
    
    func setSettingsValidating() {
        settings = .validating
    }
    
    func setSettingsValid(_ apiKeyInfo: ApiKeyInfo) {
        settings = .valid(apiKeyInfo)
    }
    
    func setSettingsInvalid(_ message: String) {
        settings = .invalid(message)
    }
    
    func setSettingsSaving() {
        settings = .saving
    }
    
    func setSettingsSaved() {
        settings = .saved
    }
    
    func setSettingsError(_ error: AppError) {
        settings = .error(error)
        errors = .error(error)
    }
    
    // MARK: - Timers Actions
    
    func setTimersActive(_ activeTimers: [String: TimerInfo]) {
        timers = .active(activeTimers)
    }
    
    func setTimerUpdating(_ profileId: String) {
        timers = .updating(profileId)
    }
    
    func addTimer(_ timer: TimerInfo) {
        var currentTimers = timers.activeTimers
        currentTimers[timer.profileId] = timer
        timers = .active(currentTimers)
    }
    
    func removeTimer(for profileId: String) {
        var currentTimers = timers.activeTimers
        currentTimers.removeValue(forKey: profileId)
        timers = .active(currentTimers)
    }
    
    // MARK: - Network Actions
    
    func setNetworkConnecting() {
        network = .connecting
    }
    
    func setNetworkConnected() {
        network = .connected
    }
    
    func setNetworkDisconnected() {
        network = .disconnected
    }
    
    func setNetworkError(_ error: AppError) {
        network = .error(error)
        errors = .error(error)
    }
    
    // MARK: - UI Actions
    
    func showSettings() {
        ui = .showingSettings
    }
    
    func hideSettings() {
        ui = .idle
    }
    
    func showError(_ error: AppError) {
        ui = .showingError(error)
        errors = .error(error)
    }
    
    func showSuccess(_ message: String) {
        ui = .showingSuccess(message)
    }
    
    func setLoading(_ message: String) {
        ui = .loading(message)
    }
    
    func clearUI() {
        ui = .idle
    }
    
    // MARK: - Error Actions
    
    func clearError() {
        errors = .idle
    }
    
    func setError(_ error: AppError) {
        errors = .error(error)
    }
    
    func markErrorRecovered() {
        errors = .recovered
    }
}

// MARK: - State Persistence

extension AppState {
    
    /// Saves current state to UserDefaults
    func saveState() {
        let encoder = JSONEncoder()
        
        // Save selected profile
        if let selectedProfile = selectedProfile {
            if let encoded = try? encoder.encode(selectedProfile) {
                UserDefaults.standard.set(encoded, forKey: "selected_profile")
            }
        }
        
        // Save active timers
        let activeTimers = timers.activeTimers
        if let encoded = try? encoder.encode(activeTimers) {
            UserDefaults.standard.set(encoded, forKey: "active_timers")
        }
    }
    
    /// Loads state from UserDefaults
    func loadState() {
        let decoder = JSONDecoder()
        
        // Load selected profile
        if let data = UserDefaults.standard.data(forKey: "selected_profile"),
           let profile = try? decoder.decode(Profile.self, from: data) {
            // Update profiles state if we have profiles loaded
            if case .loaded(let profiles) = self.profiles {
                let updatedProfiles = profiles.map { p in
                    var updated = p
                    updated.isSelected = (p.id == profile.id)
                    return updated
                }
                self.profiles = .loaded(updatedProfiles)
            }
        }
        
        // Load active timers
        if let data = UserDefaults.standard.data(forKey: "active_timers"),
           let timersDict = try? decoder.decode([String: TimerInfo].self, from: data) {
            // Filter out expired timers
            let activeTimers = timersDict.filter { !$0.value.isExpired }
            if !activeTimers.isEmpty {
                self.timers = .active(activeTimers)
            }
        }
    }
    
    /// Clears all persisted state
    func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "selected_profile")
        UserDefaults.standard.removeObject(forKey: "active_timers")
    }
}

// MARK: - Debug Helpers

extension AppState {
    
    var debugDescription: String {
        return """
        AppState Debug Info:
        - Profiles: \(profiles)
        - Settings: \(settings)
        - Timers: \(timers)
        - Network: \(network)
        - UI: \(ui)
        - Errors: \(errors)
        - Selected Profile: \(selectedProfile?.name ?? "None")
        - Needs Configuration: \(needsConfiguration)
        - Operation In Progress: \(isOperationInProgress)
        """
    }
}