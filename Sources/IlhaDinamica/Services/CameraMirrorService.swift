@preconcurrency import AVFoundation
import Foundation

@MainActor
final class CameraMirrorService: ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var errorMessage: String?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.leonardo.ilhadinamica.camera")
    private var isConfigured = false

    init() {
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func start() {
        errorMessage = nil
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized:
            configureAndStartSession()

        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                if granted {
                    configureAndStartSession()
                } else {
                    errorMessage = "Permissão de câmera negada."
                }
            }

        case .denied, .restricted:
            errorMessage = "Autorize a câmera em Ajustes do Sistema > Privacidade e Segurança > Câmera."

        @unknown default:
            errorMessage = "Câmera indisponível."
        }
    }

    func stop() {
        isRunning = false
        let captureSession = session
        sessionQueue.async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func configureAndStartSession() {
        isRunning = true
        let captureSession = session
        let alreadyConfigured = isConfigured
        isConfigured = true

        sessionQueue.async { [weak self] in
            if !alreadyConfigured {
                captureSession.beginConfiguration()
                captureSession.sessionPreset = .medium

                if let device = AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                } else {
                    captureSession.commitConfiguration()
                    Task { @MainActor in
                        self?.isRunning = false
                        self?.errorMessage = "Nenhuma câmera disponível."
                    }
                    return
                }
                captureSession.commitConfiguration()
            }

            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }
}
