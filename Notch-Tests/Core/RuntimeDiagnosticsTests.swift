import Foundation
import Testing
@testable import Notch_

struct RuntimeDiagnosticsTests {
    @Test
    func diagnosticsTrimToConfiguredMaximum() async {
        let diagnostics = RuntimeDiagnostics(maxEntries: 2)

        await diagnostics.record(level: .info, message: "one", source: "tests")
        await diagnostics.record(level: .warning, message: "two", source: "tests")
        await diagnostics.record(level: .error, message: "three", source: "tests")

        let entries = await diagnostics.allEntries()
        #expect(entries.count == 2)
        #expect(entries[0].message == "two")
        #expect(entries[1].message == "three")
    }

    @Test
    func diagnosticsCanPublishTransientEvents() async {
        let eventBus = NotchEventBus()
        let diagnostics = RuntimeDiagnostics(maxEntries: 10, eventBus: eventBus)
        let subscription = await eventBus.subscribe()

        let receiveTask = Task<NotchEvent?, Never> {
            var iterator = subscription.stream.makeAsyncIterator()
            return await iterator.next()
        }

        await diagnostics.record(level: .warning, message: "adapter degraded", source: "tests")
        let event = await receiveTask.value

        #expect(event?.kind == .transientEventRaised)
        #expect(event?.source == "diagnostics")
        await eventBus.unsubscribe(id: subscription.id)
    }
}
