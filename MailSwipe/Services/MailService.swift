import Foundation

@MainActor
protocol MailService {
    func validateAccount() async throws
    func fetchUnreadMessages(excluding reviewedIDs: Set<String>) async throws -> [MailMessage]
    func loadContent(messageID: String) async throws -> MailContent
    func markRead(messageID: String) async throws
    func markUnread(messageID: String) async throws
    func localURLForAttachment(messageID: String, attachmentID: String) async throws -> URL
}

enum MailServiceError: LocalizedError {
    case attachmentUnavailable
    case invalidMessage
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .attachmentUnavailable:
            return "画面試作では添付ファイルをまだダウンロードできません。"
        case .invalidMessage:
            return "メールの情報を読み取れませんでした。もう一度読み込み直してください。"
        case .connectionFailed(let detail):
            return "iCloudメールに接続できませんでした。メールアドレスとアプリ用パスワードを確認してください。\n\n\(detail)"
        }
    }
}

@MainActor
final class MockMailService: MailService {
    private(set) var readMessageIDs: Set<String> = []

    private let messages: [MailMessage] = [
        MailMessage(
            id: "prototype:101",
            subject: "ゼミの日程について",
            senderName: "山田先生",
            senderAddress: "yamada@example.com",
            receivedAt: ISO8601DateFormatter().date(from: "2026-09-18T01:30:00Z")!,
            plainBody: "次回のゼミは9月22日（火）13時から行います。資料を事前に共有してください。",
            htmlBody: nil,
            attachments: []
        ),
        MailMessage(
            id: "prototype:102",
            subject: "インターンシップ参加のお礼",
            senderName: "採用担当",
            senderAddress: "recruit@example.co.jp",
            receivedAt: ISO8601DateFormatter().date(from: "2026-09-18T07:15:00Z")!,
            plainBody: "先日は弊社インターンシップへご参加いただき、ありがとうございました。アンケートへのご協力をお願いいたします。",
            htmlBody: """
            <h2>ご参加ありがとうございました</h2>
            <p>先日は弊社インターンシップへご参加いただき、ありがとうございました。</p>
            <p>アンケートへのご協力をお願いいたします。</p>
            <img src="https://example.com/tracking/sample.png" alt="会社ロゴ">
            """,
            attachments: []
        ),
        MailMessage(
            id: "prototype:103",
            subject: "発表資料の確認依頼",
            senderName: "研究室メンバー",
            senderAddress: "member@example.ac.jp",
            receivedAt: ISO8601DateFormatter().date(from: "2026-09-19T03:00:00Z")!,
            plainBody: "発表資料を添付しました。内容の確認をお願いします。",
            htmlBody: nil,
            attachments: [
                MailAttachment(
                    id: "attachment:1",
                    fileName: "発表資料.pdf",
                    mimeType: "application/pdf",
                    sizeInBytes: 824_000
                )
            ]
        )
    ]

    func validateAccount() async throws {}

    func fetchUnreadMessages(excluding reviewedIDs: Set<String>) async throws -> [MailMessage] {
        messages
            .filter { !readMessageIDs.contains($0.id) && !reviewedIDs.contains($0.id) }
            .sorted { $0.receivedAt < $1.receivedAt }
    }

    func loadContent(messageID: String) async throws -> MailContent {
        guard let message = messages.first(where: { $0.id == messageID }) else {
            throw MailServiceError.invalidMessage
        }

        return MailContent(
            plainBody: message.plainBody,
            htmlBody: message.htmlBody,
            attachments: message.attachments
        )
    }

    func markRead(messageID: String) async throws {
        readMessageIDs.insert(messageID)
    }

    func markUnread(messageID: String) async throws {
        readMessageIDs.remove(messageID)
    }

    func localURLForAttachment(messageID: String, attachmentID: String) async throws -> URL {
        throw MailServiceError.attachmentUnavailable
    }
}
