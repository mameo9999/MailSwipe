import SwiftUI

struct RootView: View {
    @ObservedObject var appModel: MailSwipeAppModel

    var body: some View {
        Group {
            if let deckViewModel = appModel.deckViewModel {
                ContentView(
                    viewModel: deckViewModel,
                    onDisconnect: appModel.disconnect
                )
            } else {
                AccountSetupView(appModel: appModel)
            }
        }
    }
}
