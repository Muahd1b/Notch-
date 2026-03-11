import CoreGraphics

enum ShellSizing {
    nonisolated static let shadowPadding: CGFloat = 20
    nonisolated static let closedHoverHotspotHorizontalPadding: CGFloat = 36
    nonisolated static let closedHoverHotspotBottomPadding: CGFloat = 18
    nonisolated static let closedHoverActivationHorizontalInset: CGFloat = 16
    nonisolated static let closedHoverActivationVerticalInset: CGFloat = 2
    nonisolated static let openNotchSize = CGSize(width: 640, height: 190)
    nonisolated static let cornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) = (
        opened: (top: 19, bottom: 24),
        closed: (top: 6, bottom: 14)
    )
    nonisolated static let headerCapsuleSize = CGSize(width: 30, height: 30)
    nonisolated static let headerSpacing: CGFloat = 4
    nonisolated static let headerSideGroupSpacing: CGFloat = 2
    nonisolated static let headerTabSpacing: CGFloat = 2
    nonisolated static let headerCenterGapPadding: CGFloat = 12
    nonisolated static let headerStatusGroupSpacing: CGFloat = 3
    nonisolated static let headerLeadingInset: CGFloat = 12
    nonisolated static let headerTrailingInset: CGFloat = 12
    nonisolated static let openContentSpacing: CGFloat = 12
    nonisolated static let headerTabHeight: CGFloat = 24
    nonisolated static let headerTabButtonWidth: CGFloat = 23
    nonisolated static let headerActionButtonSize = CGSize(width: 30, height: 30)
    nonisolated static let artworkSize = CGSize(width: 100, height: 100)
}

struct ShellSizingSettings: Equatable {
    let notchHeightMode: WindowHeightMode
    let nonNotchHeightMode: WindowHeightMode
    let notchHeight: Double
    let nonNotchHeight: Double

    nonisolated static let `default` = ShellSizingSettings(
        notchHeightMode: .matchRealNotchSize,
        nonNotchHeightMode: .matchMenuBar,
        notchHeight: 38,
        nonNotchHeight: 24
    )
}
