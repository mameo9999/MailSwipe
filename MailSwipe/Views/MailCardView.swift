import SwiftUI

struct MailCardView: View {
    let message: MailMessage
    let isLoadingBody: Bool
    let onAttachmentTap: (MailAttachment) -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日（E） HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(message.subject)
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Label(message.senderDisplay, systemImage: "person.crop.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(
                    Self.dateFormatter.string(from: message.receivedAt),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isLoadingBody && !message.isContentLoaded {
                        HStack {
                            Spacer()
                            ProgressView("本文を読み込み中…")
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else if let htmlBody = message.htmlBody {
                        HTMLMailBodyView(html: htmlBody)
                            .frame(minHeight: 260)
                    } else {
                        Text(message.plainBody.isEmpty ? "本文はありません。" : message.plainBody)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !message.attachments.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("添付ファイル")
                                .font(.headline)

                            ForEach(message.attachments) { attachment in
                                Button {
                                    onAttachmentTap(attachment)
                                } label: {
                                    AttachmentRow(attachment: attachment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
    }
}
