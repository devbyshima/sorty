import SwiftUI

@main
struct SortyApp: App {
    #if DEBUG
    @State private var session = SessionModel(usesDemoData: DebugLaunch.usesDemoData)
    #else
    @State private var session = SessionModel()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
