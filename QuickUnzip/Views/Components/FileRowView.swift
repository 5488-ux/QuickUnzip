import SwiftUI

struct FileRowView: View {
    let item: FileItem
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundColor(item.iconColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                HStack(spacing: 8) {
                    Text(item.formattedSize)
                    Text(item.formattedDate)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            Spacer()
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
