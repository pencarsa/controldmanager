import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var menuBarController: MenuBarController
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var isLoading = false
    @State private var lastActionStatus: String = "Ready"
    @State private var showStatus = false
    @State private var profileStatus: String = "Unknown"
    @State private var showingSettings = false
    @State private var settingsWindow: NSWindow?
    @State private var windowDelegate: WindowDelegate?
    
    // Enhanced features - removed timer options, using fixed 30-minute disable duration
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced header with dynamic icon
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .animation(.easeInOut(duration: 0.3), value: profileStatus)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ControlD Manager")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Network status indicator
                HStack(spacing: 4) {
                    if networkMonitor.status.isConnected {
                        Image(systemName: "wifi")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Online")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Offline")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(4)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                if menuBarController.needsConfiguration {
                    configurationRequiredView
                } else {
                    profileStatusView
                }
            }
            
            Divider()
            
            // Quick actions section
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                    quickActionButton("Settings", icon: "gear.fill", color: .gray) {
                        showingSettings = true
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Quit ControlD") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .font(.caption)
                
                Spacer()
                
                Text("Enhanced v2.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            checkProfileStatus()
        }
        .onChange(of: showingSettings) { newValue in
            if newValue {
                showSettingsWindow()
            }
        }
    }
    
    // MARK: - Enhanced View Components
    
    private var configurationRequiredView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration Required")
                .font(.subheadline)
                .foregroundColor(.orange)
            
            Button(action: {
                showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gear.fill")
                    Text("Configure Settings")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var profileStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profile Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if profileStatus == "Disabled" {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text("Disabled")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)
                }
            }
            
            Text(statusDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Main action button
            mainActionButton
        }
    }
    
    
    private var mainActionButton: some View {
        Button(action: {
            performMainAction()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: mainActionIcon)
                }
                Text(mainActionText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
    
    private func quickActionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch profileStatus {
        case "Disabled":
            return "shield.fill"
        case "Enabled":
            return "shield"
        case "Error":
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch profileStatus {
        case "Disabled":
            return .red
        case "Enabled":
            return .green
        case "Error":
            return .orange
        default:
            return .gray
        }
    }
    
    private var statusSubtitle: String {
        if !networkMonitor.status.isConnected {
            return "Network Offline"
        } else if menuBarController.needsConfiguration {
            return "Setup required"
        } else {
            return "\(menuBarController.settingsManager.selectedProfileName) • Online"
        }
    }
    
    private var statusDescription: String {
        if menuBarController.needsConfiguration {
            return "Please configure your API key and select a profile"
        } else {
            return profileStatus == "Disabled" ?
                "Profile is currently disabled" :
                "Ready to disable profile"
        }
    }
    
    private var mainActionText: String {
        if isLoading {
            return profileStatus == "Disabled" ? "Re-enabling..." : "Disabling..."
        } else {
            return profileStatus == "Disabled" ? "Re-enable Profile" : "Disable Profile (30 min)"
        }
    }
    
    private var mainActionIcon: String {
        return profileStatus == "Disabled" ? "play.fill" : "clock.fill"
    }
    
    // MARK: - Enhanced Actions
    
    private func performMainAction() {
        if profileStatus == "Disabled" {
            reEnableProfile()
        } else {
            disableProfile()
        }
    }
    
    private func disableProfile() {
        isLoading = true
        showStatus = false
        
        Task {
            do {
                let success = try await menuBarController.disableEndpoint()
                
                if success {
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Success: Profile disabled for 30 minutes"
                        profileStatus = "Disabled"
                        showStatus = true
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Failed: Could not disable profile"
                        showStatus = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    lastActionStatus = "Error: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }
    
    private func reEnableProfile() {
        isLoading = true
        showStatus = false
        
        Task {
            do {
                let success = try await menuBarController.disableEndpoint() // This toggles
                
                if success {
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Success: Profile re-enabled"
                        profileStatus = "Enabled"
                        showStatus = true
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Failed: Could not re-enable profile"
                        showStatus = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    lastActionStatus = "Error: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }
    
    
    private func checkProfileStatus() {
        Task {
            do {
                let status = try await menuBarController.getProfileStatus()
                await MainActor.run {
                    profileStatus = status
                }
            } catch {
                print("Failed to check profile status: \(error)")
                await MainActor.run {
                    profileStatus = "Error"
                    lastActionStatus = "Error: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }
    
    private func showSettingsWindow() {
        // Don't open multiple settings windows
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Close the MenuBarExtra popover
        closeMenuBarPopover()
        
        let settingsView = SettingsView(settingsManager: menuBarController.settingsManager, menuBarController: menuBarController)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ControlD Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.setFrame(NSRect(x: 0, y: 0, width: 500, height: 700), display: false)
        window.minSize = NSSize(width: 450, height: 600)
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        // Store strong references to prevent deallocation
        settingsWindow = window
        windowDelegate = WindowDelegate {
            showingSettings = false
            settingsWindow = nil
            windowDelegate = nil
            // Refresh data when settings window closes
            Task { await menuBarController.checkConnection() }
            checkProfileStatus()
        }
        window.delegate = windowDelegate
    }
    
    private func closeMenuBarPopover() {
        // Try multiple approaches to close the MenuBarExtra popover
        DispatchQueue.main.async {
            // Method 1: Look for MenuBarExtra specific windows
            for window in NSApplication.shared.windows {
                let className = window.className
                if className.contains("MenuBarExtra") ||
                   className.contains("Popover") ||
                   className.contains("MenuBarWindow") ||
                   (window.level == .popUpMenu && window.styleMask.contains(.borderless)) ||
                   (window.level == .statusBar) {
                    window.orderOut(nil)
                    print("Closed window: \(className)")
                }
            }
            
            // Method 2: Try to deactivate the app momentarily
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let frontmostApp = NSWorkspace.shared.frontmostApplication,
                   frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                    // Another app is already frontmost, good
                    return
                }
                
                // Try to hide the app briefly to dismiss MenuBar popover
                NSApplication.shared.hide(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApplication.shared.unhide(nil)
                }
            }
        }
    }
}

// Helper class for window delegate
class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

#Preview {
    ContentView()
        .environmentObject(MenuBarController())
}