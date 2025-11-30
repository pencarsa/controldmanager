import Foundation

/// Dependency injection container for managing app services
final class DependencyContainer {
    
    // MARK: - Singleton
    
    static let shared = DependencyContainer()
    
    // MARK: - Services
    
    lazy var configuration: ConfigurationServiceProtocol = {
        return ConfigurationService.shared
    }()
    
    lazy var logger: LoggerProtocol = {
        return LoggingService(configuration: configuration)
    }()
    
    lazy var keychainService: KeychainServiceProtocol = {
        return KeychainService(serviceName: configuration.keychainServiceName, logger: logger)
    }()
    
    lazy var settingsService: SettingsServiceProtocol = {
        return SettingsService(keychainService: keychainService, configuration: configuration, logger: logger)
    }()
    
    lazy var networkService: NetworkService = {
        return NetworkService(configuration: configuration, logger: logger)
    }()
    
    lazy var apiService: APIServiceProtocol = {
        return ControlDAPIService(
            networkService: networkService,
            settingsService: settingsService,
            configuration: configuration,
            logger: logger
        )
    }()
    
    // MARK: - Initialization
    
    private init() {
        logger.info("DependencyContainer initialized")
    }
    
    // MARK: - Factory Methods
    
    func makeMenuBarController() -> MenuBarController {
        // MenuBarController currently uses legacy services directly
        // This method is kept for future migration to DI pattern
        return MenuBarController()
    }
    
}

// MARK: - Protocol for Testability

protocol DependencyContainerProtocol {
    var configuration: ConfigurationServiceProtocol { get }
    var logger: LoggerProtocol { get }
    var keychainService: KeychainServiceProtocol { get }
    var settingsService: SettingsServiceProtocol { get }
    var networkService: NetworkService { get }
    var apiService: APIServiceProtocol { get }
    
    func makeMenuBarController() -> MenuBarController
}

extension DependencyContainer: DependencyContainerProtocol {}
