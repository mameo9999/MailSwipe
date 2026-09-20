import Foundation

struct MailMessage: Identifiable, Equatable, Codable {
    let id: String
    let subject: String
    let senderName: String
    let senderAddress: String
    let receivedAt: Date
    var plainBody: String
    var htmlBody: String?
    var attachments: [MailAttachment]
    var isContentLoaded: Bool

    init(
        id: String,
        subject: String,
        senderName: String,
        senderAddress: String,
        receivedAt: Date,
        plainBody: String,
        htmlBody: String?,
        attachments: [MailAttachment],
        isContentLoaded: Bool = true
    ) {
        self.id = id
        self.subject = subject
        self.senderName = senderName
        self.senderAddress = senderAddress
        self.receivedAt = receivedAt
        self.plainBody = plainBody
        self.htmlBody = htmlBody
        self.attachments = attachments
        self.isContentLoaded = isContentLoaded
    }

    var senderDisplay: String {
        senderName.isEmpty ? senderAddress : "\(senderName) <\(senderAddress)>"
    }
}

struct MailContent: Equatable {
    let plainBody: String
    let htmlBody: String?
    let attachments: [MailAttachment]
}

struct MailAccountCredentials: Codable, Equatable {
    let emailAddress: String
    let appSpecificPassword: String

    var normalizedEmailAddress: String {
        emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct MailAttachment: Identifiable, Equatable, Codable {
    let id: String
    let fileName: String
    let mimeType: String
    let sizeInBytes: Int

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .file)
    }
}

enum SwipeDecision: String, Codable, Equatable {
    case read
    case keepUnread
}
