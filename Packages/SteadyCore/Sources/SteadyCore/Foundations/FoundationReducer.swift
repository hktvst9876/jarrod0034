import Foundation

public enum FoundationReducer {
    public static func startDay(
        at now: Date, settings: FoundationSettings,
        previous: FoundationDayState? = nil,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> FoundationDayState {
        guard now.timeIntervalSince1970.isFinite else {
            return FoundationDayState(day: now, settings: settings)
        }
        if let previous, previous.day.timeIntervalSince1970.isFinite,
           calendar.isDate(previous.day, inSameDayAs: now) {
            return reconcile(settings: settings, state: previous, now: now, calendar: calendar)
        }
        return FoundationDayState(
            day: calendar.startOfDay(for: now), settings: settings,
            items: FoundationKind.allCases.map { freshItem($0, settings: settings) }
        )
    }

    /// Daily progress survives refresh. New local days keep preferences, not yesterday's completion.
    public static func reconcile(
        settings: FoundationSettings, state: FoundationDayState,
        now: Date, calendar: Calendar = SteadyCalendar.singapore()
    ) -> FoundationDayState {
        guard now.timeIntervalSince1970.isFinite, state.day.timeIntervalSince1970.isFinite,
              calendar.isDate(state.day, inSameDayAs: now) else {
            return startDay(at: now, settings: settings, calendar: calendar)
        }
        let items = FoundationKind.allCases.map { kind -> FoundationItemState in
            guard !settings.disabledKinds.contains(kind) else { return freshItem(kind, settings: settings) }
            guard let item = state.items.first(where: { $0.kind == kind }), item.status != .disabled else {
                return freshItem(kind, settings: settings)
            }
            // Completed actions are historical; changing restrictions cannot rewrite them.
            if item.status == .done { return item }
            let options = FoundationCatalog.options(for: kind, settings: settings)
            guard options.contains(where: { $0.id == item.optionID }) else {
                return freshItem(kind, settings: settings)
            }
            if item.status == .snoozed {
                guard let until = item.snoozedUntil, until.timeIntervalSince1970.isFinite,
                      until > now, calendar.isDate(until, inSameDayAs: now) else {
                    return activeItem(item, options: options)
                }
            }
            return item
        }
        return FoundationDayState(
            day: calendar.startOfDay(for: now), settings: settings,
            items: items, appliedEventIDs: state.appliedEventIDs
        )
    }

    public static func apply(
        _ event: FoundationEvent, to state: FoundationDayState, now: Date,
        calendar: Calendar = SteadyCalendar.singapore(), safetyFlags: [SafetyFlag] = []
    ) throws -> FoundationDayState {
        guard !event.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoundationError.emptyEventID
        }
        guard [event.day, state.day, now].allSatisfy({ $0.timeIntervalSince1970.isFinite }),
              calendar.isDate(event.day, inSameDayAs: state.day),
              calendar.isDate(state.day, inSameDayAs: now) else { throw FoundationError.staleDay }
        if state.appliedEventIDs.contains(event.id) { return state }
        guard state.items.count == FoundationKind.allCases.count,
              Set(state.items.map(\.kind)).count == FoundationKind.allCases.count,
              let index = state.items.firstIndex(where: { $0.kind == event.kind }) else {
            throw FoundationError.invalidState
        }
        let item = state.items[index]
        var disabledKinds = state.settings.disabledKinds
        let replacement: FoundationItemState
        switch event.action {
        case .disable:
            disabledKinds.insert(event.kind)
            replacement = FoundationItemState(kind: event.kind, status: .disabled, optionID: item.optionID)
        case .enable:
            guard disabledKinds.contains(event.kind) || item.status == .disabled else {
                throw FoundationError.invalidTransition
            }
            disabledKinds.remove(event.kind)
            replacement = freshItem(event.kind, settings: copying(state.settings, disabledKinds: disabledKinds))
        default:
            guard !SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations else {
                throw FoundationError.safetyBlocked
            }
            guard item.status != .disabled, item.status != .done,
                  !disabledKinds.contains(event.kind) else { throw FoundationError.inactiveItem }
            let options = FoundationCatalog.options(for: event.kind, settings: state.settings)
            guard options.contains(where: { $0.id == item.optionID }) else { throw FoundationError.unknownOption }
            replacement = try changing(item, action: event.action, options: options, now: now, calendar: calendar)
        }
        var items = state.items
        items[index] = replacement
        return FoundationDayState(
            day: state.day, settings: copying(state.settings, disabledKinds: disabledKinds),
            items: items, appliedEventIDs: state.appliedEventIDs.union([event.id])
        )
    }

    private static func changing(
        _ item: FoundationItemState, action: FoundationAction, options: [FoundationOption],
        now: Date, calendar: Calendar
    ) throws -> FoundationItemState {
        switch action {
        case .done:
            return FoundationItemState(kind: item.kind, status: .done, optionID: item.optionID)
        case .replace(let id):
            guard options.contains(where: { $0.id == id }) else { throw FoundationError.unknownOption }
            guard id != item.optionID else { throw FoundationError.unchangedOption }
            return FoundationItemState(kind: item.kind, status: .replaced, optionID: id)
        case .snooze(let until):
            guard until.timeIntervalSince1970.isFinite, until > now,
                  until.timeIntervalSince(now) <= 12 * 60 * 60,
                  calendar.isDate(until, inSameDayAs: now) else { throw FoundationError.invalidSnooze }
            return FoundationItemState(kind: item.kind, status: .snoozed, optionID: item.optionID, snoozedUntil: until)
        case .resume:
            guard item.status == .snoozed else { throw FoundationError.invalidTransition }
            return activeItem(item, options: options)
        case .disable, .enable:
            throw FoundationError.invalidTransition
        }
    }

    private static func freshItem(_ kind: FoundationKind, settings: FoundationSettings) -> FoundationItemState {
        FoundationItemState(
            kind: kind, status: settings.disabledKinds.contains(kind) ? .disabled : .available,
            optionID: FoundationCatalog.options(for: kind, settings: settings).first?.id
        )
    }

    private static func activeItem(_ item: FoundationItemState, options: [FoundationOption]) -> FoundationItemState {
        FoundationItemState(
            kind: item.kind, status: item.optionID == options.first?.id ? .available : .replaced,
            optionID: item.optionID
        )
    }

    private static func copying(_ settings: FoundationSettings, disabledKinds: Set<FoundationKind>) -> FoundationSettings {
        FoundationSettings(
            disabledKinds: disabledKinds, movementMode: settings.movementMode,
            movementsToAvoid: settings.movementsToAvoid
        )
    }
}
