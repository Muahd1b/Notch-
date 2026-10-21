import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct SourceSelectionSection: View {
    let title: String
    let sources: [SelectableSource]
    @Binding var selection: Set<String>
    let disabled: Bool

    var body: some View {
        Section {
            if sources.isEmpty {
                Text("No sources available yet. Connect access above, then reload.")
                    .foregroundStyle(.secondary)
            }
            ForEach(sources) { source in
                Button {
                    if selection.contains(source.id) {
                        selection.remove(source.id)
                    } else {
                        selection.insert(source.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(source.color)
                            .frame(width: 20, height: 20)
                            .overlay {
                                if selection.contains(source.id) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                        Text(source.name)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        } header: {
            Text(title)
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Controll Notch")
                    .font(.headline)
                Text("Developer command center for the notch.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("About")
    }
}

struct SettingsSectionHeader: View {
    let title: String
    let badge: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.08), in: Capsule())
            }
        }
    }
}

struct SelectableSource: Identifiable {
    let id: String
    let name: String
    let color: Color
}

extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}

func formatHour(_ value: Double) -> String {
    let hour = Int(value.rounded())
    let suffix = hour < 12 ? "AM" : "PM"
    let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    return "\(displayHour):00 \(suffix)"
}

func gestureSensitivityLabel(_ value: Double) -> String {
    switch value {
    case ..<0.34:
        return "Low"
    case ..<0.67:
        return "Medium"
    default:
        return "High"
    }
}
