import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellMediaControlPageView: View {
    @ObservedObject var viewModel: ShellViewModel

    @ObservedObject private var media = ShellMediaIntegrationService.shared
    @State private var selectedTrackID: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leftMediaPanel
                .frame(width: 252, alignment: .topLeading)

            rightRecentPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            media.start()
            if selectedTrackID == nil {
                selectedTrackID = media.currentTrack?.id ?? displayedTracks.first?.id
            }
        }
        .onDisappear {
            media.stop()
        }
        .onChange(of: media.currentTrack?.id) { _, newValue in
            if selectedTrackID == nil {
                selectedTrackID = newValue
            }
        }
    }

    private var leftMediaPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Media")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            HStack(alignment: .top, spacing: 8) {
                Button {
                    Task { await media.openActiveSourceApp() }
                } label: {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor(for: activeTrack.source).opacity(0.85), .black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            if let artwork = media.currentArtwork {
                                Image(nsImage: artwork)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.86))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(width: 88, height: 88)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 5) {
                    Text(activeTrack.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(activeTrack.artist)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                    Text(activeTrack.collection)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)

                    mediaProgressBar
                    HStack {
                        Text(durationLabel(media.elapsedSeconds))
                        Spacer()
                        Text(durationLabel(max(1, media.durationSeconds)))
                    }
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 6) {
                mediaControlButton(symbol: "shuffle", isActive: media.isShuffled) {
                    Task { await media.toggleShuffle() }
                }
                mediaControlButton(symbol: "backward.fill", isActive: false) {
                    Task { await media.previousTrack() }
                }
                mediaControlButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", isActive: true) {
                    Task { await media.togglePlayPause() }
                }
                mediaControlButton(symbol: "forward.fill", isActive: false) {
                    Task { await media.nextTrack() }
                }
                mediaControlButton(symbol: media.repeatMode.iconName, isActive: media.repeatMode.isActive) {
                    Task { await media.cycleRepeatMode() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 7) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Slider(
                    value: Binding(
                        get: { media.volume },
                        set: { newValue in
                            media.volume = newValue
                            Task { await media.setVolume(newValue) }
                        }
                    ),
                    in: 0...1
                )
                    .tint(.white.opacity(0.82))

                Text("\(Int((media.volume * 100).rounded()))")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(media.statusLabel)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private var mediaProgressBar: some View {
        let progress = media.durationSeconds > 0
            ? Double(media.elapsedSeconds) / Double(media.durationSeconds)
            : 0

        return GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.9))
                        .frame(width: proxy.size.width * min(1, max(0, progress)))
                }
        }
        .frame(height: 6)
    }

    private var rightRecentPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    if displayedTracks.isEmpty {
                        Text("No recent tracks yet")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }

                    ForEach(displayedTracks) { track in
                        Button {
                            selectedTrackID = track.id
                            Task { await media.play(track: track) }
                            viewModel.playSelectionHaptic()
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Rectangle()
                                    .fill(.white.opacity(0.92))
                                    .frame(width: 3)
                                    .cornerRadius(1.5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)

                                    Text("\(track.artist)  |  \(track.collection)")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.58))
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(track.playedAtLabel ?? "--:--")
                                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.95))
                                    Text(durationLabel(track.durationSeconds))
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                ((selectedTrackID == track.id || media.currentTrack?.id == track.id) ? .white.opacity(0.11) : .white.opacity(0.05)),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollDisabled(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var displayedTracks: [ShellMediaTrackItem] {
        let activeProvider = media.activeProvider ?? media.currentTrack?.source
        let items = media.recentTracks.filter { track in
            guard let activeProvider else { return true }
            return track.source == activeProvider
        }
        return Array(items.prefix(5))
    }

    private var activeTrack: ShellMediaTrackItem {
        media.currentTrack
            ?? displayedTracks.first
            ?? ShellMediaTrackItem(
                id: "media-fallback",
                title: "No Track",
                artist: "Disconnected",
                collection: "Media",
                durationSeconds: 1,
                source: media.activeProvider ?? .appleMusic,
                queuePosition: nil,
                playedAtLabel: nil
            )
    }

    private func mediaControlButton(symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            viewModel.playSelectionHaptic()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(isActive ? 0.95 : 0.82))
                .frame(width: 30, height: 30)
                .background(
                    isActive ? .white.opacity(0.13) : .white.opacity(0.07),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }

    private func accentColor(for provider: ShellMediaProvider) -> Color {
        switch provider {
        case .spotify:
            return .green
        case .appleMusic:
            return .pink
        }
    }

    private func durationLabel(_ totalSeconds: Int) -> String {
        let minutes = max(0, totalSeconds / 60)
        let seconds = max(0, totalSeconds % 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
