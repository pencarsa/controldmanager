import SwiftUI

@main
struct ControlDMenuBarApp: App {
    @StateObject private var menuBarController = MenuBarController()
    
    var body: some Scene {
        MenuBarExtra("ControlD", systemImage: menuBarController.currentStatusIcon) {
            ContentView()
                .environmentObject(menuBarController)
        }
        .menuBarExtraStyle(.window)
    }
}
