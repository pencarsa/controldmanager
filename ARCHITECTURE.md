# Architecture

## Current State

**Active**: Legacy architecture (MenuBarController → ControlDService + SettingsManager)  
**Available**: Modern DI architecture in Services/ (unused)

## New Utilities

**Error Handling**
- `Core/AppError.swift` - Unified errors with recovery actions
- `Core/RetryPolicy.swift` - Exponential backoff

**Performance**
- `Core/APICache.swift` - Thread-safe caching with TTL
- `Core/Debouncer.swift` - Debouncing/throttling
- `Core/BackgroundRefreshService.swift` - Auto-refresh

**Security**
- `Core/SecureMemory.swift` - Secure string handling
- `Core/AuditLogger.swift` - Security event logging
- `Core/BiometricAuthService.swift` - Face ID/Touch ID

**Monitoring**
- `Core/NetworkMonitor.swift` - Network connectivity

**Testing**
- `ControlDMenuBarTests/*` - Unit tests

## Testing

```bash
xcodebuild test -project ControlDMenuBar.xcodeproj -scheme ControlDMenuBar
```

