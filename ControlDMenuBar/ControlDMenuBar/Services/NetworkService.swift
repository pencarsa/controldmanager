import Foundation

/// Network service for handling HTTP requests
final class NetworkService {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let configuration: ConfigurationServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    init(configuration: ConfigurationServiceProtocol = ConfigurationService.shared,
         logger: LoggerProtocol = LoggingService.shared,
         session: URLSession? = nil) {
        self.configuration = configuration
        self.logger = logger
        
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = configuration.defaultTimeout
            config.timeoutIntervalForResource = configuration.defaultTimeout
            self.session = URLSession(configuration: config)
        }
    }
    
    // MARK: - Request Methods
    
    func performRequest<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        apiKey: String? = nil
    ) async throws -> T {
        let startTime = Date()
        
        guard let url = URL(string: configuration.apiBaseURL + endpoint.path) else {
            throw AppError.networkError("Invalid URL: \(configuration.apiBaseURL + endpoint.path)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication if provided
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body if needed
        if let body = endpoint.body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw AppError.networkError("Failed to serialize request body: \(error.localizedDescription)")
            }
        }
        
        logger.logNetworkRequest(url: url.absoluteString, method: endpoint.method.rawValue)
        
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkError("Invalid response type")
            }
            
            logger.logNetworkResponse(url: url.absoluteString, 
                                    statusCode: httpResponse.statusCode, 
                                    duration: duration)
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - parse response
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(responseType, from: data)
                    return result
                } catch {
                    logger.error("Failed to decode response: \(error)")
                    throw AppError.apiError("Failed to decode response: \(error.localizedDescription)", 
                                          statusCode: httpResponse.statusCode)
                }
                
            case 401:
                throw AppError.invalidApiKey
                
            case 404:
                throw AppError.profileNotFound
                
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AppError.apiError(errorMessage, statusCode: httpResponse.statusCode)
            }
            
        } catch let error as AppError {
            logger.logNetworkError(url: url.absoluteString, error: error)
            throw error
        } catch {
            logger.logNetworkError(url: url.absoluteString, error: error)
            throw AppError.networkError(error.localizedDescription)
        }
    }
    
    /// Validate connection by making a simple request
    func validateConnection(apiKey: String) async throws -> Bool {
        let endpoint = APIEndpoint.getProfiles
        let _: ProfilesResponse = try await performRequest(endpoint: endpoint, 
                                                          responseType: ProfilesResponse.self, 
                                                          apiKey: apiKey)
        return true
    }
}

// MARK: - API Endpoints

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: [String: Any]?
    
    init(path: String, method: HTTPMethod, body: [String: Any]? = nil) {
        self.path = path
        self.method = method
        self.body = body
    }
    
    // MARK: - Predefined Endpoints
    
    static let getProfiles = APIEndpoint(path: "/profiles", method: .GET)
    
    static func updateProfile(id: String, disableTTL: Int) -> APIEndpoint {
        return APIEndpoint(
            path: "/profiles/\(id)",
            method: .PUT,
            body: ["disable_ttl": disableTTL]
        )
    }
}

// MARK: - Response Models

struct ProfilesResponse: Codable {
    let body: ProfilesBody
}

struct ProfilesBody: Codable {
    let profiles: [ProfileData]
}

struct ProfileData: Codable {
    let PK: String
    let name: String
    let updated: Int
    let disable_ttl: Int?
}

// MARK: - NetworkService + APIServiceProtocol

extension NetworkService: APIServiceProtocol {
    
    func validateConnection() async throws -> Bool {
        // This would need an API key from settings
        // Implementation will be handled by the main API service
        throw AppError.configurationMissing
    }
    
    func validateApiKey(_ apiKey: String) async throws -> Bool {
        return try await validateConnection(apiKey: apiKey)
    }
    
    func fetchAllProfiles() async throws -> [Profile] {
        // This would need an API key from settings
        // Implementation will be handled by the main API service
        throw AppError.configurationMissing
    }
    
    func getProfileStatus(profileId: String) async throws -> ProfileStatus {
        // Implementation will be handled by the main API service
        throw AppError.configurationMissing
    }
    
    func toggleProfileDisable(profileId: String) async throws -> Bool {
        // Implementation will be handled by the main API service
        throw AppError.configurationMissing
    }
}
