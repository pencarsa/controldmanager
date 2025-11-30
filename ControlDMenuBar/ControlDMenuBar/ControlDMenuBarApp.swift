import SwiftUI

@main
struct ControlDMenuBarApp: App {
    @StateObject private var menuBarController = MenuBarController()
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(menuBarController)
        } label: {
            Image(systemName: menuBarController.currentStatusIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
