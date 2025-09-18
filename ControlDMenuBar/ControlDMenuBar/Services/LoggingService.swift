import Foundation
import os.log

/// Structured logging service for the application
final class LoggingService: LoggerProtocol {
    
    // MARK: - Singleton
    
    static let shared = LoggingService()
    
    private let logger: Logger
    private let configuration: ConfigurationServiceProtocol
    
    // MARK: - Initialization
    
    init(configuration: ConfigurationServiceProtocol = ConfigurationService.shared) {
        self.configuration = configuration
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.controld.menubar", 
                           category: "ControlD")
    }
    
    // MARK: - LoggerProtocol
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard configuration.isDebugMode else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        logger.debug("\(logMessage)")
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        logger.info("\(logMessage)")
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        logger.warning("\(logMessage)")
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        logger.error("\(logMessage)")
    }
    
    // MARK: - Convenience Methods
    
    func logNetworkRequest(url: String, method: String) {
        guard configuration.shouldLogNetworkRequests else { return }
        debug("🌐 \(method) \(url)")
    }
    
    func logNetworkResponse(url: String, statusCode: Int, duration: TimeInterval) {
        guard configuration.shouldLogNetworkRequests else { return }
        debug("🌐 ← \(statusCode) \(url) (\(String(format: "%.2f", duration))s)")
    }
    
    func logNetworkError(url: String, error: Error) {
        self.error("🌐 ✗ \(url) - \(error.localizedDescription)")
    }
    
    func logUserAction(_ action: String) {
        info("👤 User action: \(action)")
    }
    
    func logStateChange(from oldState: String, to newState: String) {
        info("🔄 State change: \(oldState) → \(newState)")
    }
}
