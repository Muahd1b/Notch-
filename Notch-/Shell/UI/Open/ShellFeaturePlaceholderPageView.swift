import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellFeaturePlaceholderPageView: View {
    let title: String
    let subtitle: String
    let metric: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(metric.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.white.opacity(0.07), in: Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
