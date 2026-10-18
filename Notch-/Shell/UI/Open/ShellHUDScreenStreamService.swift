import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

final class ShellHUDScreenStreamService: ObservableObject {
    static let shared = ShellHUDScreenStreamService()

    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var isSessionRunning = false
    @Published private(set) var hasScreenRecordingAccess = CGPreflightScreenCaptureAccess()
    @Published private(set) var didAttemptPermissionRequest = false
    @Published private(set) var statusMessage = "Stream idle"

    private let sessionQueue = DispatchQueue(label: "Notch.HUD.Stream.SessionQueue", qos: .userInitiated)
    private var captureSession: AVCaptureSession?

    private init() {
        refreshState()
    }

    func refreshState() {
        let access = CGPreflightScreenCaptureAccess()
        DispatchQueue.main.async {
            self.hasScreenRecordingAccess = access
            if !access {
                self.statusMessage = "Screen recording permission required"
            }
        }
    }

    func toggleSession() {
        if isSessionRunning {
            stopSession()
        } else {
            startSession()
        }
    }

    func startSession() {
        let access = CGPreflightScreenCaptureAccess()
        DispatchQueue.main.async {
            self.hasScreenRecordingAccess = access
        }

        if !access {
            didAttemptPermissionRequest = true
            let granted = CGRequestScreenCaptureAccess()
            DispatchQueue.main.async {
                self.hasScreenRecordingAccess = granted
                self.statusMessage = granted ? "Stream ready" : "Screen recording permission required"
            }
            guard granted else { return }
        }

        configureAndStartSession()
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
                self.statusMessage = "Stream stopped"
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
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
                    self.statusMessage = session.isRunning ? "Streaming main display" : "Stream idle"
                }
                return
            }

            guard let screenInput = AVCaptureScreenInput(displayID: CGMainDisplayID()) else {
                DispatchQueue.main.async {
                    self.statusMessage = "Display capture unavailable"
                }
                return
            }

            screenInput.minFrameDuration = CMTime(value: 1, timescale: 30)
            screenInput.capturesCursor = true
            screenInput.capturesMouseClicks = true

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .high

            guard session.canAddInput(screenInput) else {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.statusMessage = "Display input unavailable"
                }
                return
            }

            session.addInput(screenInput)

            let output = AVCaptureVideoDataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()
            session.startRunning()
            self.captureSession = session

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill

            DispatchQueue.main.async {
                self.previewLayer = layer
                self.isSessionRunning = session.isRunning
                self.statusMessage = session.isRunning ? "Streaming main display" : "Stream idle"
            }
        }
    }
}
