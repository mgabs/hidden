//
//  AutoCollapseCoordinatorTests.swift
//  HiddenBarTests
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import XCTest

final class AutoCollapseCoordinatorTests: XCTestCase {

    private final class FakeScheduler: AutoCollapseScheduling {
        final class Token {
            let id: Int
            let delay: TimeInterval
            let handler: () -> Void
            var cancelled = false

            init(id: Int, delay: TimeInterval, handler: @escaping () -> Void) {
                self.id = id
                self.delay = delay
                self.handler = handler
            }
        }

        private var nextID = 1
        private(set) var scheduled: [Token] = []

        var activeTokens: [Token] {
            scheduled.filter { !$0.cancelled }
        }

        func schedule(after delay: TimeInterval, handler: @escaping () -> Void) -> AnyObject {
            let token = Token(id: nextID, delay: delay, handler: handler)
            nextID += 1
            scheduled.append(token)
            return token
        }

        func cancel(_ token: AnyObject) {
            (token as? Token)?.cancelled = true
        }

        func fireLatest() {
            guard let token = activeTokens.last else {
                XCTFail("No active timer to fire")
                return
            }
            token.cancelled = true
            token.handler()
        }
    }

    private func makeSUT(
        scheduler: FakeScheduler = FakeScheduler(),
        autoHide: Bool = true,
        delay: TimeInterval = 10.0,
        collapsed: Bool = false,
        busy: Bool = false,
        accessibilityAuthorized: Bool = true
    ) -> (
        coordinator: AutoCollapseCoordinator,
        scheduler: FakeScheduler,
        setAutoHide: (Bool) -> Void,
        setCollapsed: (Bool) -> Void,
        setBusy: (Bool) -> Void,
        setAccessibility: (Bool) -> Void,
        setNextResult: (CollapseResult) -> Void,
        collapseCallCount: () -> Int,
        notifyCount: () -> Int
    ) {
        var isAutoHide = autoHide
        var isCollapsed = collapsed
        var isBusy = busy
        var isAX = accessibilityAuthorized
        var nextResult: CollapseResult = .collapsed
        var collapses = 0
        var notifies = 0

        let coordinator = AutoCollapseCoordinator(
            scheduler: scheduler,
            deferralPollInterval: 0.5,
            unavailableRetryBackoff: 2.0,
            isAutoHideEnabled: { isAutoHide },
            delayProvider: { delay },
            isCollapsed: { isCollapsed },
            isBusy: { isBusy },
            isAccessibilityAuthorized: { isAX },
            requestCollapse: { completion in
                collapses += 1
                if nextResult == .collapsed {
                    isCollapsed = true
                }
                completion(nextResult)
            },
            notifyAccessibilityRequired: {
                notifies += 1
            }
        )

        return (
            coordinator,
            scheduler,
            { isAutoHide = $0 },
            { isCollapsed = $0 },
            { isBusy = $0 },
            { isAX = $0 },
            { nextResult = $0 },
            { collapses },
            { notifies }
        )
    }

    // MARK: - REQ-AUTOHIDE-1: Idle-Based Deferral

