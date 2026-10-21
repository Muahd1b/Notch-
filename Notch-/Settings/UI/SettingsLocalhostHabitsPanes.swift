import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct LocalhostSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable localhost monitoring", isOn: $settings.localhostMonitoringEnabled)
                Toggle("Show localhost in closed state", isOn: $settings.localhostClosedStateEnabled)
                    .disabled(!settings.localhostMonitoringEnabled)
                Toggle("Show healthy services", isOn: $settings.localhostShowHealthyServices)
                    .disabled(!settings.localhostMonitoringEnabled)
            } header: {
                Text("Service registry")
            }

            Section {
                LabeledContent("Refresh interval") {
                    Text("\(Int(settings.localhostRefreshInterval))s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.localhostRefreshInterval, in: 2...30, step: 1)
                    .disabled(!settings.localhostMonitoringEnabled)

                LabeledContent("Failure debounce") {
                    Text("\(settings.localhostFailureDebounce, specifier: "%.1f")s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.localhostFailureDebounce, in: 0.5...10, step: 0.5)
                    .disabled(!settings.localhostMonitoringEnabled)
            } header: {
                Text("Polling")
            }
        }
        .navigationTitle("Localhost")
    }
}

struct HabitsSettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    let runtimeServices: CoreRuntimeServices?
    @State private var habits: [ShellHabitProgress] = []
    @State private var newHabitTitle = ""
    @State private var newHabitTarget = 1
    @State private var isMutating = false
    @State private var feedback: String?
    @State private var feedbackIsError = false
    @State private var draggedHabitID: String?

    var body: some View {
        Form {
            Section {
                Toggle("Enable habits", isOn: $settings.habitsEnabled)
                Toggle("Show habits in closed state", isOn: $settings.habitsClosedStateEnabled)
                    .disabled(!settings.habitsEnabled)
                Toggle("Daily reminders", isOn: $settings.habitsReminderEnabled)
                    .disabled(!settings.habitsEnabled)
            } header: {
                Text("Daily tracking")
            }

            Section {
                LabeledContent("Reset hour") {
                    Text(formatHour(settings.habitsDailyResetHour))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.habitsDailyResetHour, in: 0...23, step: 1)
                    .disabled(!settings.habitsEnabled)
            } header: {
                Text("Schedule")
            }

            Section {
                TextField("Habit name", text: $newHabitTitle)
                    .disabled(!settings.habitsEnabled || isMutating)

                Stepper(value: $newHabitTarget, in: 1...20) {
                    Text("Daily target: \(newHabitTarget)")
                }
                .disabled(!settings.habitsEnabled || isMutating)

                Button("Create habit") {
                    Task { await createHabit() }
                }
                .disabled(!settings.habitsEnabled || isMutating || newHabitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Habit library")
            }

            Section {
                if habits.isEmpty {
                    Text("No habits yet. Create your first habit above.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(habits) { habit in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.title)
                                Text("Daily target: \(max(1, habit.targetUnits))")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await deleteHabit(id: habit.id) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isMutating)
                        }
                        .contentShape(Rectangle())
                        .onDrag {
                            draggedHabitID = habit.id
                            return NSItemProvider(object: NSString(string: habit.id))
                        }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: HabitsDropDelegate(
                                targetHabitID: habit.id,
                                habits: $habits,
                                draggedHabitID: $draggedHabitID,
                                onMove: moveHabits
                            )
                        )
                    }
                }
            } header: {
                Text("Current habits")
            } footer: {
                Text("Drag and drop habits to define the order used in settings and the shell.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Delete mock data", role: .destructive) {
                    Task { await deleteMockData() }
                }
                .disabled(isMutating)
                Text("Removes legacy seeded habits and learning entries from earlier builds.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Data")
            }

            if let feedback {
                Section {
                    Text(feedback)
                        .foregroundStyle(feedbackIsError ? .red : .secondary)
                }
            }
        }
        .task {
            await reloadHabits()
        }
        .navigationTitle("Habits")
    }

    private func reloadHabits() async {
        guard let runtime = runtimeServices ?? CoreRuntimeServices.shared else {
            habits = []
            return
        }
        habits = await runtime.habitsForSettings()
    }

    private func createHabit() async {
        guard let runtime = runtimeServices ?? CoreRuntimeServices.shared else {
            feedback = "Habits runtime is unavailable."
            feedbackIsError = true
            return
        }

        let title = newHabitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        isMutating = true
        defer { isMutating = false }

        let created = await runtime.createHabit(title: title, targetUnits: newHabitTarget)
        await reloadHabits()

        if created {
            newHabitTitle = ""
            newHabitTarget = 1
            feedback = "Habit created."
            feedbackIsError = false
        } else {
            feedback = "Could not create habit. Check if a habit with the same name already exists."
            feedbackIsError = true
        }
    }

    private func deleteHabit(id: String) async {
        guard let runtime = runtimeServices ?? CoreRuntimeServices.shared else {
            feedback = "Habits runtime is unavailable."
            feedbackIsError = true
            return
        }

        isMutating = true
        defer { isMutating = false }

        let deleted = await runtime.deleteHabit(id: id)
        await reloadHabits()

        if deleted {
            feedback = "Habit deleted."
            feedbackIsError = false
        } else {
            feedback = "Could not delete habit."
            feedbackIsError = true
        }
    }

    private func moveHabits(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)

        Task {
            guard let runtime = runtimeServices ?? CoreRuntimeServices.shared else {
                feedback = "Habits runtime is unavailable."
                feedbackIsError = true
                await reloadHabits()
                return
            }

            let reordered = await runtime.reorderHabits(fromOffsets: source, toOffset: destination)
            if !reordered {
                feedback = "Could not persist habits order."
                feedbackIsError = true
                await reloadHabits()
            }
        }
    }

    private func deleteMockData() async {
        guard let runtime = runtimeServices ?? CoreRuntimeServices.shared else {
            feedback = "Habits runtime is unavailable."
            feedbackIsError = true
            return
        }

        isMutating = true
        defer { isMutating = false }

        let deleted = await runtime.deleteLegacyMockHabitsLearningData()
        await reloadHabits()

        if deleted {
            feedback = "Legacy mock data deleted."
            feedbackIsError = false
        } else {
            feedback = "No legacy mock data found."
            feedbackIsError = false
        }
    }
}

struct HabitsDropDelegate: DropDelegate {
    let targetHabitID: String
    @Binding var habits: [ShellHabitProgress]
    @Binding var draggedHabitID: String?
    let onMove: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedHabitID,
              draggedHabitID != targetHabitID,
              let fromIndex = habits.firstIndex(where: { $0.id == draggedHabitID }),
              let targetIndex = habits.firstIndex(where: { $0.id == targetHabitID }) else {
            return
        }

        let destination = targetIndex > fromIndex ? targetIndex + 1 : targetIndex
        onMove(IndexSet(integer: fromIndex), destination)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedHabitID = nil
        return true
    }
}
