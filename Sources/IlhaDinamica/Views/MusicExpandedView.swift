import AppKit
import SwiftUI

struct MusicExpandedView: View {
    @ObservedObject var music: MusicService
    @ObservedObject var settings: SettingsStore

    private var displayedElapsed: Double {
        music.isScrubbing ? music.scrubSeconds : music.elapsedTime
    }

    private var progressFraction: Double {
        guard music.duration > 0 else { return 0 }
        return max(0, min(1, displayedElapsed / music.duration))
    }

    private var resolvedSourceName: String {
        music.sourceDisplayName.isEmpty ? music.player.displayName : music.sourceDisplayName
    }

    var body: some View {
        Group {
            if music.hasTrack {
                activeTrackView
            } else if music.automationDenied {
                automationNoticeView
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activeTrackView: some View {
        GeometryReader { geo in
            let artSize = max(84, min(130, geo.size.height - 14))
            let corner = max(14, artSize * 0.14)

            HStack(spacing: 16) {
                Button {
                    music.openActivePlayer()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: max(16, artSize * 0.16), style: .continuous)
                            .fill(music.accentColor.opacity(0.35))
                            .frame(width: artSize, height: artSize)
                            .blur(radius: 14)

                        if let artwork = music.artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: artSize, height: artSize)
                                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                                )
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: corner, style: .continuous)
                                    .fill(music.accentColor.opacity(0.22))
                                Image(systemName: music.player.fallbackSymbolName)
                                    .font(.system(size: max(26, artSize * 0.32), weight: .semibold))
                                    .foregroundStyle(music.accentColor)
                            }
                            .frame(width: artSize, height: artSize)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Abrir \(resolvedSourceName)")

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(music.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(subtitleText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.62))
                                .lineLimit(1)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            let badgeTint = settings.resolvedButtonColor(fallback: music.accentColor)
                            let barTint = settings.resolvedSliderColor(fallback: music.accentColor)
                            Text(resolvedSourceName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(badgeTint)
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(badgeTint.opacity(0.15), in: Capsule())

                            AudioVisualizerView(
                                isPlaying: music.isPlaying,
                                accentColor: barTint,
                                barCount: 4,
                                barWidth: 2.3,
                                maxHeight: 14,
                                spacing: 2.0
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.trailing, 2)
                    }

                    Spacer(minLength: 6)

                    VStack(spacing: 4) {
                        scrubBar

                        HStack {
                            if music.duration > 0 {
                                Text(formatTime(displayedElapsed))
                                Spacer()
                                Text(formatTime(music.duration))
                            } else {
                                Text(music.isPlaying ? "Reproduzindo" : "Pausado")
                                Spacer()
                                Text(resolvedSourceName)
                                    .lineLimit(1)
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.48))
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 16) {
                        Spacer(minLength: 0)

                        Button {
                            music.seek(to: max(0, displayedElapsed - 10))
                        } label: {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(music.duration <= 0)
                        .opacity(music.duration > 0 ? 1.0 : 0.32)

                        Button {
                            music.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            music.togglePlayPause()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(settings.resolvedButtonColor(fallback: .white))
                                    .frame(width: 38, height: 38)
                                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(settings.resolvedButtonForeground(fallback: .black))
                                    .offset(x: music.isPlaying ? 0 : 1)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            music.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            let target = music.duration > 0
                                ? min(music.duration, displayedElapsed + 10)
                                : displayedElapsed + 10
                            music.seek(to: target)
                        } label: {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(music.duration <= 0)
                        .opacity(music.duration > 0 ? 1.0 : 0.32)

                        Spacer(minLength: 0)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .frame(height: artSize)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private var scrubBar: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let canScrub = music.duration > 0
            let fillFraction = canScrub ? progressFraction : (music.isPlaying ? 0.38 : 0.0)
            let barHeight: CGFloat = (canScrub && (music.isHoveringTrack || music.isScrubbing)) ? 6 : 4

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(height: barHeight)

                Capsule(style: .continuous)
                    .fill(settings.resolvedSliderColor(fallback: music.accentColor))
                    .frame(width: width * CGFloat(fillFraction), height: barHeight)

                if canScrub && (music.isHoveringTrack || music.isScrubbing) {
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, min(width - 10, width * CGFloat(progressFraction) - 5)))
                }
            }
            .frame(height: 14)
            .contentShape(Rectangle())
            .onHover { hovering in
                guard canScrub else {
                    music.isHoveringTrack = false
                    return
                }
                withAnimation(.easeInOut(duration: 0.14)) {
                    music.isHoveringTrack = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard music.duration > 0 else { return }
                        music.isScrubbing = true
                        let ratio = max(0, min(1, value.location.x / width))
                        music.scrubSeconds = Double(ratio) * music.duration
                    }
                    .onEnded { value in
                        guard music.duration > 0 else {
                            music.isScrubbing = false
                            return
                        }
                        let ratio = max(0, min(1, value.location.x / width))
                        let target = Double(ratio) * music.duration
                        music.isScrubbing = false
                        music.seek(to: target)
                    }
            )
        }
        .frame(height: 14)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Nenhuma mídia tocando")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Inicie uma música ou vídeo no Spotify, Apple Music, YouTube ou navegador.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                if music.isAppInstalled("com.spotify.client") {
                    launchPlayerButton(title: "Abrir Spotify", icon: "play.circle.fill", tint: MusicPlayerKind.spotify.defaultAccentColor) {
                        music.openPlayer(.spotify)
                    }
                }

                if music.isAppInstalled("com.apple.Music") {
                    launchPlayerButton(title: "Abrir Música", icon: "music.note", tint: MusicPlayerKind.appleMusic.defaultAccentColor) {
                        music.openPlayer(.appleMusic)
                    }
                }

                Spacer()

                Button {
                    Task { await music.pollNow() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Atualizar player")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var automationNoticeView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Permissão de Automação necessária")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Autorize o app em Ajustes do Sistema > Privacidade e Segurança > Automação.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button("Ajustes") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func launchPlayerButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var subtitleText: String {
        if music.album.isEmpty {
            return music.artist
        }
        if music.artist.isEmpty {
            return music.album
        }
        return "\(music.artist) — \(music.album)"
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
