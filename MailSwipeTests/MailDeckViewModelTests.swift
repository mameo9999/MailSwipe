import XCTest
@testable import MailSwipe

@MainActor
final class MailDeckViewModelTests: XCTestCase {
    func testLeftSwipeMarksReviewedButKeepsUnread() async throws {
        let service = MockMailService()
        let store = InMemoryReviewedMailStore()
        let viewModel = MailDeckViewModel(service: service, reviewedStore: store)

        await viewModel.load()
        let firstID = try XCTUnwrap(viewModel.currentMessage?.id)

        await viewModel.processCurrentMessage(as: .keepUnread)

        XCTAssertTrue(store.reviewedIDs.contains(firstID))
        XCTAssertFalse(service.readMessageIDs.contains(firstID))
        XCTAssertEqual(viewModel.currentIndex, 1)
    }

    func testRightSwipeAndDownSwipeRestoreUnreadMessage() async throws {
        let service = MockMailService()
        let store = InMemoryReviewedMailStore()
        let viewModel = MailDeckViewModel(service: service, reviewedStore: store)

        await viewModel.load()
        let firstID = try XCTUnwrap(viewModel.currentMessage?.id)

        await viewModel.processCurrentMessage(as: .read)
        XCTAssertTrue(service.readMessageIDs.contains(firstID))

        await viewModel.goBack()

        XCTAssertEqual(viewModel.currentMessage?.id, firstID)
        XCTAssertFalse(service.readMessageIDs.contains(firstID))
        XCTAssertFalse(store.reviewedIDs.contains(firstID))
    }

    func testRepeatedDownSwipesCanWalkBackThroughSession() async throws {
        let service = MockMailService()
        let store = InMemoryReviewedMailStore()
        let viewModel = MailDeckViewModel(service: service, reviewedStore: store)

        await viewModel.load()
        let firstID = try XCTUnwrap(viewModel.currentMessage?.id)
        await viewModel.processCurrentMessage(as: .keepUnread)
        let secondID = try XCTUnwrap(viewModel.currentMessage?.id)
        await viewModel.processCurrentMessage(as: .keepUnread)

        await viewModel.goBack()
        XCTAssertEqual(viewModel.currentMessage?.id, secondID)

        await viewModel.goBack()
        XCTAssertEqual(viewModel.currentMessage?.id, firstID)
        XCTAssertFalse(viewModel.canGoBack)
    }

    func testPreviouslyReviewedUnreadMailIsExcludedOnNextLoad() async throws {
        let service = MockMailService()
        let store = InMemoryReviewedMailStore(reviewedIDs: ["prototype:101"])
        let viewModel = MailDeckViewModel(service: service, reviewedStore: store)

        await viewModel.load()

        XCTAssertEqual(viewModel.currentMessage?.id, "prototype:102")
        XCTAssertFalse(viewModel.messages.map(\.id).contains("prototype:101"))
    }
}

