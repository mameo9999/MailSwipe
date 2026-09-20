import SwiftUI

@main
struct MailSwipeApp: App {
    @StateObject private var viewModel: MailDeckViewModel

    init() {
        let reviewedStore = UserDefaultsReviewedMailStore(accountIdentifier: "prototype")
        let service = MockMailService()
        _viewModel = StateObject(
            wrappedValue: MailDeckViewModel(
                service: service,
                reviewedStore: reviewedStore
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}

