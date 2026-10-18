import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellHabitsPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    let statusSnapshot: ShellStatusSnapshot

    var body: some View {
        GeometryReader { proxy in
            let rightWidth = min(320, max(250, proxy.size.width * 0.35))

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    habitsColumn
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    metricsColumn
                        .frame(width: rightWidth, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
                .padding(.bottom, 10)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .onAppear {
            viewModel.habitsPageAppeared()
        }
    }

    private var habitsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Habits")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            if statusSnapshot.habits.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No habits yet")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Create habits in Settings > Habits.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(14)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(statusSnapshot.habits) { habit in
                        habitCard(habit)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var metricsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Habits Metrics")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: 8) {
                metricCard(title: "Completed", value: "\(completedHabits)")
                metricCard(title: "Remaining", value: "\(remainingHabits)")
            }

            metricCard(title: "Best Streak", value: "\(maxStreak)d")

            VStack(alignment: .leading, spacing: 4) {
                Text("Track completion directly from this page.")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                Text("Create and manage habits in Settings > Habits.")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Spacer(minLength: 0)
        }
    }

    private func habitCard(_ habit: ShellHabitProgress) -> some View {
        let targetUnits = max(1, habit.targetUnits)
        let isCompleted = habit.completedUnits >= targetUnits

        return Button {
            viewModel.toggleHabitCompletion(id: habit.id)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCompleted ? .white.opacity(0.9) : .white.opacity(0.52))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(habit.title)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(habit.completedUnits)/\(targetUnits)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    ProgressView(value: habit.progressValue)
                        .tint(.white.opacity(0.82))
                        .scaleEffect(y: 0.88)

                    Text("Streak \(habit.streakDays)d")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shell-habit-toggle-\(habit.id)")
    }

    private var completedHabits: Int {
        statusSnapshot.habits.filter { $0.progressValue >= 1 }.count
    }

    private var remainingHabits: Int {
        max(0, statusSnapshot.habits.count - completedHabits)
    }

    private var maxStreak: Int {
        statusSnapshot.habits.map(\.streakDays).max() ?? 0
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
}
