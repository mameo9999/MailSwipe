import Foundation
import Combine

@MainActor
final class MailDeckViewModel: ObservableObject {
    @Published private(set) var messages: [MailMessage] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingCurrentMessage = false
    @Published var errorMessage: String?
    @Published var attachmentPreview: AttachmentPreview?

    private let service: MailService
    private let reviewedStore: ReviewedMailStoring
    private var decisions: [SwipeDecision] = []

    init(service: MailService, reviewedStore: ReviewedMailStoring) {
        self.service = service
        self.reviewedStore = reviewedStore
    }

    var currentMessage: MailMessage? {
        guard messages.indices.contains(currentIndex) else { return nil }
        return messages[currentIndex]
    }

    var hasFinished: Bool {
        !isLoading && currentIndex >= messages.count
    }

    var canGoBack: Bool {
        currentIndex > 0
    }

    var progressText: String {
        guard !messages.isEmpty else { return "0 / 0" }
        let displayedIndex = min(currentIndex + 1, messages.count)
        return "\(displayedIndex) / \(messages.count)"
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            messages = try await service.fetchUnreadMessages(
                excluding: reviewedStore.reviewedIDs
            )
            currentIndex = 0
            decisions = []
            await loadCurrentMessageContentIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func processCurrentMessage(as decision: SwipeDecision) async {
        guard let message = currentMessage else { return }
        errorMessage = nil

        do {
            if decision == .read {
                try await service.markRead(messageID: message.id)
            }

            reviewedStore.markReviewed(message.id)

            if currentIndex < decisions.count {
                decisions[currentIndex] = decision
            } else {
                decisions.append(decision)
            }

            currentIndex += 1
            await loadCurrentMessageContentIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goBack() async {
        guard canGoBack else { return }
        errorMessage = nil

        let previousIndex = currentIndex - 1
        let message = messages[previousIndex]
        let previousDecision = decisions[previousIndex]

        do {
            if previousDecision == .read {
                try await service.markUnread(messageID: message.id)
            }

            reviewedStore.removeReviewed(message.id)
            currentIndex = previousIndex
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetReviewedHistory() async {
        reviewedStore.reset()
        await load()
    }

    func openAttachment(_ attachment: MailAttachment) async {
        guard let message = currentMessage else { return }

        do {
            let url = try await service.localURLForAttachment(
                messageID: message.id,
                attachmentID: attachment.id
            )
            attachmentPreview = AttachmentPreview(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadCurrentMessageContentIfNeeded() async {
        guard let message = currentMessage, !message.isContentLoaded else { return }
        let loadingID = message.id
        isLoadingCurrentMessage = true

        do {
            let content = try await service.loadContent(messageID: loadingID)
            guard messages.indices.contains(currentIndex), messages[currentIndex].id == loadingID else {
                isLoadingCurrentMessage = false
                return
            }
            messages[currentIndex].plainBody = content.plainBody
            messages[currentIndex].htmlBody = content.htmlBody
            messages[currentIndex].attachments = content.attachments
            messages[currentIndex].isContentLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingCurrentMessage = false
    }
}

struct AttachmentPreview: Identifiable {
    let id = UUID()
    let url: URL
}
