import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellCalendarPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    let statusSnapshot: ShellStatusSnapshot

    @ObservedObject private var settings = AppSettingsStore.shared
    @State private var selectedEventID: String?
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var carouselScrollPosition: Int?
    @State private var carouselByClick = false
    @State private var carouselHaptics = false
    private let quickActionButtonHeight: CGFloat = 50
    private let timelineViewportHeight: CGFloat = 64
    private let carouselPastDays = 7
    private let carouselFutureDays = 14
    private let carouselStep = 1
    private let carouselOffset = 2

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            quickCreateColumn
                .frame(width: 200, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)

            eventsColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            selectedDate = Calendar.current.startOfDay(for: Date())
            viewModel.calendarPageAppeared()
        }
        .sensoryFeedback(.alignment, trigger: carouselHaptics)
    }

    private var quickCreateColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            hapticActionButton(
                title: "New Event",
                symbol: "calendar.badge.plus",
                action: { viewModel.createCalendarEvent() }
            )
            .frame(
                maxWidth: .infinity,
                minHeight: quickActionButtonHeight,
                maxHeight: quickActionButtonHeight,
                alignment: .leading
            )

            hapticActionButton(
                title: "New Reminder",
                symbol: "list.bullet.clipboard",
                action: { viewModel.createReminder() }
            )
            .frame(
                maxWidth: .infinity,
                minHeight: quickActionButtonHeight,
                maxHeight: quickActionButtonHeight,
                alignment: .leading
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var eventsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(selectedDate.formatted(.dateTime.year()))
                        .font(.system(size: 17, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(width: 74, alignment: .leading)

                ZStack {
                    dayCarousel
                    HStack {
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                        Spacer()
                        LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                    }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58)

                Text("Next \(Int(settings.calendarLookaheadHours))h")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            timelineViewport
                .frame(
                    maxWidth: .infinity,
                    minHeight: timelineViewportHeight,
                    maxHeight: timelineViewportHeight,
                    alignment: .top
                )
        }
    }

    @ViewBuilder
    private var timelineViewport: some View {
        if displayEvents.isEmpty {
            VStack(spacing: 7) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
                Text(Calendar.current.isDateInToday(selectedDate) ? "No events today" : "No events")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Enjoy your free time")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(displayEvents) { event in
                            HStack(alignment: .top, spacing: 6) {
                                Rectangle()
                                    .fill(sourceColor(for: event))
                                    .frame(width: 3)
                                    .cornerRadius(1.5)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(event.title)
                                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(settings.alwaysShowFullEventTitles ? nil : 2)

                                        if event.isReminder {
                                            Text("REM")
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.72))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(.white.opacity(0.08), in: Capsule())
                                        }
                                    }

                                    if !event.location.isEmpty {
                                        Text(event.location)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.58))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 0)

                                VStack(alignment: .trailing, spacing: 2) {
                                    if event.isAllDay {
                                        Text("All-day")
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.92))
                                    } else {
                                        Text(event.startAt, style: .time)
                                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.95))
                                        Text(event.endAt, style: .time)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.58))
                                    }
                                }
                            }
                            .opacity(event.isCompleted ? 0.42 : 1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                (selectedEventID == event.id ? .white.opacity(0.11) : .white.opacity(0.05)),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEventID = event.id
                                viewModel.playSelectionHaptic()
                            }
                            .id(event.id)
                        }
                    }
                }
                .scrollDisabled(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .onAppear {
                    guard settings.autoScrollToNextEvent else { return }
                    if let targetID = targetEventID(in: displayEvents) {
                        proxy.scrollTo(targetID, anchor: .top)
                    }
                }
                .onChange(of: displayEvents.map(\.id)) { _, _ in
                    guard settings.autoScrollToNextEvent else { return }
                    if let targetID = targetEventID(in: displayEvents) {
                        proxy.scrollTo(targetID, anchor: .top)
                    }
                }
            }
        }
    }

    private var dayCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                let spacerCount = carouselOffset
                let dateCount = totalCarouselDateItems()
                let totalItems = dateCount + 2 * spacerCount

                ForEach(0..<totalItems, id: \.self) { index in
                    if index < spacerCount || index >= spacerCount + dateCount {
                        Spacer()
                            .frame(width: 24, height: 24)
                            .id(index)
                    } else {
                        let date = dateForCarouselItemIndex(index: index, spacerCount: spacerCount)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let isToday = Calendar.current.isDateInToday(date)

                        Button {
                            selectDate(date, index: index)
                        } label: {
                            VStack(spacing: 8) {
                                Text(weekdayLabel(for: date))
                                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.62))

                                ZStack {
                                    Circle()
                                        .fill(isToday ? .blue.opacity(0.92) : .clear)
                                        .frame(width: 20, height: 20)

                                    Text(dayNumberLabel(for: date))
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(isSelected ? .white : .white.opacity(isToday ? 0.95 : 0.62))
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(
                                isSelected ? Color.blue.opacity(0.38) : .clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
            }
            .frame(height: 50)
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: $carouselScrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.horizontal)
        .onChange(of: carouselScrollPosition) { _, newValue in
            if !carouselByClick {
                handleCarouselScrollChange(newValue)
            } else {
                carouselByClick = false
            }
        }
        .onAppear {
            carouselByClick = true
            carouselScrollPosition = indexForCarouselDate(Date())
            selectedDate = Calendar.current.startOfDay(for: Date())
        }
        .onChange(of: selectedDate) { _, newValue in
            let targetIndex = indexForCarouselDate(newValue)
            if carouselScrollPosition != targetIndex {
                carouselByClick = true
                withAnimation {
                    carouselScrollPosition = targetIndex
                }
            }
        }
    }

    private var displayEvents: [ShellCalendarEvent] {
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        var dayEvents = statusSnapshot.calendarEvents.filter { event in
            event.startAt < dayEnd && event.endAt >= dayStart
        }

        if !settings.calendarShowAllDayEvents || settings.hideAllDayEvents {
            dayEvents = dayEvents.filter { !$0.isAllDay }
        }
        if settings.hideCompletedReminders {
            dayEvents = dayEvents.filter { !($0.isReminder && $0.isCompleted) }
        }

        if dayEvents.isEmpty && settings.calendarIncludeTomorrow && Calendar.current.isDateInToday(dayStart) {
            let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let tomorrowEnd = Calendar.current.date(byAdding: .day, value: 1, to: tomorrowStart) ?? tomorrowStart
            dayEvents = statusSnapshot.calendarEvents.filter { event in
                event.startAt < tomorrowEnd && event.endAt >= tomorrowStart
            }
        }

        return dayEvents.sorted(by: { $0.startAt < $1.startAt })
    }

    private func selectDate(_ date: Date, index: Int) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        selectedDate = normalizedDate
        carouselByClick = true
        withAnimation {
            carouselScrollPosition = index
        }
        triggerCarouselHaptic()
    }

    private func handleCarouselScrollChange(_ newValue: Int?) {
        guard let index = newValue else { return }
        let spacerCount = carouselOffset
        let dateCount = totalCarouselDateItems()
        guard (spacerCount..<(spacerCount + dateCount)).contains(index) else { return }

        let date = dateForCarouselItemIndex(index: index, spacerCount: spacerCount)
        let normalizedDate = Calendar.current.startOfDay(for: date)
        guard !Calendar.current.isDate(normalizedDate, inSameDayAs: selectedDate) else { return }

        selectedDate = normalizedDate
        triggerCarouselHaptic()
    }

    private func targetEventID(in events: [ShellCalendarEvent]) -> String? {
        guard !events.isEmpty else { return nil }

        let now = Date()
        let upcoming = events.first(where: { !$0.isAllDay && $0.endAt >= now && !$0.isCompleted })
        if let upcoming {
            return upcoming.id
        }
        return events.first?.id
    }

    private func weekdayLabel(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func dayNumberLabel(for date: Date) -> String {
        date.formatted(.dateTime.day())
    }

    private func totalCarouselDateItems() -> Int {
        let range = carouselPastDays + carouselFutureDays
        let step = max(carouselStep, 1)
        return Int(ceil(Double(range) / Double(step))) + 1
    }

    private func indexForCarouselDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -carouselPastDays, to: today) ?? today
        )
        let targetDate = calendar.startOfDay(for: date)
        let dayDelta = calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 0
        let stepIndex = max(0, min(dayDelta / max(carouselStep, 1), totalCarouselDateItems() - 1))
        return carouselOffset + stepIndex
    }

    private func dateForCarouselItemIndex(index: Int, spacerCount: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -carouselPastDays, to: today) ?? today
        let stepIndex = index - spacerCount
        return calendar.date(byAdding: .day, value: stepIndex * max(carouselStep, 1), to: startDate) ?? today
    }

    private func triggerCarouselHaptic() {
        guard settings.enableHaptics else { return }
        carouselHaptics.toggle()
    }

    private func hapticActionButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sourceColor(for event: ShellCalendarEvent) -> Color {
        if let sourceColorHex = event.sourceColorHex,
            let parsed = Color(hex: sourceColorHex)
        {
            return parsed
        }

        let palette: [Color] = [.blue, .mint, .orange, .pink, .purple, .teal, .red]
        let index = abs(event.sourceID.hashValue) % palette.count
        return palette[index]
    }
}

private extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6 || sanitized.count == 8 else { return nil }

        var int: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&int) else { return nil }

        let r, g, b, a: UInt64
        if sanitized.count == 8 {
            (r, g, b, a) = (
                (int >> 24) & 0xFF,
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        } else {
            (r, g, b, a) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF,
                0xFF
            )
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
