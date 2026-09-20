import SwiftUI

@main
struct MailSwipeApp: App {
    @StateObject private var appModel = MailSwipeAppModel()

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
        }
    }
}
