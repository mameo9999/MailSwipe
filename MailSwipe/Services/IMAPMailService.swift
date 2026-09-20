import Foundation
import MailCore

@MainActor
final class IMAPMailService: MailService {
    private struct AttachmentSource {
        let uid: UInt32
        let partID: String
        let encoding: MCOEncoding
    }

    private let folder = "INBOX"
    private let session: MCOIMAPSession
    private var sourceMessages: [String: MCOIMAPMessage] = [:]
    private var attachmentSources: [String: AttachmentSource] = [:]

    init(credentials: MailAccountCredentials) {
        let session = MCOIMAPSession()
        session.hostname = "imap.mail.me.com"
        session.port = 993
        session.username = credentials.normalizedEmailAddress
        session.password = credentials.appSpecificPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        session.connectionType = .TLS
        session.isCheckCertificateEnabled = true
        session.timeout = 30
        self.session = session
    }

    func validateAccount() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = session.checkAccountOperation()
            operation?.start { error in
                if let error {
                    continuation.resume(throwing: MailServiceError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func fetchUnreadMessages(excluding reviewedIDs: Set<String>) async throws -> [MailMessage] {
        let unreadUIDs = try await searchUnreadUIDs()
        guard unreadUIDs.count() > 0 else {
            sourceMessages = [:]
            attachmentSources = [:]
            return []
        }

        let source = try await fetchMessages(uids: unreadUIDs)
        sourceMessages = [:]
        attachmentSources = [:]

        return source.compactMap { message in
            let id = messageIdentifier(uid: message.uid)
            guard !reviewedIDs.contains(id) else { return nil }
            sourceMessages[id] = message

            let attachments = message.attachments().compactMap { part -> MailAttachment? in
                guard let imapPart = part as? MCOIMAPPart,
                      let partID = imapPart.partID,
                      !partID.isEmpty else {
                    return nil
                }

                let attachmentID = "\(id):\(partID)"
                attachmentSources[attachmentID] = AttachmentSource(
                    uid: message.uid,
                    partID: partID,
                    encoding: imapPart.encoding
                )

                return MailAttachment(
                    id: attachmentID,
                    fileName: imapPart.filename ?? "添付ファイル",
                    mimeType: imapPart.mimeType ?? "application/octet-stream",
                    sizeInBytes: Int(imapPart.decodedSize())
                )
            }

            let sender = message.header.from ?? message.header.sender
            return MailMessage(
                id: id,
                subject: nonEmpty(message.header.subject, fallback: "（件名なし）"),
                senderName: sender?.displayName ?? "",
                senderAddress: sender?.mailbox ?? "",
                receivedAt: message.header.receivedDate ?? message.header.date ?? .distantPast,
                plainBody: "",
                htmlBody: nil,
                attachments: attachments,
                isContentLoaded: false
            )
        }
        .sorted { $0.receivedAt < $1.receivedAt }
    }

    func loadContent(messageID: String) async throws -> MailContent {
        guard let message = sourceMessages[messageID] else {
            throw MailServiceError.invalidMessage
        }

        let html = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let operation = session.htmlRenderingOperation(with: message, folder: folder)
            operation?.start { html, error in
                if let error {
                    continuation.resume(throwing: MailServiceError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: html ?? "")
                }
            }
        }

        return MailContent(
            plainBody: html.isEmpty ? "本文を表示できませんでした。" : "",
            htmlBody: html.isEmpty ? nil : html,
            attachments: sourceMessages[messageID]?.attachments().compactMap { part in
                guard let imapPart = part as? MCOIMAPPart,
                      let partID = imapPart.partID else { return nil }
                let attachmentID = "\(messageID):\(partID)"
                return MailAttachment(
                    id: attachmentID,
                    fileName: imapPart.filename ?? "添付ファイル",
                    mimeType: imapPart.mimeType ?? "application/octet-stream",
                    sizeInBytes: Int(imapPart.decodedSize())
                )
            } ?? []
        )
    }

    func markRead(messageID: String) async throws {
        try await updateSeenFlag(messageID: messageID, kind: .add)
    }

    func markUnread(messageID: String) async throws {
        try await updateSeenFlag(messageID: messageID, kind: .remove)
    }

    func localURLForAttachment(messageID: String, attachmentID: String) async throws -> URL {
        guard let source = attachmentSources[attachmentID] else {
            throw MailServiceError.attachmentUnavailable
        }

        let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let operation = session.fetchMessageAttachmentOperation(
                withFolder: folder,
                uid: source.uid,
                partID: source.partID,
                encoding: source.encoding
            )
            operation?.start { error, data in
                if let error {
                    continuation.resume(throwing: MailServiceError.connectionFailed(error.localizedDescription))
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: MailServiceError.attachmentUnavailable)
                }
            }
        }

        let matchingPart = sourceMessages[messageID]?
            .attachments()
            .first(where: { ($0 as? MCOIMAPPart)?.partID == source.partID }) as? MCOIMAPPart
        let fileName = matchingPart?.filename ?? "添付ファイル"
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MailSwipe", isDirectory: true)
            .appendingPathComponent(messageID.replacingOccurrences(of: ":", with: "-"), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(sanitizedFileName(fileName))
        try data.write(to: url, options: Data.WritingOptions.atomic)
        return url
    }

    private func searchUnreadUIDs() async throws -> MCOIndexSet {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let expression = MCOIMAPSearchExpression.searchUnread()
            let operation = session.searchExpressionOperation(withFolder: folder, expression: expression)
            operation?.start { error, results in
                if let error {
                    continuation.resume(throwing: MailServiceError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: results ?? MCOIndexSet())
                }
            }
        }
    }

    private func fetchMessages(uids: MCOIndexSet) async throws -> [MCOIMAPMessage] {
        try await withCheckedThrowingContinuation { continuation in
            let requestKind: MCOIMAPMessagesRequestKind = [.headers, .structure, .internalDate]
            let operation = session.fetchMessagesOperation(
                withFolder: folder,
                requestKind: requestKind,
                uids: uids
            )
            operation?.start { error, messages, _ in
                if let error {
                    continuation.resume(throwing: MailServiceError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: messages ?? [])
                }
            }
        }
    }

    private func updateSeenFlag(
        messageID: String,
        kind: MCOIMAPStoreFlagsRequestKind
    ) async throws {
        guard let uid = sourceMessages[messageID]?.uid else {
            throw MailServiceError.invalidMessage
        }

        try await withCheckedThrowingContinuation { continuation in
            let operation = session.storeFlagsOperation(
                withFolder: folder,
                uids: MCOIndexSet(index: UInt64(uid)),
                kind: kind,
                flags: .seen
            )
            operation?.start { error in
                if let error {
                    continuation.resume(throwing: MailServiceError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func messageIdentifier(uid: UInt32) -> String {
        "icloud:INBOX:\(uid)"
    }

    private func nonEmpty(_ value: String?, fallback: String) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return value
    }

    private func sanitizedFileName(_ fileName: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:\0")
        let result = fileName.components(separatedBy: invalid).joined(separator: "_")
        return result.isEmpty ? "添付ファイル" : result
    }
}
