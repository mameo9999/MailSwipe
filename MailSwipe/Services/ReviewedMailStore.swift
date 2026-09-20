import Foundation

protocol ReviewedMailStoring {
    var reviewedIDs: Set<String> { get }
    func markReviewed(_ messageID: String)
    func removeReviewed(_ messageID: String)
    func reset()
}

final class UserDefaultsReviewedMailStore: ReviewedMailStoring {
    private let defaults: UserDefaults
    private let key: String

    init(accountIdentifier: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.key = "reviewed-mail-ids.\(accountIdentifier)"
    }

    var reviewedIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func markReviewed(_ messageID: String) {
        var ids = reviewedIDs
        ids.insert(messageID)
        defaults.set(Array(ids).sorted(), forKey: key)
    }

    func removeReviewed(_ messageID: String) {
        var ids = reviewedIDs
        ids.remove(messageID)
        defaults.set(Array(ids).sorted(), forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}

final class InMemoryReviewedMailStore: ReviewedMailStoring {
    private(set) var reviewedIDs: Set<String>

    init(reviewedIDs: Set<String> = []) {
        self.reviewedIDs = reviewedIDs
    }

    func markReviewed(_ messageID: String) {
        reviewedIDs.insert(messageID)
    }

    func removeReviewed(_ messageID: String) {
        reviewedIDs.remove(messageID)
    }

    func reset() {
        reviewedIDs.removeAll()
    }
}

