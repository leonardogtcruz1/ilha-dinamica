import AppKit
import AVFoundation
import SwiftUI

struct MirrorExpandedView: View {
    @ObservedObject var camera: CameraMirrorService
    @ObservedObject var audio: AudioControlService
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                if let errorMessage = camera.errorMessage {
                    VStack(spacing: 6) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                } else {
                    CameraPreviewRepresentable(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(width: 224, height: 144)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.85)
            )

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Espelho Rápido")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Confira enquadramento e microfone antes da call.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.58))
                }

                Button {
                    audio.toggleMicMute()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text(audio.isMicMuted ? "Microfone Mutado" : "Microfone Ativo")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        audio.isMicMuted ? Color.red.opacity(0.85) : Color(red: 0.22, green: 0.72, blue: 0.45).opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                if camera.authorizationStatus == .denied || camera.authorizationStatus == .restricted {
                    Button("Ajustes da Câmera") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Spacer(minLength: 0)

                Button {
                    onClose()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Fechar Espelho")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: CameraPreviewContainerView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
        nsView.configureMirroring()
    }
}

private final class CameraPreviewContainerView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
        configureMirroring()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        configureMirroring()
    }

    func configureMirroring() {
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
