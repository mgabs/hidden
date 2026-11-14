//
//  AutoCollapseCoordinator.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import Foundation

enum AutoCollapseState: Equatable {
    case idle
    case countdown
    case deferred
    case waitingRetry
}

protocol AutoCollapseScheduling {
    func schedule(after delay: TimeInterval, handler: @escaping () -> Void) -> AnyObject
    func cancel(_ token: AnyObject)
}

final class TimerAutoCollapseScheduler: AutoCollapseScheduling {
    func schedule(after delay: TimeInterval, handler: @escaping () -> Void) -> AnyObject {
        return Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            handler()
        }
    }

    func cancel(_ token: AnyObject) {
        (token as? Timer)?.invalidate()
    }
}

/// Owns auto-collapse countdown, busy-state deferral, timer cancellation,
/// environment-invalidation re-arming, and single-retry + Accessibility notice.
final class AutoCollapseCoordinator {
    private(set) var state: AutoCollapseState = .idle

    private let scheduler: AutoCollapseScheduling
    private let deferralPollInterval: TimeInterval
    private let unavailableRetryBackoff: TimeInterval

    private let isAutoHideEnabled: () -> Bool
    private let delayProvider: () -> TimeInterval
    private let isCollapsed: () -> Bool
    private let isBusy: () -> Bool
    private let isAccessibilityAuthorized: () -> Bool
    private let requestCollapse: (_ completion: @escaping (CollapseResult) -> Void) -> Void
    private let notifyAccessibilityRequired: () -> Void

    private var activeToken: AnyObject?
    private var hasRetriedUnavailable = false
    private var hasNotifiedAccessibility = false

    init(
        scheduler: AutoCollapseScheduling = TimerAutoCollapseScheduler(),
        deferralPollInterval: TimeInterval = 0.5,
        unavailableRetryBackoff: TimeInterval = 2.0,
        isAutoHideEnabled: @escaping () -> Bool,
        delayProvider: @escaping () -> TimeInterval,
        isCollapsed: @escaping () -> Bool,
        isBusy: @escaping () -> Bool,
        isAccessibilityAuthorized: @escaping () -> Bool,
        requestCollapse: @escaping (_ completion: @escaping (CollapseResult) -> Void) -> Void,
        notifyAccessibilityRequired: @escaping () -> Void
    ) {
        self.scheduler = scheduler
        self.deferralPollInterval = deferralPollInterval
        self.unavailableRetryBackoff = unavailableRetryBackoff
        self.isAutoHideEnabled = isAutoHideEnabled
        self.delayProvider = delayProvider
        self.isCollapsed = isCollapsed
        self.isBusy = isBusy
        self.isAccessibilityAuthorized = isAccessibilityAuthorized
        self.requestCollapse = requestCollapse
        self.notifyAccessibilityRequired = notifyAccessibilityRequired
    }

    deinit {
        cancelTimer()
    }

    func armIfNeeded() {
        guard isAutoHideEnabled(), !isCollapsed() else {
            cancel()
            return
        }
        scheduleCountdown()
    }

    func cancel() {
        cancelTimer()
        state = .idle
    }

    func didCollapse() {
        hasRetriedUnavailable = false
        hasNotifiedAccessibility = false
        cancel()
    }

    func didExpand() {
        hasRetriedUnavailable = false
        armIfNeeded()
    }

    func didBecomeIdleFromMenuOrPrefs() {
        guard state == .deferred || state == .countdown else { return }
        guard isAutoHideEnabled(), !isCollapsed(), !isBusy() else { return }
        scheduleCountdown()
    }

    func didInvalidateLayoutToExpanded() {
        hasRetriedUnavailable = false
        armIfNeeded()
    }

    func preferencesChanged() {
        guard isAutoHideEnabled() else {
            hasRetriedUnavailable = false
            cancel()
            return
        }
        armIfNeeded()
    }

    func handleUnavailable() {
        guard isAutoHideEnabled(), !isCollapsed() else {
            cancel()
            return
        }

        if !hasRetriedUnavailable {
            hasRetriedUnavailable = true
            scheduleRetry()
        } else {
            cancel()
            if !isAccessibilityAuthorized(), !hasNotifiedAccessibility {
                hasNotifiedAccessibility = true
                notifyAccessibilityRequired()
            }
        }
    }

    // MARK: - Private

    private func scheduleCountdown() {
        cancelTimer()
        state = .countdown
        let delay = max(0, delayProvider())
        activeToken = scheduler.schedule(after: delay) { [weak self] in
            self?.countdownFired()
        }
    }

    private func countdownFired() {
        activeToken = nil
        guard isAutoHideEnabled(), !isCollapsed() else {
            state = .idle
            return
        }
        if isBusy() {
            scheduleDeferralPoll()
        } else {
            performCollapse()
        }
    }

    private func scheduleDeferralPoll() {
        cancelTimer()
        state = .deferred
        activeToken = scheduler.schedule(after: deferralPollInterval) { [weak self] in
            self?.deferralPollFired()
        }
    }

    private func deferralPollFired() {
        activeToken = nil
        guard isAutoHideEnabled(), !isCollapsed() else {
            state = .idle
            return
        }
        if isBusy() {
            scheduleDeferralPoll()
        } else {
            scheduleCountdown()
        }
    }

    private func scheduleRetry() {
        cancelTimer()
        state = .waitingRetry
        activeToken = scheduler.schedule(after: unavailableRetryBackoff) { [weak self] in
            self?.retryFired()
        }
    }

    private func retryFired() {
        activeToken = nil
        guard isAutoHideEnabled(), !isCollapsed() else {
            state = .idle
            return
        }
        if isBusy() {
            scheduleDeferralPoll()
        } else {
            performCollapse()
        }
    }

    private func performCollapse() {
        state = .idle
        requestCollapse { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .collapsed:
                self.didCollapse()
            case .unavailable:
                self.handleUnavailable()
            }
        }
    }

    private func cancelTimer() {
        if let token = activeToken {
            scheduler.cancel(token)
            activeToken = nil
        }
    }
}
