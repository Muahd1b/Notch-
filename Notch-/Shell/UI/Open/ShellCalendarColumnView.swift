import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellHomeSummaryView: View {
    let statusSnapshot: ShellStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Home")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Text("Live Overview")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 8) {
                overviewCard(
                    symbol: "calendar",
                    label: "Calendar",
                    value: "\(statusSnapshot.calendarEvents.count)"
                )
                overviewCard(
                    symbol: "server.rack",
                    label: "Hosts",
                    value: "\(statusSnapshot.localhostServices.filter { $0.status == .healthy }.count)/\(statusSnapshot.localhostServices.count)"
                )
                overviewCard(
                    symbol: "checkmark.circle.fill",
                    label: "Habits",
                    value: "\(statusSnapshot.habits.filter { $0.progressValue >= 1 }.count)/\(statusSnapshot.habits.count)"
                )
                overviewCard(
                    symbol: "brain.head.profile",
                    label: "Learn",
                    value: "\(statusSnapshot.learningSignals.count)"
                )
            }

            HStack(spacing: 8) {
                summaryPill(title: "Focus", value: statusSnapshot.focusLabel)
                summaryPill(title: "Next", value: statusSnapshot.nextEventLabel)
                summaryPill(title: "Local", value: statusSnapshot.hostStatusLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewCard(symbol: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryPill(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.045), in: Capsule())
    }
}

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

