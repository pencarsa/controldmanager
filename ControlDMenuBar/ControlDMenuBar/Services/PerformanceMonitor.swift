import Foundation
import os.log

/// Service for monitoring application performance and collecting metrics
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    // MARK: - Properties
    
    private var metrics: [String: MetricCollection] = [:]
    private let maxSamples = 100
    private let slowOperationThreshold: TimeInterval = 0.1 // 100ms
    private let logger = Logger(subsystem: "com.example.controld", category: "Performance")
    
    // MARK: - Data Models
    
    private struct MetricCollection {
        var samples: [TimeInterval] = []
        var totalExecutions: Int = 0
        var slowExecutions: Int = 0
        var lastExecution: Date = Date()
        
        var averageTime: TimeInterval {
            guard !samples.isEmpty else { return 0 }
            return samples.reduce(0, +) / Double(samples.count)
        }
        
        var minTime: TimeInterval {
            return samples.min() ?? 0
        }
        
        var maxTime: TimeInterval {
            return samples.max() ?? 0
        }
        
        var slowExecutionPercentage: Double {
            guard totalExecutions > 0 else { return 0 }
            return Double(slowExecutions) / Double(totalExecutions) * 100
        }
    }
    
    struct PerformanceReport {
        let operation: String
        let averageTime: TimeInterval
        let minTime: TimeInterval
        let maxTime: TimeInterval
        let totalExecutions: Int
        let slowExecutions: Int
        let slowExecutionPercentage: Double
        let lastExecution: Date
        
        var formattedAverageTime: String {
            return String(format: "%.3f ms", averageTime * 1000)
        }
        
        var formattedMinTime: String {
            return String(format: "%.3f ms", minTime * 1000)
        }
        
        var formattedMaxTime: String {
            return String(format: "%.3f ms", maxTime * 1000)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("PerformanceMonitor initialized")
        startPeriodicReporting()
    }
    
    // MARK: - Performance Measurement
    
    /// Measures execution time of a synchronous operation
    func measureExecutionTime<T>(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        recordMetric(
            operation: operation,
            time: timeElapsed,
            file: file,
            function: function,
            line: line
        )
        
        return result
    }
    
    /// Measures execution time of an async operation
    func measureExecutionTime<T>(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        recordMetric(
            operation: operation,
            time: timeElapsed,
            file: file,
            function: function,
            line: line
        )
        
        return result
    }
    
    /// Records a custom metric
    func recordCustomMetric(operation: String, time: TimeInterval) {
        recordMetric(operation: operation, time: time)
    }
    
    // MARK: - Memory Monitoring
    
    /// Gets current memory usage in MB
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0
        }
    }
    
    /// Records memory usage for monitoring
    func recordMemoryUsage(context: String = "general") {
        let memoryUsage = getCurrentMemoryUsage()
        recordCustomMetric(operation: "memory_usage_\(context)", time: memoryUsage)
        
        if memoryUsage > 100 { // Alert if over 100MB
            logger.warning("High memory usage detected: \(String(format: "%.2f", memoryUsage)) MB in context: \(context)")
        }
    }
    
    // MARK: - Reporting
    
    /// Gets performance report for a specific operation
    func getReport(for operation: String) -> PerformanceReport? {
        guard let collection = metrics[operation] else { return nil }
        
        return PerformanceReport(
            operation: operation,
            averageTime: collection.averageTime,
            minTime: collection.minTime,
            maxTime: collection.maxTime,
            totalExecutions: collection.totalExecutions,
            slowExecutions: collection.slowExecutions,
            slowExecutionPercentage: collection.slowExecutionPercentage,
            lastExecution: collection.lastExecution
        )
    }
    
    /// Gets all performance reports
    func getAllReports() -> [PerformanceReport] {
        return metrics.compactMap { (operation, _) in
            getReport(for: operation)
        }.sorted { $0.averageTime > $1.averageTime }
    }
    
    /// Gets summary of performance metrics
    func getPerformanceSummary() -> String {
        let reports = getAllReports()
        let totalOperations = reports.reduce(0) { $0 + $1.totalExecutions }
        let slowOperations = reports.reduce(0) { $0 + $1.slowExecutions }
        let currentMemory = getCurrentMemoryUsage()
        
        var summary = """
        📊 Performance Summary
        =====================
        Total Operations: \(totalOperations)
        Slow Operations: \(slowOperations) (\(String(format: "%.1f", Double(slowOperations) / Double(max(totalOperations, 1)) * 100))%)
        Current Memory: \(String(format: "%.2f", currentMemory)) MB
        
        Top 5 Slowest Operations:
        """
        
        for (index, report) in reports.prefix(5).enumerated() {
            summary += "\n\(index + 1). \(report.operation): \(report.formattedAverageTime) avg (\(report.totalExecutions) executions)"
        }
        
        return summary
    }
    
    // MARK: - Private Methods
    
    private func recordMetric(
        operation: String,
        time: TimeInterval,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Initialize collection if needed
        if metrics[operation] == nil {
            metrics[operation] = MetricCollection()
        }
        
        // Update metrics
        metrics[operation]!.samples.append(time)
        metrics[operation]!.totalExecutions += 1
        metrics[operation]!.lastExecution = Date()
        
        // Track slow operations
        if time > slowOperationThreshold {
            metrics[operation]!.slowExecutions += 1
            
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            logger.warning("⚠️ Slow operation: \(operation) took \(String(format: "%.3f", time * 1000))ms at \(fileName):\(line) in \(function)")
        }
        
        // Keep only recent samples
        if metrics[operation]!.samples.count > maxSamples {
            metrics[operation]!.samples.removeFirst()
        }
        
        // Log debug info for very slow operations
        if time > 1.0 { // 1 second
            logger.error("🚨 Very slow operation: \(operation) took \(String(format: "%.3f", time))s")
        }
    }
    
    private func startPeriodicReporting() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.generatePeriodicReport()
        }
    }
    
    private func generatePeriodicReport() {
        let summary = getPerformanceSummary()
        logger.info("Periodic Performance Report:\n\(summary)")
        
        // Record current memory usage
        recordMemoryUsage(context: "periodic_check")
    }
    
    // MARK: - Cleanup
    
    /// Clears all performance metrics
    func clearMetrics() {
        metrics.removeAll()
        logger.info("Performance metrics cleared")
    }
    
    /// Clears metrics for a specific operation
    func clearMetrics(for operation: String) {
        metrics.removeValue(forKey: operation)
        logger.info("Performance metrics cleared for operation: \(operation)")
    }
}

