import Foundation

/// Debouncer for delaying execution of operations
final class Debouncer {
    
    // MARK: - Properties
    
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    // MARK: - Initialization
    
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    // MARK: - Debouncing
    
    /// Debounce a closure
    func debounce(action: @escaping () -> Void) {
        // Cancel previous work item
        workItem?.cancel()
        
        // Create new work item
        let newWorkItem = DispatchWorkItem(block: action)
        workItem = newWorkItem
        
        // Schedule execution
        queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
    
    /// Cancel pending debounced action
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
    
    /// Execute immediately and cancel pending
    func executeNow(action: @escaping () -> Void) {
        cancel()
        queue.async(execute: action)
    }
}

/// Throttler for limiting execution frequency
final class Throttler {
    
    // MARK: - Properties
    
    private let interval: TimeInterval
    private var lastExecutionTime: Date?
    private let queue: DispatchQueue
    
    // MARK: - Initialization
    
    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }
    
    // MARK: - Throttling
    
    /// Throttle a closure
    func throttle(action: @escaping () -> Void) {
        let now = Date()
        
        // Check if we should execute
        if let lastExecution = lastExecutionTime {
            let timeSinceLastExecution = now.timeIntervalSince(lastExecution)
            if timeSinceLastExecution < interval {
                // Too soon, skip
                return
            }
        }
        
        // Execute and update timestamp
        lastExecutionTime = now
        queue.async(execute: action)
    }
    
    /// Reset throttle state
    func reset() {
        lastExecutionTime = nil
    }
}

// MARK: - Async Support

extension Debouncer {
    /// Debounce an async operation
    @MainActor
    func debounceAsync(action: @escaping () async -> Void) {
        // Cancel previous work item
        workItem?.cancel()
        
        // Create new work item
        let newWorkItem = DispatchWorkItem {
            Task {
                await action()
            }
        }
        workItem = newWorkItem
        
        // Schedule execution
        queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
}

extension Throttler {
    /// Throttle an async operation
    @MainActor
    func throttleAsync(action: @escaping () async -> Void) {
        let now = Date()
        
        // Check if we should execute
        if let lastExecution = lastExecutionTime {
            let timeSinceLastExecution = now.timeIntervalSince(lastExecution)
            if timeSinceLastExecution < interval {
                // Too soon, skip
                return
            }
        }
        
        // Execute and update timestamp
        lastExecutionTime = now
        Task {
            await action()
        }
    }
}

// MARK: - Actor-based Debouncer (Thread-safe)

actor AsyncDebouncer {
    private let delay: TimeInterval
    private var task: Task<Void, Never>?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () async -> Void) {
        // Cancel previous task
        task?.cancel()
        
        // Create new task
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Check if not cancelled
            guard !Task.isCancelled else { return }
            
            await action()
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

