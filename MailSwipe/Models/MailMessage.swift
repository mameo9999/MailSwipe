import Foundation

struct MailMessage: Identifiable, Equatable, Codable {
    let id: String
    let subject: String
    let senderName: String
    let senderAddress: String
    let receivedAt: Date
    let plainBody: String
    let htmlBody: String?
    let attachments: [MailAttachment]

    var senderDisplay: String {
        senderName.isEmpty ? senderAddress : "\(senderName) <\(senderAddress)>"
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

