import AppKit
import SwiftUI

struct ShelfExpandedView: View {
    @ObservedObject var shelf: ShelfService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.36, green: 0.76, blue: 1.0))
                    Text(shelf.items.isEmpty ? "Bandeja de Arquivos" : "Bandeja (\(shelf.items.count))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)

                    if let status = shelf.airDropStatusText {
                        Text(status)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.36, green: 0.76, blue: 1.0))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.36, green: 0.76, blue: 1.0).opacity(0.16), in: Capsule())
                    } else if !shelf.items.isEmpty {
                        Text("• arraste pros apps")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                }

                Spacer()

                Button {
                    pickFiles()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Adicionar")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.11), in: Capsule())
                }
                .buttonStyle(.plain)

                if !shelf.items.isEmpty {
                    Button {
                        shelf.clearAll()
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

            HStack(spacing: 10) {
                airDropSectionCard

                if shelf.items.isEmpty && shelf.pendingDropCount == 0 {
                    dropEmptyState
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if shelf.pendingDropCount > 0 {
                                importingPlaceholderCard
                            }
                            ForEach(shelf.items) { item in
                                shelfCard(item)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    private var airDropSectionCard: some View {
        let blue = Color(red: 0.30, green: 0.74, blue: 1.0)
        let targeted = shelf.isAirDropDropTargeted

        return VStack(spacing: 5) {
            Button {
                if shelf.items.isEmpty {
                    shelf.pickFilesForAirDrop()
                } else {
                    shelf.sendAllViaAirDrop()
                }
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .stroke(blue.opacity(targeted ? 0.55 : 0.22), lineWidth: 1)
                            .frame(width: 44, height: 44)
                        Circle()
                            .stroke(blue.opacity(targeted ? 0.75 : 0.34), lineWidth: 1)
                            .frame(width: 33, height: 33)
                        Circle()
                            .fill(blue.opacity(targeted ? 0.32 : 0.18))
                            .frame(width: 24, height: 24)
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(targeted ? .white : blue)
                    }

                    Text("AirDrop")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)

                    Text(
                        targeted
                            ? "Solte p/ enviar"
                            : (shelf.items.isEmpty ? "Escolher arquivos" : "Enviar tudo (\(shelf.items.count))")
                    )
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(targeted ? .white : blue)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .help(shelf.items.isEmpty ? "Escolher arquivo para enviar via AirDrop" : "Enviar todos os arquivos da Bandeja via AirDrop")

            Button {
                shelf.openAirDropWindow()
            } label: {
                Text("Abrir Finder")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Abrir janela do AirDrop no Finder para receber ou enviar")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(width: 112, height: 118)
        .background(
            targeted ? blue.opacity(0.20) : blue.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(targeted ? blue : blue.opacity(0.32), lineWidth: targeted ? 1.4 : 0.9)
        )
        .onDrop(of: [.fileURL], isTargeted: $shelf.isAirDropDropTargeted) { providers in
            shelf.handleAirDropDrop(providers: providers)
        }
    }

    private var dropEmptyState: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    shelf.isDropTargeted ? Color(red: 0.36, green: 0.76, blue: 1.0) : Color.white.opacity(0.16),
                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(shelf.isDropTargeted ? Color(red: 0.36, green: 0.76, blue: 1.0).opacity(0.12) : Color.white.opacity(0.04))
                )

            VStack(spacing: 5) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(shelf.isDropTargeted ? Color(red: 0.36, green: 0.76, blue: 1.0) : Color.white.opacity(0.55))
                Text("Arraste prints, vídeos ou arquivos para cá")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Text("Ficam prontos com preview para arrastar ao WhatsApp, Slack ou Finder")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.50))
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var importingPlaceholderCard: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                ProgressView()
                    .controlSize(.small)
                    .colorScheme(.dark)
            }
            .frame(width: 120, height: 74)

            VStack(spacing: 2) {
                Text("Preparando...")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Text("Aguarde")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(6)
        .frame(width: 132, height: 118)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(red: 0.36, green: 0.76, blue: 1.0).opacity(0.45), lineWidth: 1)
        )
    }

    private func shelfCard(_ item: ShelfItem) -> some View {
        let isHighlighted = shelf.highlightedItemID == item.id
        let isVisual = item.hasVisualPreview
        let cardWidth: CGFloat = isVisual ? 132 : 102

        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 5) {
                if isVisual {
                    mediaPreviewBox(for: item, isHighlighted: isHighlighted)
                } else {
                    fileIconBox(for: item)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(item.name)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text(item.sizeText)
                            .font(.system(size: 9.5, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .lineLimit(1)

                        Spacer(minLength: 2)

                        if isHighlighted {
                            Text("Pronto")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(Color(red: 0.22, green: 0.90, blue: 0.48))
                        } else {
                            HStack(spacing: 5) {
                                Button {
                                    shelf.sendItemViaAirDrop(item)
                                } label: {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.30, green: 0.74, blue: 1.0).opacity(0.88))
                                }
                                .buttonStyle(.plain)
                                .help("Enviar via AirDrop")

                                Button {
                                    shelf.copyToClipboard(item)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.50))
                                }
                                .buttonStyle(.plain)
                                .help("Copiar arquivo")
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(6)
            .frame(width: cardWidth, height: 118, alignment: .top)
            .background(
                (isHighlighted ? Color(red: 0.22, green: 0.90, blue: 0.48).opacity(0.10) : Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isHighlighted ? Color(red: 0.22, green: 0.90, blue: 0.48).opacity(0.60) : Color.white.opacity(0.11),
                        lineWidth: isHighlighted ? 1.15 : 0.75
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .onAppear {
                shelf.ensurePreviewLoaded(for: item)
            }
            .onTapGesture(count: 2) {
                shelf.openFile(item)
            }
            .onDrag({
                NSItemProvider(object: item.url as NSURL)
            }, preview: {
                dragPreview(for: item)
            })
            .contextMenu {
                Button("Enviar via AirDrop") { shelf.sendItemViaAirDrop(item) }
                Button("Abrir") { shelf.openFile(item) }
                Button("Copiar") { shelf.copyToClipboard(item) }
                Button("Mostrar no Finder") { shelf.revealInFinder(item) }
                Divider()
                Button("Remover da Bandeja") { shelf.remove(item) }
            }

            Button {
                shelf.remove(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13.5))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white.opacity(0.92), Color.black.opacity(0.68))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Remover")
        }
    }

    private func mediaPreviewBox(for item: ShelfItem, isHighlighted: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05))

            if let thumb = shelf.previewImage(for: item) {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 74)
                    .clipped()
            } else {
                VStack(spacing: 4) {
                    Image(systemName: item.mediaKind == .video ? "video.fill" : "photo.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Text(item.mediaKind == .video ? "Gerando preview..." : "Carregando...")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Color.white.opacity(0.38))
                }
            }

            if item.mediaKind == .video {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 24, height: 24)
                    .background(Color.black.opacity(0.52), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 0.7))
            }

            VStack {
                Spacer()
                HStack {
                    if item.mediaKind == .video {
                        HStack(spacing: 3) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 7.5, weight: .bold))
                            Text(shelf.durationText(for: item) ?? "Vídeo")
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded).monospacedDigit())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.64), in: Capsule())
                    } else if isHighlighted {
                        HStack(spacing: 3) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 7.5, weight: .bold))
                            Text("Print")
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.64), in: Capsule())
                    }
                    Spacer()
                }
                .padding(5)
            }
        }
        .frame(width: 120, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
        )
    }

    private func fileIconBox(for item: ShelfItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05))
            Image(nsImage: shelf.fallbackIcon(for: item.url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
        }
        .frame(width: 90, height: 74)
    }

    private func dragPreview(for item: ShelfItem) -> some View {
        Group {
            if let thumb = shelf.previewImage(for: item) {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 112, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            } else {
                HStack(spacing: 6) {
                    Image(nsImage: shelf.fallbackIcon(for: item.url))
                        .resizable()
                        .frame(width: 26, height: 26)
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.begin { response in
            if response == .OK {
                Task { @MainActor in
                    shelf.addFiles(panel.urls, emitCallback: false)
                }
            }
        }
    }
}
