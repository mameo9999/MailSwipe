import Foundation

@MainActor
final class MailSwipeAppModel: ObservableObject {
    @Published private(set) var deckViewModel: MailDeckViewModel?
    @Published private(set) var isConnecting = false
    @Published var setupErrorMessage: String?

    private let credentialStore: CredentialStoring

    init(credentialStore: CredentialStoring = KeychainCredentialStore()) {
        self.credentialStore = credentialStore

        if let credentials = try? credentialStore.load() {
            configureAccount(credentials)
        }
    }

    func connect(emailAddress: String, appSpecificPassword: String) async {
        let credentials = MailAccountCredentials(
            emailAddress: emailAddress,
            appSpecificPassword: appSpecificPassword
        )

        guard credentials.normalizedEmailAddress.contains("@"),
              !credentials.appSpecificPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setupErrorMessage = "iCloudメールアドレスとアプリ用パスワードを入力してください。"
            return
        }

        isConnecting = true
        setupErrorMessage = nil

        do {
            let service = IMAPMailService(credentials: credentials)
            try await service.validateAccount()
            try credentialStore.save(credentials)
            configureAccount(credentials, service: service)
        } catch {
            setupErrorMessage = error.localizedDescription
        }

        isConnecting = false
    }

    func disconnect() {
        do {
            try credentialStore.clear()
            deckViewModel = nil
        } catch {
            setupErrorMessage = error.localizedDescription
        }
    }

    private func configureAccount(
        _ credentials: MailAccountCredentials,
        service: MailService? = nil
    ) {
        let resolvedService = service ?? IMAPMailService(credentials: credentials)
        let reviewedStore = UserDefaultsReviewedMailStore(
            accountIdentifier: credentials.normalizedEmailAddress
        )
        deckViewModel = MailDeckViewModel(
            service: resolvedService,
            reviewedStore: reviewedStore
        )
    }
}
