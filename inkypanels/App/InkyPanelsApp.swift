import SwiftUI
import SwiftData

@main
struct InkyPanelsApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ProgressRecord.self)
    }
}
