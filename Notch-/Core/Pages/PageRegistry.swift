import Foundation

enum NotchPage: String, CaseIterable, Sendable, Codable {
    case home
    case notifications
    case calendar
    case mediaControl
    case habits
    case agents
    case openclaw
    case focus
    case hud
    case localhost
    case financialBoard
}

struct PageRegistration: Equatable, Sendable, Codable {
    let page: NotchPage
    var isEnabled: Bool
    var sortOrder: Int
}

actor PageRegistry {
    private var registrations: [NotchPage: PageRegistration]

    init(pages: [NotchPage] = NotchPage.allCases) {
        var seeded: [NotchPage: PageRegistration] = [:]
        for (index, page) in pages.enumerated() {
            seeded[page] = PageRegistration(page: page, isEnabled: true, sortOrder: index)
        }
        registrations = seeded
    }

    func register(_ page: NotchPage, isEnabled: Bool = true, sortOrder: Int? = nil) {
        let normalizedOrder = sortOrder ?? (registrations.values.map(\.sortOrder).max() ?? -1) + 1
        registrations[page] = PageRegistration(page: page, isEnabled: isEnabled, sortOrder: normalizedOrder)
    }

    func setEnabled(_ isEnabled: Bool, for page: NotchPage) {
        guard var registration = registrations[page] else { return }
        registration.isEnabled = isEnabled
        registrations[page] = registration
    }

    func setSortOrder(_ sortOrder: Int, for page: NotchPage) {
        guard var registration = registrations[page] else { return }
        registration.sortOrder = sortOrder
        registrations[page] = registration
    }

    func registration(for page: NotchPage) -> PageRegistration? {
        registrations[page]
    }

    func allRegistrations() -> [PageRegistration] {
        registrations.values.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.page.rawValue < rhs.page.rawValue
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    func orderedEnabledPages() -> [NotchPage] {
        allRegistrations()
            .filter(\.isEnabled)
            .map(\.page)
    }
}
