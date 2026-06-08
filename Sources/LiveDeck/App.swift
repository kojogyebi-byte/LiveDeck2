import SwiftUI

@main
struct LiveDeckApp: App {
    @StateObject private var engine = Engine()

    var body: some Scene {
        WindowGroup("LiveDeck Studio") {
            MainView()
                .environmentObject(engine)
                .frame(minWidth: 1100, minHeight: 640)
                .onAppear { engine.start() }
        }
        .windowStyle(.titleBar)
    }
}