// MARK: - Convenience Extensions

extension PerformanceMonitor {
    
    /// Measures network request performance
    func measureNetworkRequest<T>(
        endpoint: String,
        block: () async throws -> T
    ) async rethrows -> T {
        return try await measureExecutionTime(operation: "network_request_\(endpoint)") {
            return try await block()
        }
    }
    
    /// Measures UI operation performance
    func measureUIOperation<T>(
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        return try measureExecutionTime(operation: "ui_\(operation)") {
            return try block()
        }
    }
    
    /// Measures database operation performance
    func measureDatabaseOperation<T>(
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        return try measureExecutionTime(operation: "db_\(operation)") {
            return try block()
        }
    }
}

// MARK: - Performance Macros

/// Convenience function for measuring performance with minimal syntax
func withPerformanceMonitoring<T>(
    _ operation: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    block: () throws -> T
) rethrows -> T {
    return try PerformanceMonitor.shared.measureExecutionTime(
        operation: operation,
        file: file,
        function: function,
        line: line,
        block: block
    )
}

/// Convenience function for measuring async performance
func withPerformanceMonitoring<T>(
    _ operation: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    block: () async throws -> T
) async rethrows -> T {
    return try await PerformanceMonitor.shared.measureExecutionTime(
        operation: operation,
        file: file,
        function: function,
        line: line,
        block: block
    )
}