import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellLocalhostPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    let statusSnapshot: ShellStatusSnapshot

    @State private var selectedServiceID: String?

    var body: some View {
        HStack(spacing: 12) {
            serviceListColumn
                .frame(width: 280, alignment: .topLeading)
            serviceMetricsColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedServiceID == nil {
                selectedServiceID = statusSnapshot.localhostServices.first?.id
            }
            viewModel.localhostPageAppeared()
        }
    }

    private var serviceListColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Localhost Services")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(statusSnapshot.localhostServices) { service in
                        Button {
                            selectedServiceID = service.id
                            viewModel.playSelectionHaptic()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(statusColor(service.status))
                                    .frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.name)
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(service.endpoint)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Text(statusLabel(service.status))
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                (selectedServiceID == service.id ? .white.opacity(0.11) : .white.opacity(0.05)),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var serviceMetricsColumn: some View {
        let healthyCount = statusSnapshot.localhostServices.filter { $0.status == .healthy }.count
        let totalRam = statusSnapshot.localhostServices.reduce(0) { $0 + $1.ramUsageMB }
        let selected = statusSnapshot.localhostServices.first { $0.id == selectedServiceID } ?? statusSnapshot.localhostServices.first

        return VStack(alignment: .leading, spacing: 8) {
            Text("Runtime Metrics")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: 8) {
                metricCard(title: "Healthy", value: "\(healthyCount)/\(statusSnapshot.localhostServices.count)")
                metricCard(title: "RAM", value: "\(totalRam) MB")
            }

            if let selected {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selected.name)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    metricTrack(label: "RAM", value: selected.ramUsageMB, maxValue: 1024)
                    metricTrack(label: "CPU", value: selected.cpuPercent, maxValue: 100)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricTrack(label: String, value: Int, maxValue: Int) -> some View {
        let normalized = min(1, max(0, Double(value) / Double(maxValue)))
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Text("\(value)")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.09))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.white.opacity(0.58))
                            .frame(width: proxy.size.width * normalized)
                    }
            }
            .frame(height: 6)
        }
    }

    private func statusColor(_ status: ShellLocalhostServiceStatus) -> Color {
        switch status {
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .down:
            return .red
        }
    }

    private func statusLabel(_ status: ShellLocalhostServiceStatus) -> String {
        switch status {
        case .healthy:
            return "UP"
        case .degraded:
            return "DEGRADED"
        case .down:
            return "DOWN"
        }
    }
}
