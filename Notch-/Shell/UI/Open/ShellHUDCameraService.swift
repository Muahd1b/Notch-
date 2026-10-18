import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

final class ShellHUDCameraService: ObservableObject {
    static let shared = ShellHUDCameraService()

    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var isSessionRunning = false
    @Published private(set) var cameraAvailable = false
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var statusMessage = "Camera idle"

    private let sessionQueue = DispatchQueue(label: "Notch.HUD.Camera.SessionQueue", qos: .userInitiated)
    private var captureSession: AVCaptureSession?

    private init() {
        refreshState()
    }

    func refreshState() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .denied || status == .restricted {
                self.statusMessage = "Camera access denied"
            }
        }
        checkCameraAvailability()
    }

    func toggleSession() {
        if isSessionRunning {
            stopSession()
        } else {
            startSession()
        }
    }

    func startSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        switch status {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authorizationStatus = granted ? .authorized : .denied
                    self.statusMessage = granted ? "Camera ready" : "Camera access denied"
                    if granted {
                        self.checkCameraAvailability()
                        self.configureAndStartSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.statusMessage = "Camera access denied"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.statusMessage = "Camera unavailable"
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            let session = self.captureSession
            self.captureSession = nil

            if let session {
                if session.isRunning {
                    session.stopRunning()
                }
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                for output in session.outputs {
                    session.removeOutput(output)
                }
                session.commitConfiguration()
            }

            DispatchQueue.main.async {
                self.previewLayer = nil
                self.isSessionRunning = false
                self.statusMessage = "Camera stopped"
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private func checkCameraAvailability() {
        let availableDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        let hasDevices = !availableDevices.isEmpty
        DispatchQueue.main.async {
            self.cameraAvailable = hasDevices
            if !hasDevices {
                self.statusMessage = "No camera detected"
            }
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async {
            if let session = self.captureSession {
                if !session.isRunning {
                    session.startRunning()
                }
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                DispatchQueue.main.async {
                    self.previewLayer = layer
                    self.isSessionRunning = session.isRunning
                    self.statusMessage = session.isRunning ? "Camera live" : "Camera idle"
                }
                return
            }

            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                mediaType: .video,
                position: .unspecified
            )

            guard let videoDevice = self.preferredVideoDevice(from: discoverySession.devices) else {
                DispatchQueue.main.async {
                    self.cameraAvailable = false
                    self.statusMessage = "No camera detected"
                }
                return
            }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .high

            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                guard session.canAddInput(input) else {
                    DispatchQueue.main.async {
                        self.statusMessage = "Camera input unavailable"
                    }
                    session.commitConfiguration()
                    return
                }

                session.addInput(input)

                session.commitConfiguration()
                session.startRunning()
                self.captureSession = session

                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill

                DispatchQueue.main.async {
                    self.previewLayer = layer
                    self.cameraAvailable = true
                    self.isSessionRunning = session.isRunning
                    self.statusMessage = session.isRunning ? "Camera live" : "Camera idle"
                }
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.statusMessage = "Camera failed: \(error.localizedDescription)"
                    self.isSessionRunning = false
                    self.previewLayer = nil
                }
            }
        }
    }

    private func preferredVideoDevice(from devices: [AVCaptureDevice]) -> AVCaptureDevice? {
        if let builtInFront = devices.first(where: {
            $0.deviceType == .builtInWideAngleCamera && $0.position == .front
        }) {
            return builtInFront
        }

        if let builtIn = devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            return builtIn
        }

        if let externalNonPhone = devices.first(where: {
            ($0.deviceType == .external || $0.deviceType == .continuityCamera)
                && !$0.localizedName.localizedCaseInsensitiveContains("iphone")
        }) {
            return externalNonPhone
        }

        return devices.first
    }
}
