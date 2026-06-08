import SwiftUI

@main
struct LiveDeckApp: App {
    @StateObject private var engine = Engine()

    var body: some Scene {
        WindowGroup("LiveDeck Studio") {
            MainView()
                .environmentObject(engine)
                .frame(minWidth: 1280, minHeight: 760)
                .onAppear { engine.start() }
        }
        .windowStyle(.titleBar)
    }
}