@MainActor
struct ShellFocusTimerPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    @ObservedObject private var settings = AppSettingsStore.shared

    var body: some View {
        GeometryReader { proxy in
            let layout = layoutMetrics(for: proxy.size.height)

            HStack(alignment: .top, spacing: layout.columnSpacing) {
                rightTimerColumn(compact: layout.isCompact)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                leftControlsColumn(compact: layout.isCompact)
                    .frame(width: layout.controlsWidth, alignment: .topTrailing)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func leftControlsColumn(compact: Bool) -> some View {
        let focusRecords = viewModel.focusSessionRecords.filter { $0.phase == .focus }
        let totalFocusMinutes = focusRecords.reduce(0) { $0 + max(0, $1.durationSeconds / 60) }

        return VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: compact ? 6 : 8) {
                metricCard(title: "Sessions", value: "\(focusRecords.count)", compact: compact)
                metricCard(title: "Minutes", value: "\(totalFocusMinutes)", compact: compact)
            }

            Spacer(minLength: compact ? 4 : 6)

            HStack(spacing: compact ? 6 : 8) {
                compactActionButton(
                    title: "Focus \(Int(settings.focusDurationMinutes))m",
                    symbol: "play.fill",
                    compact: compact,
                    action: viewModel.startFocusSession
                )
                compactActionButton(
                    title: viewModel.focusIsPaused ? "Resume" : "Pause",
                    symbol: viewModel.focusIsPaused ? "play.fill" : "pause.fill",
                    compact: compact,
                    isEnabled: viewModel.focusTimerIsRunning,
                    action: viewModel.toggleFocusPauseResume
                )
            }

            HStack(spacing: compact ? 6 : 8) {
                compactActionButton(
                    title: "Break \(Int(settings.shortBreakMinutes))m",
                    symbol: "cup.and.saucer.fill",
                    compact: compact,
                    action: viewModel.startBreakSession
                )
                compactActionButton(
                    title: "Stop",
                    symbol: "stop.fill",
                    compact: compact,
                    isEnabled: viewModel.focusTimerIsRunning,
                    action: viewModel.stopFocusSession
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func rightTimerColumn(compact: Bool) -> some View {
        GeometryReader { timerProxy in
            let fontSize = timerFontSize(in: timerProxy.size)

            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                Spacer(minLength: 0)

                Text(viewModel.focusRemainingLabel)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: compact ? 6 : 8) {
                    Text(viewModel.focusTimerPhase.title.uppercased())
                        .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))

                    if viewModel.focusIsPaused {
                        Text("Paused")
                            .font(.system(size: compact ? 11 : 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 8 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func compactActionButton(
        title: String,
        symbol: String,
        compact: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: compact ? 5 : 6) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                Text(title)
                    .font(.system(size: compact ? 10 : 10.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(isEnabled ? 0.92 : 0.5))
            .padding(.horizontal, compact ? 8 : 9)
            .padding(.vertical, compact ? 6 : 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
    }

    private func metricCard(title: String, value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            Text(title)
                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 9)
        .padding(.vertical, compact ? 6 : 7)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func layoutMetrics(for height: CGFloat) -> FocusLayoutMetrics {
        let boundedHeight = max(height, 96)
        let isCompact = boundedHeight < 132
        let controlsWidth: CGFloat = isCompact ? 286 : 304
        let columnSpacing: CGFloat = isCompact ? 8 : 10

        return FocusLayoutMetrics(
            isCompact: isCompact,
            controlsWidth: controlsWidth,
            columnSpacing: columnSpacing
        )
    }

    private func timerFontSize(in size: CGSize) -> CGFloat {
        let widthDriven = size.width * 0.36
        let heightDriven = size.height * 0.62
        return max(52, min(widthDriven, heightDriven))
    }

    private struct FocusLayoutMetrics {
        let isCompact: Bool
        let controlsWidth: CGFloat
        let columnSpacing: CGFloat
    }
}

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

final class ShellHUDCameraService: ObservableObject {
    static let shared = ShellHUDCameraService()

    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var isSessionRunning = false
    @Published private(set) var cameraAvailable = false
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var statusMessage = "Camera idle"

    private let sessionQueue = DispatchQueue(label: "Notch.HUD.Camera.SessionQueue", qos: .userInitiated)
    private var captureSession: AVCaptureSession?

    private init() {
        refreshState()
    }

    func refreshState() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .denied || status == .restricted {
                self.statusMessage = "Camera access denied"
            }
        }
        checkCameraAvailability()
    }

    func toggleSession() {
        if isSessionRunning {
            stopSession()
        } else {
            startSession()
        }
    }

    func startSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        switch status {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authorizationStatus = granted ? .authorized : .denied
                    self.statusMessage = granted ? "Camera ready" : "Camera access denied"
                    if granted {
                        self.checkCameraAvailability()
                        self.configureAndStartSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.statusMessage = "Camera access denied"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.statusMessage = "Camera unavailable"
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            let session = self.captureSession
            self.captureSession = nil

            if let session {
                if session.isRunning {
                    session.stopRunning()
                }
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                for output in session.outputs {
                    session.removeOutput(output)
                }
                session.commitConfiguration()
            }

            DispatchQueue.main.async {
                self.previewLayer = nil
                self.isSessionRunning = false
                self.statusMessage = "Camera stopped"
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private func checkCameraAvailability() {
        let availableDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        let hasDevices = !availableDevices.isEmpty
        DispatchQueue.main.async {
            self.cameraAvailable = hasDevices
            if !hasDevices {
                self.statusMessage = "No camera detected"
            }
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async {
            if let session = self.captureSession {
                if !session.isRunning {
                    session.startRunning()
                }
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                DispatchQueue.main.async {
                    self.previewLayer = layer
                    self.isSessionRunning = session.isRunning
                    self.statusMessage = session.isRunning ? "Camera live" : "Camera idle"
                }
                return
            }

            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                mediaType: .video,
                position: .unspecified
            )

            guard let videoDevice = self.preferredVideoDevice(from: discoverySession.devices) else {
                DispatchQueue.main.async {
                    self.cameraAvailable = false
                    self.statusMessage = "No camera detected"
                }
                return
            }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .high

            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                guard session.canAddInput(input) else {
                    DispatchQueue.main.async {
                        self.statusMessage = "Camera input unavailable"
                    }
                    session.commitConfiguration()
                    return
                }

                session.addInput(input)

                session.commitConfiguration()
                session.startRunning()
                self.captureSession = session

                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill

                DispatchQueue.main.async {
                    self.previewLayer = layer
                    self.cameraAvailable = true
                    self.isSessionRunning = session.isRunning
                    self.statusMessage = session.isRunning ? "Camera live" : "Camera idle"
                }
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.statusMessage = "Camera failed: \(error.localizedDescription)"
                    self.isSessionRunning = false
                    self.previewLayer = nil
                }
            }
        }
    }

    private func preferredVideoDevice(from devices: [AVCaptureDevice]) -> AVCaptureDevice? {
        if let builtInFront = devices.first(where: {
            $0.deviceType == .builtInWideAngleCamera && $0.position == .front
        }) {
            return builtInFront
        }

        if let builtIn = devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            return builtIn
        }

        if let externalNonPhone = devices.first(where: {
            ($0.deviceType == .external || $0.deviceType == .continuityCamera)
                && !$0.localizedName.localizedCaseInsensitiveContains("iphone")
        }) {
            return externalNonPhone
        }

        return devices.first
    }
}

final class ShellHUDScreenStreamService: ObservableObject {
    static let shared = ShellHUDScreenStreamService()

    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var isSessionRunning = false
    @Published private(set) var hasScreenRecordingAccess = CGPreflightScreenCaptureAccess()
    @Published private(set) var didAttemptPermissionRequest = false
    @Published private(set) var statusMessage = "Stream idle"

    private let sessionQueue = DispatchQueue(label: "Notch.HUD.Stream.SessionQueue", qos: .userInitiated)
    private var captureSession: AVCaptureSession?

    private init() {
        refreshState()
    }

    func refreshState() {
        let access = CGPreflightScreenCaptureAccess()
        DispatchQueue.main.async {
            self.hasScreenRecordingAccess = access
            if !access {
                self.statusMessage = "Screen recording permission required"
            }
        }
    }

    func toggleSession() {
        if isSessionRunning {
            stopSession()
        } else {
            startSession()
        }
    }

    func startSession() {
        let access = CGPreflightScreenCaptureAccess()
        DispatchQueue.main.async {
            self.hasScreenRecordingAccess = access
        }

        if !access {
            didAttemptPermissionRequest = true
            let granted = CGRequestScreenCaptureAccess()
            DispatchQueue.main.async {
                self.hasScreenRecordingAccess = granted
                self.statusMessage = granted ? "Stream ready" : "Screen recording permission required"
            }
            guard granted else { return }
        }

        configureAndStartSession()
    }

    func stopSession() {
        sessionQueue.async {
            let session = self.captureSession
            self.captureSession = nil

            if let session {
                if session.isRunning {
                    session.stopRunning()
                }
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                for output in session.outputs {
                    session.removeOutput(output)
                }
                session.commitConfiguration()
            }

            DispatchQueue.main.async {
                self.previewLayer = nil
                self.isSessionRunning = false
                self.statusMessage = "Stream stopped"
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    private func configureAndStartSession() {
        sessionQueue.async {
            if let session = self.captureSession {
                if !session.isRunning {
                    session.startRunning()
                }
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                DispatchQueue.main.async {
                    self.previewLayer = layer
                    self.isSessionRunning = session.isRunning
                    self.statusMessage = session.isRunning ? "Streaming main display" : "Stream idle"
                }
                return
            }

            guard let screenInput = AVCaptureScreenInput(displayID: CGMainDisplayID()) else {
                DispatchQueue.main.async {
                    self.statusMessage = "Display capture unavailable"
                }
                return
            }

            screenInput.minFrameDuration = CMTime(value: 1, timescale: 30)
            screenInput.capturesCursor = true
            screenInput.capturesMouseClicks = true

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .high

            guard session.canAddInput(screenInput) else {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.statusMessage = "Display input unavailable"
                }
                return
            }

            session.addInput(screenInput)

            let output = AVCaptureVideoDataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()
            session.startRunning()
            self.captureSession = session

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill

            DispatchQueue.main.async {
                self.previewLayer = layer
                self.isSessionRunning = session.isRunning
                self.statusMessage = session.isRunning ? "Streaming main display" : "Stream idle"
            }
        }
    }
}

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
