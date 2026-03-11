import Foundation
import Testing
@testable import Notch_

struct NotchEventBusTests {
    @Test
    func publishDeliversToSubscribers() async {
        let eventBus = NotchEventBus(maxBufferedEvents: 5)
        let subscription = await eventBus.subscribe()
        let expectedEvent = NotchEvent(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            kind: .signalChanged,
            source: "tests.eventbus",
            timestamp: Date(timeIntervalSince1970: 100),
            payload: .text("signal")
        )

        let receiveTask = Task<NotchEvent?, Never> {
            var iterator = subscription.stream.makeAsyncIterator()
            return await iterator.next()
        }

        await eventBus.publish(expectedEvent)
        let receivedEvent = await receiveTask.value

        #expect(receivedEvent == expectedEvent)
        await eventBus.unsubscribe(id: subscription.id)
    }

    @Test
    func recentEventsRespectsMaxBufferSize() async {
        let eventBus = NotchEventBus(maxBufferedEvents: 2)

        await eventBus.publish(
            NotchEvent(
                kind: .transientEventRaised,
                source: "tests.buffer",
                timestamp: Date(timeIntervalSince1970: 1),
                payload: .text("1")
            )
        )
        await eventBus.publish(
            NotchEvent(
                kind: .transientEventRaised,
                source: "tests.buffer",
                timestamp: Date(timeIntervalSince1970: 2),
                payload: .text("2")
            )
        )
        await eventBus.publish(
            NotchEvent(
                kind: .transientEventRaised,
                source: "tests.buffer",
                timestamp: Date(timeIntervalSince1970: 3),
                payload: .text("3")
            )
        )

        let recentEvents = await eventBus.recentEvents(limit: 10)

        #expect(recentEvents.count == 2)
        #expect(recentEvents[0].payload == .text("2"))
        #expect(recentEvents[1].payload == .text("3"))
    }
}
