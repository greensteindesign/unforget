import Foundation

/// The heart of the app: computes the next triggers from events + stages and fires
/// them via ONE precise timer. No polling — recomputation only on changes,
/// wake, time jumps, or after an alarm.
@MainActor
final class AlarmScheduler {

    var onFire: ((Trigger) -> Void)?

    /// All candidates (calendar + custom reminders).
    var occurrences: [ScheduledOccurrence] = [] {
        didSet { recompute() }
    }

    /// Escalation stages in minutes-before-start, descending. Last = fullscreen.
    var stages: [Int] = [1] {
        didSet { recompute() }
    }

    /// Minutes after event start for the follow-up; nil turns it off.
    var followUpMinutes: Int? = 1 {
        didSet { recompute() }
    }

    var pausedUntil: Date? {
        didSet { recompute() }
    }

    /// Returns the end of the quiet period if quiet hours are active right now (nil otherwise).
    var quietUntil: ((Date) -> Date?)?

    /// How long after event start an "already running" alert still fires.
    private let missedGrace: TimeInterval = 15 * 60

    private var firedKeys = Set<String>()
    private var snoozes: [String: (until: Date, count: Int)] = [:]
    private var timer: DispatchSourceTimer?

    // Acknowledged events survive an app restart (id -> startDate).
    private var acknowledged: [String: Date] = [:] {
        didSet { persistAcknowledged() }
    }

    init() {
        if let stored = UserDefaults.standard.dictionary(forKey: "acknowledged") as? [String: Double] {
            let cutoff = Date().addingTimeInterval(-2 * 24 * 3600)
            acknowledged = stored
                .mapValues { Date(timeIntervalSince1970: $0) }
                .filter { $0.value > cutoff }
        }
    }

    // MARK: - Actions from the overlay

    func acknowledge(_ occurrenceID: String) {
        if let occ = occurrences.first(where: { $0.id == occurrenceID }) {
            acknowledged[occurrenceID] = occ.startDate
        } else {
            acknowledged[occurrenceID] = Date()
        }
        snoozes[occurrenceID] = nil
        recompute()
    }

    /// Escalating snooze intervals: 2 → 5 → 10 minutes.
    @discardableResult
    func snooze(_ occurrenceID: String) -> Int {
        let count = snoozes[occurrenceID]?.count ?? 0
        let minutes = [2, 5, 10][min(count, 2)]
        snoozes[occurrenceID] = (Date().addingTimeInterval(TimeInterval(minutes * 60)), count + 1)
        recompute()
        return minutes
    }

    /// Requeue an alarm without snooze escalation (e.g. presentation guard).
    func requeue(_ occurrenceID: String, minutes: Int) {
        let count = snoozes[occurrenceID]?.count ?? 0
        snoozes[occurrenceID] = (Date().addingTimeInterval(TimeInterval(minutes * 60)), count)
        recompute()
    }

    func isAcknowledged(_ occurrenceID: String) -> Bool {
        acknowledged[occurrenceID] != nil
    }

    /// Next unacknowledged event (for the menu bar).
    var nextUpcoming: ScheduledOccurrence? {
        upcoming(limit: 1).first
    }