    func test_armIfNeeded_collapsesAfterDelayWhenNotBusy() {
        let sut = makeSUT(delay: 10.0)
        sut.coordinator.armIfNeeded()

        XCTAssertEqual(sut.coordinator.state, .countdown)
        XCTAssertEqual(sut.scheduler.activeTokens.count, 1)
        XCTAssertEqual(sut.scheduler.activeTokens.first?.delay, 10.0)

        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 1)
        XCTAssertEqual(sut.coordinator.state, .idle)
        XCTAssertTrue(sut.scheduler.activeTokens.isEmpty)
    }

    func test_busyDeferral_pollsShortCadenceAndStartsFullIdleCountdownOnIdle() {
        let sut = makeSUT(delay: 10.0, busy: true)
        sut.coordinator.armIfNeeded()

        // Initial 10s timer fires while busy -> enters .deferred with 0.5s poll (<= 1.0s NFR)
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 0)
        XCTAssertEqual(sut.coordinator.state, .deferred)
        XCTAssertEqual(sut.scheduler.activeTokens.last?.delay, 0.5)

        // Still busy on poll -> stays .deferred
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 0)
        XCTAssertEqual(sut.coordinator.state, .deferred)

        // Interaction ends -> starts full 10s idle countdown
        sut.setBusy(false)
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 0)
        XCTAssertEqual(sut.coordinator.state, .countdown)
        XCTAssertEqual(sut.scheduler.activeTokens.last?.delay, 10.0)

        // Idle countdown expires -> collapses
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 1)
        XCTAssertEqual(sut.coordinator.state, .idle)
    }

    func test_didBecomeIdleFromMenuOrPrefs_resetsCountdownImmediately() {
        let sut = makeSUT(delay: 10.0, busy: true)
        sut.coordinator.armIfNeeded()
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.coordinator.state, .deferred)

        sut.setBusy(false)
        sut.coordinator.didBecomeIdleFromMenuOrPrefs()
        XCTAssertEqual(sut.coordinator.state, .countdown)
        XCTAssertEqual(sut.scheduler.activeTokens.count, 1)
        XCTAssertEqual(sut.scheduler.activeTokens.last?.delay, 10.0)
    }

    // MARK: - REQ-AUTOHIDE-2: Timer Cancellation on Collapse & Disable

    func test_didCollapse_cancelsPendingTimer() {
        let sut = makeSUT(delay: 10.0)
        sut.coordinator.armIfNeeded()
        XCTAssertEqual(sut.scheduler.activeTokens.count, 1)

        sut.setCollapsed(true)
        sut.coordinator.didCollapse()

        XCTAssertEqual(sut.coordinator.state, .idle)
        XCTAssertTrue(sut.scheduler.activeTokens.isEmpty)
    }

    func test_disablingAutoHide_cancelsPendingTimer() {
        let sut = makeSUT(delay: 10.0)
        sut.coordinator.armIfNeeded()
        XCTAssertEqual(sut.scheduler.activeTokens.count, 1)

        sut.setAutoHide(false)
        sut.coordinator.preferencesChanged()

        XCTAssertEqual(sut.coordinator.state, .idle)
        XCTAssertTrue(sut.scheduler.activeTokens.isEmpty)
    }

    // MARK: - REQ-AUTOHIDE-3: Environment Change Re-Arming

    func test_didInvalidateLayoutToExpanded_reArmsWhenAutoHideEnabled() {
        let sut = makeSUT(autoHide: true, delay: 10.0, collapsed: false)
        sut.coordinator.didInvalidateLayoutToExpanded()

        XCTAssertEqual(sut.coordinator.state, .countdown)
        XCTAssertEqual(sut.scheduler.activeTokens.count, 1)
    }

    func test_didInvalidateLayoutToExpanded_doesNothingWhenAutoHideDisabled() {
        let sut = makeSUT(autoHide: false, delay: 10.0, collapsed: false)
        sut.coordinator.didInvalidateLayoutToExpanded()

        XCTAssertEqual(sut.coordinator.state, .idle)
        XCTAssertTrue(sut.scheduler.activeTokens.isEmpty)
    }

    // MARK: - REQ-AUTOHIDE-4 & NFR-AUTOHIDE-1: Unavailable Single Retry + AX Notification

    func test_unavailable_retriesOnceAndRecoversWithoutNotification() {
        let sut = makeSUT(delay: 10.0, accessibilityAuthorized: false)
        sut.setNextResult(.unavailable)
        sut.coordinator.armIfNeeded()

        // First collapse fails -> schedules single 2.0s retry (<= 3.0s NFR)
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 1)
        XCTAssertEqual(sut.coordinator.state, .waitingRetry)
        XCTAssertEqual(sut.scheduler.activeTokens.last?.delay, 2.0)
        XCTAssertEqual(sut.notifyCount(), 0)

        // Retry succeeds -> transitions to idle without AX notification
        sut.setNextResult(.collapsed)
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 2)
        XCTAssertEqual(sut.coordinator.state, .idle)
        XCTAssertEqual(sut.notifyCount(), 0)
        XCTAssertTrue(sut.scheduler.activeTokens.isEmpty)
    }

    func test_unavailableTwiceWithoutAccessibility_notifiesOnceAndStops() {
        let sut = makeSUT(delay: 10.0, accessibilityAuthorized: false)
        sut.setNextResult(.unavailable)
        sut.coordinator.armIfNeeded()

        // Attempt 1 fails -> .waitingRetry
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 1)
        XCTAssertEqual(sut.coordinator.state, .waitingRetry)

        // Attempt 2 (retry) fails -> notifies once and stops
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 2)
        XCTAssertEqual(sut.coordinator.state, .idle)
        XCTAssertEqual(sut.notifyCount(), 1)
        XCTAssertTrue(sut.scheduler.activeTokens.isEmpty)
    }

    func test_unavailableTwiceWithAccessibilityGranted_doesNotNotify() {
        let sut = makeSUT(delay: 10.0, accessibilityAuthorized: true)
        sut.setNextResult(.unavailable)
        sut.coordinator.armIfNeeded()

        sut.scheduler.fireLatest()
        sut.scheduler.fireLatest()

        XCTAssertEqual(sut.collapseCallCount(), 2)
        XCTAssertEqual(sut.coordinator.state, .idle)
        XCTAssertEqual(sut.notifyCount(), 0)
    }

    func test_unavailableRetry_defersIfUserBecomesBusyBeforeRetryFires() {
        let sut = makeSUT(delay: 10.0, accessibilityAuthorized: false)
        sut.setNextResult(.unavailable)
        sut.coordinator.armIfNeeded()

        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.coordinator.state, .waitingRetry)

        sut.setBusy(true)
        sut.scheduler.fireLatest()
        XCTAssertEqual(sut.collapseCallCount(), 1)
        XCTAssertEqual(sut.coordinator.state, .deferred)
    }
}
