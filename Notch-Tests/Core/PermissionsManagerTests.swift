import Foundation
import Testing
@testable import Notch_

@MainActor
struct PermissionsManagerTests {
    @Test
    func updateStatusMutatesSummaryAndPublishesEvent() async {
        let eventBus = NotchEventBus()
        let manager = PermissionsManager(eventBus: eventBus)
        let subscription = await eventBus.subscribe()

        let receiveTask = Task<NotchEvent?, Never> {
            var iterator = subscription.stream.makeAsyncIterator()
            return await iterator.next()
        }

        manager.updateStatus(.denied, for: .camera)
        let event = await receiveTask.value
        let summary = manager.summary()

        #expect(manager.status(for: .camera) == .denied)
        #expect(summary.deniedCount == 1)
        #expect(summary.needsSetupCount == PermissionDomain.allCases.count - 1)
        #expect(event?.kind == .signalChanged)
        #expect(event?.source == "permissions.camera")
        await eventBus.unsubscribe(id: subscription.id)
    }
}
