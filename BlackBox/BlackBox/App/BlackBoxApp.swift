import SwiftUI

@main
struct BlackBoxApp: App {
    @StateObject private var coordinator = StateCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .frame(minWidth: 1100, minHeight: 750)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 850)
    }
}
