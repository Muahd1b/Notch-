import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellHUDPageView: View {
    @ObservedObject var viewModel: ShellViewModel

    @ObservedObject private var cameraService = ShellHUDCameraService.shared
    @ObservedObject private var streamService = ShellHUDScreenStreamService.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cameraColumn
                .frame(width: 252, alignment: .topLeading)

            streamColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            cameraService.refreshState()
            streamService.refreshState()
        }
        .onDisappear {
            cameraService.stopSession()
            streamService.stopSession()
        }
    }

    private var cameraColumn: some View {
        ZStack {
            if let previewLayer = cameraService.previewLayer, cameraService.isSessionRunning {
                ShellHUDPreviewLayerView(previewLayer: previewLayer)
                    .scaleEffect(x: -1, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.04))
                    .overlay {
                        VStack(spacing: 7) {
                            Image(systemName: cameraService.authorizationStatus == .denied ? "exclamationmark.triangle" : "web.camera")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text(cameraService.authorizationStatus == .denied ? "Camera denied" : "Mirror")
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
            }
            hudCardLabel("Camera")
            hudCardActionButton(
                title: cameraButtonTitle,
                iconName: cameraService.isSessionRunning ? "stop.circle.fill" : "play.circle.fill",
                action: handleCameraPrimaryAction
            )
        }
        .frame(height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            handleCameraPrimaryAction()
        }
    }

    private var streamColumn: some View {
        ZStack {
            if let previewLayer = streamService.previewLayer, streamService.isSessionRunning {
                ShellHUDPreviewLayerView(previewLayer: previewLayer)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.04))
                    .overlay {
                        VStack(spacing: 7) {
                            Image(systemName: "display")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Full Screen Preview")
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
            }
            hudCardLabel("Display Stream")
            hudCardActionButton(
                title: streamButtonTitle,
                iconName: streamService.isSessionRunning ? "stop.circle.fill" : "play.circle.fill",
                action: handleStreamPrimaryAction
            )
        }
        .frame(height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            handleStreamPrimaryAction()
        }
    }

    private func hudCardLabel(_ title: String) -> some View {
        VStack {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .allowsHitTesting(false)
    }

    private func hudCardActionButton(title: String, iconName: String, action: @escaping () -> Void) -> some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 11.5, weight: .semibold))
                        Text(title)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
    }

    private var cameraButtonTitle: String {
        switch cameraService.authorizationStatus {
        case .denied, .restricted:
            return "Open Camera Settings"
        default:
            return cameraService.isSessionRunning ? "Stop Camera" : "Start Camera"
        }
    }

    private var streamButtonTitle: String {
        if !streamService.hasScreenRecordingAccess && streamService.didAttemptPermissionRequest {
            return "Open Screen Settings"
        }
        return streamService.isSessionRunning ? "Stop Stream" : "Start Stream"
    }

    private func handleCameraPrimaryAction() {
        switch cameraService.authorizationStatus {
        case .denied, .restricted:
            cameraService.openSystemSettings()
        default:
            cameraService.toggleSession()
        }
        viewModel.playSelectionHaptic()
    }

    private func handleStreamPrimaryAction() {
        if !streamService.hasScreenRecordingAccess && streamService.didAttemptPermissionRequest {
            streamService.openSystemSettings()
        } else {
            streamService.toggleSession()
        }
        viewModel.playSelectionHaptic()
    }
}

private struct ShellHUDPreviewLayerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer = previewLayer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if nsView.layer !== previewLayer {
            nsView.layer = previewLayer
        }
        previewLayer.frame = nsView.bounds
        CATransaction.commit()
    }
}
