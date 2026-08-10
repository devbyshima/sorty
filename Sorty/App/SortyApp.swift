import SwiftUI

@main
struct SortyApp: App {
    #if DEBUG
    @State private var session = SessionModel(
        usesDemoData: DebugLaunch.usesDemoData,
        demoStall: DebugLaunch.libraryStall,
        demoTrackStall: DebugLaunch.trackStall
    )
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