    /// The next unacknowledged events, in chronological order.
    func upcoming(limit: Int) -> [ScheduledOccurrence] {
        let now = Date()
        return occurrences
            .filter { $0.startDate > now.addingTimeInterval(-60) && acknowledged[$0.id] == nil }
            .sorted { $0.startDate < $1.startDate }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Core

    func recompute() {
        timer?.cancel()
        timer = nil

        let now = Date()

        // Paused: fire nothing, but recompute when the pause ends.
        if let paused = pausedUntil, paused > now {
            scheduleTimer(at: paused)
            return
        }

        // Quiet hours/profile: calendar alarms rest until the quiet period ends.
        // Custom reminders are exempt — whoever explicitly sets "laundry in
        // 20 min" at 22:10 wants to be woken at 22:30; otherwise quiet hours
        // would swallow exactly what was asked for.
        let quietEnd: Date? = {
            guard let q = quietUntil?(now), q > now else { return nil }
            return q
        }()

        var due: [Trigger] = []
        var future: [Trigger] = []

        for occ in occurrences where acknowledged[occ.id] == nil {
            if quietEnd != nil, !occ.isCustom { continue }

            // An active snooze replaces all stages.
            if let snooze = snoozes[occ.id] {
                let trigger = Trigger(occurrence: occ, stage: 0, kind: .snoozeReturn, fireDate: snooze.until)
                if snooze.until <= now {
                    snoozes[occ.id] = nil
                    due.append(trigger)
                } else {
                    future.append(trigger)
                }
                continue
            }

            // Hard stop: event ends in 5 min and the next one is already waiting (back-to-back).
            // The hyperfocus exit from the running meeting — subtle, as a banner.
            if !occ.isCustom, occ.endDate > now {
                let hardStopDate = occ.endDate.addingTimeInterval(-300)
                let endKey = "\(occ.id)#end"
                if occ.startDate < hardStopDate, !firedKeys.contains(endKey),
                   let follower = occurrences.first(where: {
                       $0.id != occ.id && acknowledged[$0.id] == nil
                           && $0.startDate >= occ.startDate.addingTimeInterval(60)
                           && $0.startDate <= occ.endDate.addingTimeInterval(600)
                   }) {
                    let trigger = Trigger(
                        occurrence: occ, stage: -1, kind: .hardStop,
                        fireDate: max(hardStopDate, now), followerTitle: follower.title
                    )
                    if hardStopDate > now {
                        future.append(trigger)
                    } else if now < occ.endDate {
                        firedKeys.insert(endKey)
                        due.append(trigger)
                    } else {
                        firedKeys.insert(endKey)
                    }
                }
            }

            let occStages = occ.stagesOverride ?? stages
            guard let finalStage = occStages.last else { continue }

            for stage in occStages {
                let key = "\(occ.id)#\(stage)"
                guard !firedKeys.contains(key) else { continue }
                let fireDate = occ.startDate.addingTimeInterval(TimeInterval(-stage * 60))
                let isFinal = (stage == finalStage)

                if fireDate > now {
                    future.append(Trigger(
                        occurrence: occ, stage: stage,
                        kind: isFinal ? .final : .preWarn,
                        fireDate: fireDate
                    ))
                } else if isFinal {
                    // Missed (sleep/restart)? Catch up within the grace period.
                    let deadline = min(occ.endDate, occ.startDate.addingTimeInterval(missedGrace))
                    if now < deadline {
                        // Custom reminders fire exactly at their start time — a few
                        // milliseconds of timer latency don't count as "already running".
                        let lateTolerance: TimeInterval = occ.isCustom ? 120 : 0
                        let kind: Trigger.Kind = now >= occ.startDate.addingTimeInterval(lateTolerance) ? .missed : .final
                        due.append(Trigger(occurrence: occ, stage: stage, kind: kind, fireDate: now))
                    } else {
                        firedKeys.insert(key) // too old — ignore silently, no shaming
                    }
                } else {
                    firedKeys.insert(key) // a missed pre-warning is irrelevant
                }
            }

            // Follow-up: the event is running and nobody has acknowledged it.
            // Separate marker so the caught-up main alarm doesn't collide.
            if let follow = followUpMinutes, !occ.isCustom {
                let key = "\(occ.id)#follow"
                let fireDate = occ.startDate.addingTimeInterval(TimeInterval(follow * 60))
                let deadline = min(occ.endDate, occ.startDate.addingTimeInterval(missedGrace))
                if !firedKeys.contains(key), fireDate < deadline {
                    let trigger = Trigger(
                        occurrence: occ, stage: 0, kind: .missed,
                        fireDate: max(fireDate, now), isFollowUp: true
                    )
                    if fireDate > now {
                        future.append(trigger)
                    } else if now < deadline {
                        due.append(trigger)
                    } else {
                        firedKeys.insert(key) // too late — no piling on
                    }
                }
            }
        }

        for trigger in due.sorted(by: { $0.fireDate < $1.fireDate }) {
            markFired(trigger)
            onFire?(trigger)
        }

        var nextDate = future.min(by: { $0.fireDate < $1.fireDate })?.fireDate
        if let quietEnd {
            // Recompute after the quiet period so calendar alarms
            // (grace period!) are caught up right away.
            nextDate = min(nextDate ?? quietEnd, quietEnd)
        }
        if let nextDate {
            scheduleTimer(at: nextDate)
        }
    }

    private func markFired(_ trigger: Trigger) {
        if trigger.isFollowUp {
            firedKeys.insert("\(trigger.occurrence.id)#follow")
            return
        }
        switch trigger.kind {
        case .snoozeReturn:
            return
        case .hardStop:
            firedKeys.insert("\(trigger.occurrence.id)#end")
        default:
            firedKeys.insert("\(trigger.occurrence.id)#\(trigger.stage)")
        }
    }

    private func scheduleTimer(at date: Date) {
        let t = DispatchSource.makeTimerSource(queue: .main)
        let delay = max(0.1, date.timeIntervalSinceNow)
        t.schedule(deadline: .now() + delay, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in
            self?.recompute()
        }
        t.resume()
        timer = t
    }

    private func persistAcknowledged() {
        let dict = acknowledged.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(dict, forKey: "acknowledged")
    }
}
