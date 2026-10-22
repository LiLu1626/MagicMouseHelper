import SwiftUI

@main
struct MagicMouseHelperApp: App {
    @StateObject private var engine = MouseEngine()

    var body: some Scene {
        Window("MagicMouseHelper 设置", id: "settings") {
            ContentView(engine: engine)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("MagicMouseHelper", systemImage: "computermouse") {
            ContentView(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}
