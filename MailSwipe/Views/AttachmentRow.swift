import SwiftUI

struct AttachmentRow: View {
    let attachment: MailAttachment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .frame(width: 34)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(attachment.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconName: String {
        if attachment.mimeType == "application/pdf" {
            return "doc.richtext"
        }
        if attachment.mimeType.hasPrefix("image/") {
            return "photo"
        }
        return "paperclip"
    }
}

