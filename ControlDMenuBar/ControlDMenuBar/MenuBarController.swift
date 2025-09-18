import SwiftUI
import Combine

@MainActor
class MenuBarController: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?
    
    private let controlDService = ControlDService()
    let settingsManager = SettingsManager()
    
    init() {
        // Initialize the controller
        setupControlDService()
    }
    
    private func setupControlDService() {
        // Pass the settings manager to the service
        controlDService.settingsManager = settingsManager
    }
    
    func disableEndpoint() async throws -> Bool {
        do {
            let success = try await controlDService.disableWorkMacEndpoint()
            isConnected = success
            lastError = nil
            return success
        } catch {
            lastError = error.localizedDescription
            isConnected = false
            throw error
        }
    }
    
    func checkConnection() async -> Bool {
        do {
            return try await controlDService.validateConnection()
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    func getProfileStatus() async throws -> String {
        return try await controlDService.getProfileStatus()
    }
    
    func validateApiKey(_ apiKey: String) async throws -> Bool {
        return try await controlDService.validateApiKey(apiKey)
    }
    
    func loadAvailableProfiles() async throws -> [ControlDService.Profile] {
        return try await controlDService.fetchAllProfiles()
    }
    
    func disableProfile(profileId: String, durationInMinutes: Int = 60) async throws -> Bool {
        return try await controlDService.disableProfile(profileId: profileId, durationInMinutes: durationInMinutes)
    }
    
    func enableProfile(profileId: String) async throws -> Bool {
        return try await controlDService.enableProfile(profileId: profileId)
    }
    
    var needsConfiguration: Bool {
        return !settingsManager.hasValidApiKey || !settingsManager.hasSelectedProfile
    }
}