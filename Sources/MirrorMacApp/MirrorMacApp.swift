import SwiftUI

@main
struct MirrorMacApp: App {
    var body: some Scene {
        WindowGroup("Mirror Mac") {
            ContentView()
        }
        .windowResizability(.contentSize)

        Settings {
            Text("Mirror Mac")
                .padding()
        }
    }
}
