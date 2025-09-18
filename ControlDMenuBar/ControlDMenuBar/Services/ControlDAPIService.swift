import Foundation

/// Enhanced ControlD API service with proper dependency injection and error handling
final class ControlDAPIService: APIServiceProtocol {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkService
    private let settingsService: SettingsServiceProtocol
    private let configuration: ConfigurationServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    init(networkService: NetworkService? = nil,
         settingsService: SettingsServiceProtocol,
         configuration: ConfigurationServiceProtocol = ConfigurationService.shared,
         logger: LoggerProtocol = LoggingService.shared) {
        self.networkService = networkService ?? NetworkService(configuration: configuration, logger: logger)
        self.settingsService = settingsService
        self.configuration = configuration
        self.logger = logger
    }
    
    // MARK: - APIServiceProtocol
    
    func validateConnection() async throws -> Bool {
        guard let apiKey = settingsService.apiKey else {
            throw AppError.invalidApiKey
        }
        
        return try await validateApiKey(apiKey)
    }
    
    func validateApiKey(_ apiKey: String) async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw AppError.invalidApiKey
        }
        
        logger.debug("Validating API key")
        
        do {
            return try await networkService.validateConnection(apiKey: apiKey)
        } catch {
            logger.error("API key validation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchAllProfiles() async throws -> [Profile] {
        guard let apiKey = settingsService.apiKey else {
            throw AppError.invalidApiKey
        }
        
        logger.debug("Fetching all profiles")
        
        do {
            let response: ProfilesResponse = try await networkService.performRequest(
                endpoint: .getProfiles,
                responseType: ProfilesResponse.self,
                apiKey: apiKey
            )
            
            let profiles = response.body.profiles.map { profileData in
                Profile(
                    id: profileData.PK,
                    name: profileData.name,
                    updated: profileData.updated,
                    disableTTL: profileData.disable_ttl
                )
            }
            
            logger.info("Successfully fetched \(profiles.count) profiles")
            return profiles
            
        } catch {
            logger.error("Failed to fetch profiles: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getProfileStatus(profileId: String) async throws -> ProfileStatus {
        logger.debug("Getting status for profile: \(profileId)")
        
        let profiles = try await fetchAllProfiles()
        
        guard let profile = profiles.first(where: { $0.id == profileId }) else {
            throw AppError.profileNotFound
        }
        
        let status = ProfileStatus(
            isEnabled: profile.disableTTL == nil || profile.disableTTL == 0,
            disableExpiresAt: profile.disableTTL.flatMap { ttl in
                ttl > 0 ? Date(timeIntervalSince1970: TimeInterval(ttl)) : nil
            }
        )
        
        logger.debug("Profile \(profileId) status: \(status.statusDescription)")
        return status
    }
    
    func toggleProfileDisable(profileId: String) async throws -> Bool {
        guard let apiKey = settingsService.apiKey else {
            throw AppError.invalidApiKey
        }
        
        logger.info("Toggling disable status for profile: \(profileId)")
        
        // Get current status
        let currentStatus = try await getProfileStatus(profileId: profileId)
        
        let newDisableTTL: Int
        let actionDescription: String
        
        if currentStatus.isEnabled {
            // Disable for configured duration
            let expirationTime = Date().addingTimeInterval(configuration.profileDisableDuration)
            newDisableTTL = Int(expirationTime.timeIntervalSince1970)
            actionDescription = "Disabling profile for \(Int(configuration.profileDisableDuration / 3600)) hour(s)"
        } else {
            // Re-enable by setting TTL to 0
            newDisableTTL = 0
            actionDescription = "Re-enabling profile"
        }
        
        logger.info(actionDescription)
        
        do {
            let endpoint = APIEndpoint.updateProfile(id: profileId, disableTTL: newDisableTTL)
            let _: ProfileUpdateResponse = try await networkService.performRequest(
                endpoint: endpoint,
                responseType: ProfileUpdateResponse.self,
                apiKey: apiKey
            )
            
            logger.info("Successfully toggled profile disable status")
            
            // Verify the change
            let newStatus = try await getProfileStatus(profileId: profileId)
            let expectedEnabled = newDisableTTL == 0
            
            if newStatus.isEnabled == expectedEnabled {
                logger.info("Profile status change verified successfully")
                return true
            } else {
                logger.warning("Profile status change verification failed")
                throw AppError.validationError("Status change was not applied correctly")
            }
            
        } catch {
            logger.error("Failed to toggle profile disable status: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Response Models

struct ProfileUpdateResponse: Codable {
    let success: Bool?
    let message: String?
}
