import SwiftUI

struct ClipboardExpandedView: View {
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.65, green: 0.56, blue: 1.0))
                    Text("Histórico (\(clipboard.items.count))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if clipboard.items.contains(where: { !$0.isPinned }) {
                    Button {
                        clipboard.clearUnpinned()
                    } label: {
                        Text("Limpar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.60))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if clipboard.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Text("Nada copiado ainda")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Text("Textos e links copiados (⌘C) aparecerão aqui automaticamente.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(clipboard.items) { item in
                            clipboardRow(item)
                        }
                    }
                }
            }
        }
    }

    private func clipboardRow(_ item: ClipboardItem) -> some View {
        let justCopied = clipboard.recentlyCopiedId == item.id

        return HStack(spacing: 8) {
            Button {
                clipboard.togglePin(item)
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(item.isPinned ? Color.yellow : Color.white.opacity(0.35))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Desafixar" : "Fixar no topo")

            Button {
                clipboard.copy(item)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: justCopied ? "checkmark.circle.fill" : (item.isURL ? "link" : "text.alignleft"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            justCopied
                                ? Color(red: 0.22, green: 0.90, blue: 0.48)
                                : (item.isURL ? Color(red: 0.36, green: 0.76, blue: 1.0) : Color.white.opacity(0.55))
                        )
                        .frame(width: 14)

                    Text(compactPreview(item.text))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(justCopied ? Color(red: 0.22, green: 0.90, blue: 0.48) : .white.opacity(0.92))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(justCopied ? "Copiado" : relativeTime(item.copiedAt))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(justCopied ? Color(red: 0.22, green: 0.90, blue: 0.48) : Color.white.opacity(0.42))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                clipboard.delete(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            justCopied ? Color(red: 0.22, green: 0.90, blue: 0.48).opacity(0.12) : Color.white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func compactPreview(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func relativeTime(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "agora" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
