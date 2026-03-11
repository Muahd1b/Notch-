import Testing
@testable import Notch_

struct PageRegistryTests {
    @Test
    func orderedEnabledPagesDefaultsToAllPagesInDeclaredOrder() async {
        let registry = PageRegistry()
        let pages = await registry.orderedEnabledPages()

        #expect(pages == NotchPage.allCases)
    }

    @Test
    func disablingPageRemovesItFromEnabledList() async {
        let registry = PageRegistry()
        await registry.setEnabled(false, for: .financialBoard)

        let pages = await registry.orderedEnabledPages()
        #expect(!pages.contains(.financialBoard))
    }

    @Test
    func changingSortOrderReordersOutput() async {
        let registry = PageRegistry()
        await registry.setSortOrder(-1, for: .localhost)

        let pages = await registry.orderedEnabledPages()
        #expect(pages.first == .localhost)
    }
}
