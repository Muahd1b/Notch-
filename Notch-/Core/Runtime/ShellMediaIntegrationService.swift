import AppKit
import Combine
import Foundation

enum ShellMediaProvider: String, CaseIterable, Identifiable {
    case spotify
    case appleMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotify:
            return "Spotify"
        case .appleMusic:
            return "Apple Music"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .spotify:
            return "com.spotify.client"
        case .appleMusic:
            return "com.apple.Music"
        }
    }
}

enum ShellMediaRepeatState: Int, CaseIterable {
    case off = 0
    case all = 1
    case one = 2

    var iconName: String {
        switch self {
        case .off, .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    var isActive: Bool {
        self != .off
    }
}

struct ShellMediaTrackItem: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let collection: String
    let durationSeconds: Int
    let source: ShellMediaProvider
    let queuePosition: Int?
    let playedAtLabel: String?
}

private enum ShellMediaProviderProbeResult {
    case ready
    case automationDenied
    case unavailable
}

@MainActor
final class ShellMediaIntegrationService: ObservableObject {
    static let shared = ShellMediaIntegrationService(settingsStore: .shared)

    @Published private(set) var spotifyConnected = false
    @Published private(set) var appleMusicConnected = false
    @Published private(set) var activeProvider: ShellMediaProvider? = nil
    @Published private(set) var currentTrack: ShellMediaTrackItem? = nil
    @Published private(set) var currentArtwork: NSImage? = nil
    @Published private(set) var isPlaying = false
    @Published private(set) var isShuffled = false
    @Published private(set) var repeatMode: ShellMediaRepeatState = .off
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var durationSeconds = 0
    @Published var volume: Double = 0.5
    @Published private(set) var recentTracks: [ShellMediaTrackItem] = []
    @Published private(set) var statusLabel: String = "Disconnected"

    private let settingsStore: AppSettingsStore
    private let scriptRunner = ShellAppleScriptRunner()
    private let artworkFetcher = ShellArtworkFetcher()
    private var preferredProvider: ShellMediaProvider = .spotify
    private var pollTask: Task<Void, Never>?
    private var spotifyNotificationTask: Task<Void, Never>?
    private var appleMusicNotificationTask: Task<Void, Never>?
    private var pollConsumerCount = 0
    private var lastTrackID: String?
    private var lastKnownTrack: ShellMediaTrackItem?
    private var lastArtworkURL: String?
    private let clockFormatter: DateFormatter

    init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .current
        self.clockFormatter = formatter
    }

    func start() {
        pollConsumerCount += 1
        startPlaybackObserversIfNeeded()
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        pollConsumerCount = max(0, pollConsumerCount - 1)
        guard pollConsumerCount == 0 else { return }
        pollTask?.cancel()
        pollTask = nil
        spotifyNotificationTask?.cancel()
        spotifyNotificationTask = nil
        appleMusicNotificationTask?.cancel()
        appleMusicNotificationTask = nil
    }

    func connect(_ provider: ShellMediaProvider) async {
        setProviderEnabled(provider, enabled: true)
        preferredProvider = provider
        statusLabel = "Connecting to \(provider.title)…"
        let opened = await openApp(bundleIdentifier: provider.bundleIdentifier)
        guard opened else {
            statusLabel = "\(provider.title) is not installed"
            await refresh()
            return
        }

        for _ in 0..<24 {
            await refresh()
            if isProviderConnected(provider) {
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        await refresh()
    }

    func disconnect(_ provider: ShellMediaProvider) async {
        setProviderEnabled(provider, enabled: false)
        if preferredProvider == provider {
            preferredProvider = provider == .spotify ? .appleMusic : .spotify
        }
        await refresh()
    }

    func openActiveSourceApp() async {
        guard let provider = activeProvider ?? connectedFallbackProvider else { return }
        _ = await openApp(bundleIdentifier: provider.bundleIdentifier)
    }

    func togglePlayPause() async {
        guard let provider = effectiveProvider else { return }
        switch provider {
        case .spotify:
            await executeSpotify("playpause")
        case .appleMusic:
            await executeAppleMusic("playpause")
        }
        await refresh()
    }

    func nextTrack() async {
        guard let provider = effectiveProvider else { return }
        switch provider {
        case .spotify:
            await executeSpotify("next track")
        case .appleMusic:
            await executeAppleMusic("next track")
        }
        await refresh()
    }

    func previousTrack() async {
        guard let provider = effectiveProvider else { return }
        switch provider {
        case .spotify:
            await executeSpotify("previous track")
        case .appleMusic:
            await executeAppleMusic("previous track")
        }
        await refresh()
    }

    func toggleShuffle() async {
        guard let provider = effectiveProvider else { return }
        switch provider {
        case .spotify:
            await executeSpotify("set shuffling to not shuffling")
        case .appleMusic:
            await executeAppleMusic("set shuffle enabled to not shuffle enabled")
        }
        await refresh()
    }

    func cycleRepeatMode() async {
        guard let provider = effectiveProvider else { return }
        switch provider {
        case .spotify:
            await executeSpotify("set repeating to not repeating")
        case .appleMusic:
            await executeAppleMusic(
                """
                if song repeat is off then
                    set song repeat to all
                else if song repeat is all then
                    set song repeat to one
                else
                    set song repeat to off
                end if
                """
            )
        }
        await refresh()
    }

    func setVolume(_ value: Double) async {
        let clamped = max(0, min(1, value))
        volume = clamped
        let pct = Int((clamped * 100).rounded())
        guard let provider = effectiveProvider else { return }
        switch provider {
        case .spotify:
            await executeSpotify("set sound volume to \(pct)")
        case .appleMusic:
            await executeAppleMusic("set sound volume to \(pct)")
        }
    }

    func play(track: ShellMediaTrackItem) async {
        preferredProvider = track.source
        switch track.source {
        case .appleMusic:
            let escapedTitle = escapeAppleScript(track.title)
            let escapedArtist = escapeAppleScript(track.artist)
            let script =
                """
                tell application "Music"
                    try
                        set targetTrack to first track of current playlist whose name is "\(escapedTitle)" and artist is "\(escapedArtist)"
                        play targetTrack
                    end try
                end tell
                """
            _ = await scriptRunner.execute(script)
        case .spotify:
            // Spotify AppleScript cannot reliably play a track by title/artist without URI.
            // Fallback keeps control in Spotify and lets user pick from Spotify app.
            _ = await openApp(bundleIdentifier: ShellMediaProvider.spotify.bundleIdentifier)
        }
        await refresh()
    }

    func refresh() async {
        let spotifyEnabled = isProviderEnabled(.spotify)
        let appleMusicEnabled = isProviderEnabled(.appleMusic)
        let spotifyRunning = isRunning(bundleIdentifier: ShellMediaProvider.spotify.bundleIdentifier)
        let appleMusicRunning = isRunning(bundleIdentifier: ShellMediaProvider.appleMusic.bundleIdentifier)

        let spotifyProbe: ShellMediaProviderProbeResult = (spotifyEnabled && spotifyRunning) ? await probeProviderControl(.spotify) : .unavailable
        let appleMusicProbe: ShellMediaProviderProbeResult = (appleMusicEnabled && appleMusicRunning) ? await probeProviderControl(.appleMusic) : .unavailable

        spotifyConnected = spotifyEnabled && spotifyRunning && spotifyProbe == .ready
        appleMusicConnected = appleMusicEnabled && appleMusicRunning && appleMusicProbe == .ready

        activeProvider = resolveProvider()
        guard let provider = activeProvider else {
            currentTrack = nil
            currentArtwork = nil
            isPlaying = false
            isShuffled = false
            repeatMode = .off
            elapsedSeconds = 0
            durationSeconds = 0
            volume = 0.5
            if !spotifyEnabled && !appleMusicEnabled {
                statusLabel = "Enable Spotify or Apple Music in Settings"
            } else if spotifyProbe == .automationDenied || appleMusicProbe == .automationDenied {
                statusLabel = "Allow Controll Notch in macOS Privacy > Automation"
            } else {
                statusLabel = "Open an enabled media app to connect"
            }
            return
        }

        let state: ShellProviderState?
        switch provider {
        case .spotify:
            state = await readSpotifyState()
        case .appleMusic:
            state = await readAppleMusicState()
        }

        guard let state else {
            statusLabel = "\(provider.title) unavailable"
            return
        }

        isPlaying = state.isPlaying
        isShuffled = state.isShuffled
        repeatMode = state.repeatMode
        elapsedSeconds = state.elapsedSeconds
        durationSeconds = state.durationSeconds
        volume = state.volume
        statusLabel = "\(provider.title) connected"

        let track = ShellMediaTrackItem(
            id: state.trackID,
            title: state.title,
            artist: state.artist,
            collection: state.album,
            durationSeconds: state.durationSeconds,
            source: provider,
            queuePosition: nil,
            playedAtLabel: nil
        )
        currentTrack = track
        updateRecentsIfNeeded(track)
        await updateArtwork(from: state)

        let providerRecentTracks: [ShellMediaTrackItem]
        switch provider {
        case .appleMusic:
            providerRecentTracks = await readAppleMusicRecent(source: provider)
        case .spotify:
            providerRecentTracks = await readSpotifyRecent(source: provider)
        }
        mergeProviderRecents(providerRecentTracks, for: provider)
    }

    private var effectiveProvider: ShellMediaProvider? {
        activeProvider ?? connectedFallbackProvider
    }

    private var connectedFallbackProvider: ShellMediaProvider? {
        if spotifyConnected { return .spotify }
        if appleMusicConnected { return .appleMusic }
        return nil
    }

    private func isProviderConnected(_ provider: ShellMediaProvider) -> Bool {
        switch provider {
        case .spotify:
            return spotifyConnected
        case .appleMusic:
            return appleMusicConnected
        }
    }

    private func isProviderEnabled(_ provider: ShellMediaProvider) -> Bool {
        switch provider {
        case .spotify:
            return settingsStore.mediaSpotifyIntegrationEnabled
        case .appleMusic:
            return settingsStore.mediaAppleMusicIntegrationEnabled
        }
    }

    private func setProviderEnabled(_ provider: ShellMediaProvider, enabled: Bool) {
        switch provider {
        case .spotify:
            settingsStore.mediaSpotifyIntegrationEnabled = enabled
        case .appleMusic:
            settingsStore.mediaAppleMusicIntegrationEnabled = enabled
        }
    }

    private func probeProviderControl(_ provider: ShellMediaProvider) async -> ShellMediaProviderProbeResult {
        let script: String
        switch provider {
        case .spotify:
            script =
                """
                tell application "Spotify"
                    try
                        set _state to player state
                        return "ok"
                    on error errMsg number errNum
                        return "error:" & (errNum as string)
                    end try
                end tell
                """
        case .appleMusic:
            script =
                """
                tell application "Music"
                    try
                        set _state to player state
                        return "ok"
                    on error errMsg number errNum
                        return "error:" & (errNum as string)
                    end try
                end tell
                """
        }

        guard let result = await scriptRunner.execute(script)?.stringValue else {
            return .unavailable
        }
        if result == "ok" { return .ready }
        if result.contains("-1743") { return .automationDenied }
        return .unavailable
    }

    private func resolveProvider() -> ShellMediaProvider? {
        switch preferredProvider {
        case .spotify where spotifyConnected:
            return .spotify
        case .appleMusic where appleMusicConnected:
            return .appleMusic
        default:
            if spotifyConnected { return .spotify }
            if appleMusicConnected { return .appleMusic }
            return nil
        }
    }

    private func updateRecentsIfNeeded(_ track: ShellMediaTrackItem) {
        guard !isPlaceholderTrack(track) else { return }

        if lastTrackID == nil && recentTracks.isEmpty {
            recentTracks = [
                ShellMediaTrackItem(
                    id: "\(track.id)-seed",
                    title: track.title,
                    artist: track.artist,
                    collection: track.collection,
                    durationSeconds: track.durationSeconds,
                    source: track.source,
                    queuePosition: nil,
                    playedAtLabel: clockFormatter.string(from: Date())
                )
            ]
            lastTrackID = track.id
            lastKnownTrack = track
            return
        }

        guard lastTrackID != track.id else {
            lastKnownTrack = track
            return
        }

        if let previous = lastKnownTrack {
            let item = ShellMediaTrackItem(
                id: "\(previous.id)-\(Date().timeIntervalSince1970)",
                title: previous.title,
                artist: previous.artist,
                collection: previous.collection,
                durationSeconds: previous.durationSeconds,
                source: previous.source,
                queuePosition: nil,
                playedAtLabel: clockFormatter.string(from: Date())
            )
            var updated = recentTracks.filter { !($0.title == item.title && $0.artist == item.artist) }
            updated.insert(item, at: 0)
            recentTracks = Array(updated.prefix(12))
        }

        lastTrackID = track.id
        lastKnownTrack = track
    }

    private func isPlaceholderTrack(_ track: ShellMediaTrackItem) -> Bool {
        track.title == "Not Playing" || track.id.hasSuffix("-idle")
    }

    private func mergeProviderRecents(_ providerRecent: [ShellMediaTrackItem], for provider: ShellMediaProvider) {
        let providerSessionRecents = recentTracks.filter { $0.source == provider }
        let otherProviderRecents = recentTracks.filter { $0.source != provider }
        var merged: [ShellMediaTrackItem] = []

        func appendIfUnique(_ item: ShellMediaTrackItem) {
            guard !merged.contains(where: {
                $0.title == item.title && $0.artist == item.artist && $0.collection == item.collection
            }) else {
                return
            }
            merged.append(item)
        }

        for item in providerSessionRecents {
            appendIfUnique(item)
        }
        for item in providerRecent {
            appendIfUnique(item)
        }

        recentTracks = Array((merged + otherProviderRecents).prefix(24))
    }

    private func startPlaybackObserversIfNeeded() {
        if spotifyNotificationTask == nil {
            spotifyNotificationTask = Task { [weak self] in
                let notifications = DistributedNotificationCenter.default().notifications(
                    named: NSNotification.Name("com.spotify.client.PlaybackStateChanged")
                )
                for await _ in notifications {
                    guard let self else { return }
                    await self.refresh()
                }
            }
        }

        if appleMusicNotificationTask == nil {
            appleMusicNotificationTask = Task { [weak self] in
                let notifications = DistributedNotificationCenter.default().notifications(
                    named: NSNotification.Name("com.apple.Music.playerInfo")
                )
                for await _ in notifications {
                    guard let self else { return }
                    await self.refresh()
                }
            }
        }
    }

    private func updateArtwork(from state: ShellProviderState) async {
        if let data = state.artworkData, let image = NSImage(data: data) {
            currentArtwork = image
            lastArtworkURL = nil
            return
        }

        guard let artworkURL = normalizedArtworkURL(from: state.artworkURL), let url = URL(string: artworkURL) else {
            if state.trackID.hasSuffix("-idle") || state.title == "Not Playing" {
                currentArtwork = nil
                lastArtworkURL = nil
            }
            return
        }

        guard artworkURL != lastArtworkURL || currentArtwork == nil else { return }
        guard let data = await artworkFetcher.fetchImageData(from: url), let image = NSImage(data: data) else {
            return
        }
        currentArtwork = image
        lastArtworkURL = artworkURL
    }

    private func normalizedArtworkURL(from raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if value.hasPrefix("spotify:image:") {
            let imageID = value.replacingOccurrences(of: "spotify:image:", with: "")
            guard !imageID.isEmpty else { return nil }
            value = "https://i.scdn.co/image/\(imageID)"
        } else if value.hasPrefix("http://") {
            value = "https://" + value.dropFirst("http://".count)
        }

        return value
    }

    private func readSpotifyState() async -> ShellProviderState? {
        let script =
            """
            tell application "Spotify"
                try
                    set playerState to player state is playing
                    set currentTrackName to name of current track
                    set currentTrackArtist to artist of current track
                    set currentTrackAlbum to album of current track
                    set trackPosition to player position
                    set trackDurationMs to duration of current track
                    set shuffleState to shuffling
                    set repeatState to repeating
                    set currentVolume to sound volume
                    set persistentID to id of current track
                    try
                        set artworkURL to artwork url of current track
                    on error
                        set artworkURL to ""
                    end try
                    return {playerState, currentTrackName, currentTrackArtist, currentTrackAlbum, trackPosition, trackDurationMs, shuffleState, repeatState, currentVolume, persistentID, artworkURL}
                on error
                    return {false, "Not Playing", "Spotify", "Spotify", 0, 0, false, false, 50, "spotify-idle", ""}
                end try
            end tell
            """
        guard let descriptor = await scriptRunner.execute(script), descriptor.numberOfItems >= 11 else {
            return nil
        }
        let durationMs = descriptor.atIndex(6)?.int32Value ?? 0
        let durationSeconds = max(0, Int(durationMs) / 1000)
        let repeatMode: ShellMediaRepeatState = (descriptor.atIndex(8)?.booleanValue ?? false) ? .all : .off
        let id = descriptor.atIndex(10)?.stringValue ?? UUID().uuidString
        let artworkURL = descriptor.atIndex(11)?.stringValue
        return ShellProviderState(
            trackID: id,
            title: descriptor.atIndex(2)?.stringValue ?? "Unknown",
            artist: descriptor.atIndex(3)?.stringValue ?? "Unknown",
            album: descriptor.atIndex(4)?.stringValue ?? "Spotify",
            elapsedSeconds: max(0, Int(descriptor.atIndex(5)?.doubleValue ?? 0)),
            durationSeconds: durationSeconds,
            isPlaying: descriptor.atIndex(1)?.booleanValue ?? false,
            isShuffled: descriptor.atIndex(7)?.booleanValue ?? false,
            repeatMode: repeatMode,
            volume: max(0, min(1, Double(descriptor.atIndex(9)?.int32Value ?? 50) / 100)),
            artworkData: nil,
            artworkURL: artworkURL
        )
    }

    private func readAppleMusicState() async -> ShellProviderState? {
        let script =
            """
            tell application "Music"
                try
                    set playerState to player state is playing
                    set currentTrackName to name of current track
                    set currentTrackArtist to artist of current track
                    set currentTrackAlbum to album of current track
                    set trackPosition to player position
                    set trackDuration to duration of current track
                    set shuffleState to shuffle enabled
                    set repeatState to song repeat
                    if repeatState is off then
                        set repeatValue to 0
                    else if repeatState is all then
                        set repeatValue to 1
                    else
                        set repeatValue to 2
                    end if
                    set currentVolume to sound volume
                    set persistentID to persistent ID of current track
                    try
                        set artData to data of artwork 1 of current track
                    on error
                        set artData to ""
                    end try
                    return {playerState, currentTrackName, currentTrackArtist, currentTrackAlbum, trackPosition, trackDuration, shuffleState, repeatValue, currentVolume, persistentID, artData}
                on error
                    return {false, "Not Playing", "Apple Music", "Apple Music", 0, 0, false, 0, 50, "apple-music-idle", ""}
                end try
            end tell
            """
        guard let descriptor = await scriptRunner.execute(script), descriptor.numberOfItems >= 11 else {
            return nil
        }
        let repeatValue = descriptor.atIndex(8)?.int32Value ?? 0
        let repeatMode = ShellMediaRepeatState(rawValue: Int(repeatValue)) ?? .off
        let id = descriptor.atIndex(10)?.stringValue ?? UUID().uuidString
        let artworkData = descriptor.atIndex(11)?.data
        return ShellProviderState(
            trackID: id,
            title: descriptor.atIndex(2)?.stringValue ?? "Unknown",
            artist: descriptor.atIndex(3)?.stringValue ?? "Unknown",
            album: descriptor.atIndex(4)?.stringValue ?? "Apple Music",
            elapsedSeconds: max(0, Int(descriptor.atIndex(5)?.doubleValue ?? 0)),
            durationSeconds: max(0, Int(descriptor.atIndex(6)?.doubleValue ?? 0)),
            isPlaying: descriptor.atIndex(1)?.booleanValue ?? false,
            isShuffled: descriptor.atIndex(7)?.booleanValue ?? false,
            repeatMode: repeatMode,
            volume: max(0, min(1, Double(descriptor.atIndex(9)?.int32Value ?? 50) / 100)),
            artworkData: artworkData,
            artworkURL: nil
        )
    }

    private func readAppleMusicRecent(source: ShellMediaProvider) async -> [ShellMediaTrackItem] {
        let script =
            """
            tell application "Music"
                try
                    set currentIndex to index of current track
                    set lowerBound to currentIndex - 12
                    if lowerBound < 1 then set lowerBound to 1
                    set recentItems to {}
                    if currentIndex > 1 then
                        repeat with i from (currentIndex - 1) to lowerBound by -1
                            set t to track i of current playlist
                            set end of recentItems to {name of t, artist of t, album of t, duration of t}
                        end repeat
                    end if
                    return recentItems
                on error
                    return {}
                end try
            end tell
            """
        guard let descriptor = await scriptRunner.execute(script), descriptor.numberOfItems > 0 else {
            return []
        }

        var items: [ShellMediaTrackItem] = []
        for idx in 1...descriptor.numberOfItems {
            guard
                let row = descriptor.atIndex(idx),
                row.numberOfItems >= 4
            else {
                continue
            }
            let title = row.atIndex(1)?.stringValue ?? "Unknown"
            let artist = row.atIndex(2)?.stringValue ?? "Unknown"
            let album = row.atIndex(3)?.stringValue ?? "Apple Music"
            let duration = max(0, Int(row.atIndex(4)?.doubleValue ?? 0))
            items.append(
                ShellMediaTrackItem(
                    id: "apple-recent-\(idx)-\(title)-\(artist)",
                    title: title,
                    artist: artist,
                    collection: album,
                    durationSeconds: duration,
                    source: source,
                    queuePosition: nil,
                    playedAtLabel: nil
                )
            )
        }
        return items
    }

    private func readSpotifyRecent(source: ShellMediaProvider) async -> [ShellMediaTrackItem] {
        let script =
            """
            tell application "Spotify"
                try
                    set currentIndex to index of current track
                    set lowerBound to currentIndex - 12
                    if lowerBound < 1 then set lowerBound to 1
                    set recentItems to {}
                    if currentIndex > 1 then
                        repeat with i from (currentIndex - 1) to lowerBound by -1
                            set t to track i of current playlist
                            set end of recentItems to {name of t, artist of t, album of t, duration of t}
                        end repeat
                    end if
                    return recentItems
                on error
                    return {}
                end try
            end tell
            """
        guard let descriptor = await scriptRunner.execute(script), descriptor.numberOfItems > 0 else {
            return []
        }

        var items: [ShellMediaTrackItem] = []
        for idx in 1...descriptor.numberOfItems {
            guard
                let row = descriptor.atIndex(idx),
                row.numberOfItems >= 4
            else {
                continue
            }
            let title = row.atIndex(1)?.stringValue ?? "Unknown"
            let artist = row.atIndex(2)?.stringValue ?? "Unknown"
            let album = row.atIndex(3)?.stringValue ?? "Spotify"
            let durationMs = max(0, Int(row.atIndex(4)?.doubleValue ?? 0))
            items.append(
                ShellMediaTrackItem(
                    id: "spotify-recent-\(idx)-\(title)-\(artist)",
                    title: title,
                    artist: artist,
                    collection: album,
                    durationSeconds: durationMs / 1000,
                    source: source,
                    queuePosition: nil,
                    playedAtLabel: nil
                )
            )
        }
        return items
    }

    private func isRunning(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier })
    }

    private func openApp(bundleIdentifier: String) async -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
                continuation.resume(returning: app != nil && error == nil)
            }
        }
    }

    private func executeSpotify(_ command: String) async {
        let script = "tell application \"Spotify\" to \(command)"
        _ = await scriptRunner.execute(script)
    }

    private func executeAppleMusic(_ command: String) async {
        let script = "tell application \"Music\" to \(command)"
        _ = await scriptRunner.execute(script)
    }

    private func escapeAppleScript(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private struct ShellProviderState {
    let trackID: String
    let title: String
    let artist: String
    let album: String
    let elapsedSeconds: Int
    let durationSeconds: Int
    let isPlaying: Bool
    let isShuffled: Bool
    let repeatMode: ShellMediaRepeatState
    let volume: Double
    let artworkData: Data?
    let artworkURL: String?
}

private actor ShellAppleScriptRunner {
    func execute(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        return script?.executeAndReturnError(&error)
    }
}

private actor ShellArtworkFetcher {
    func fetchImageData(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}
