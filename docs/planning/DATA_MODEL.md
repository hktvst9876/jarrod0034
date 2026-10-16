# Steady proposed data model

Status: **proposal appendix; names may change during implementation**

All domain types live in `SteadyCore` as Foundation-only `Codable`, `Sendable`, and `Equatable` value types. Persisted records are SwiftData `@Model` classes in the iOS app and map explicitly to domain values. Time-dependent functions receive a `Clock` and a Singapore-configured `Calendar`; they do not call `Date()` internally.

## 1. Profile and consent

```swift
struct Profile {
    var id: UUID
    var primaryFocus: Focus
    var otherFocuses: Set<Focus>
    var sleep: SleepPreferences
    var movement: MovementPreferences
    var food: FoodPreferences
    var hydration: HydrationPreferences
    var quietPeriods: [QuietPeriod]
    var lowDataMode: Bool
    var examMode: Bool
    var createdAt: Date
}

struct MovementPreferences {
    var likedActivities: [String]
    var gymAccess: GymAccess
    var sessionsPerWeek: Int
    var preferredTime: DayPeriod
    var movementsToAvoid: [String]   // entered by the user; never inferred
    var movementMode: MovementMode   // standing, seatedOK, wheelchair
}

struct FoodPreferences {
    var dietaryRules: Set<DietaryRule>
    var allergies: Set<Allergen>
    var otherAllergies: [String]
    var dislikes: [String]
    var usualAreas: [String]
    var kitchenAccess: KitchenAccess
    var maxPricePerMealSGD: Decimal?
}

struct ConsentRecord {
    var id: UUID
    var scope: EgressScope
    var grantedAt: Date
    var revokedAt: Date?
    var noticeVersion: Int
}
```

The app queries live system authorization independently. It does not treat a saved preference as proof that HealthKit, Calendar, Notifications, or Location permission is currently granted.

## 2. Daily context and safety

```swift
struct SleepNight {
    var wakeDay: Date
    var sleepStart: Date
    var wakeTime: Date
    var asleepMinutes: Int
    var inBedMinutes: Int?
    var sourceCount: Int
}

struct SleepContext {
    var lastNight: SleepNight?
    var coarseLabel: SleepLabel
    var shortfall7dMinutes: Int?
    var nightsTracked: Int
    var wakeConsistency: Consistency?
    var bedtimePlan: BedtimePlan?
}

struct ActivityContext {
    var stepsToday: Int?
    var exerciseMinutesToday: Int?
    var daysSinceExercise: Int?
    var lastWorkoutEnd: Date?
}

enum SafetyFlag {
    case userReported(Symptom)
    case healthAlert(kind: String, at: Date)
}

enum Symptom {
    case pain
    case fainting
    case chestSymptoms
    case unusualBreathlessness
    case feelingUnwell
}

struct DailyContext {
    var date: Date
    var sleep: SleepContext
    var activity: ActivityContext
    var availability: Availability
    var checkIn: CheckIn?
    var safetyFlags: [SafetyFlag]
    var plannedToday: PlanItem?
    var dataGaps: Set<DataGap>
}
```

`SafetyGate` runs before priority selection or advisor use. A relevant safety flag returns the neutral medical-safety state and suppresses performance suggestions.

## 3. Calendar availability

```swift
struct BusyInterval { var start: Date; var end: Date }

struct FreeSlot {
    var start: Date
    var end: Date
    var travelAllowanceMinutes: Int
    var confidence: SlotConfidence
}

struct Availability {
    var source: AvailabilitySource   // calendar, manualMinutes, manualBlocks, unknown
    var freeSlots: [FreeSlot]
    var freeMinutesToday: Int?
    var firstCommitmentTomorrow: Date?
}

struct CalendarChangeProposal {
    var id: UUID
    var planItemID: UUID
    var title: String
    var start: Date
    var end: Date
    var explanation: String
}
```

A proposal is inert data. Only an app-layer confirmation handler may write it to the dedicated Steady calendar.

## 4. Priority, outcomes, and plans

```swift
struct DailyPriority {
    var kind: PriorityKind
    var ruleID: String
    var title: String
    var explanation: Explanation
    var planA: PlanItem
    var chosenByUser: Bool
}

struct Outcome {
    var id: String
    var summary: String
    var parts: Set<OutcomePart>
}

struct PlanItem {
    var id: UUID
    var day: Date
    var type: PlanType
    var title: String
    var outcome: Outcome
    var minutes: Int
    var slot: FreeSlot?
    var status: PlanStatus
    var calendarEventID: String?
    var origin: PlanOrigin
}
```

`Explanation` stores a short sentence plus typed factors so every number displayed by the UI can open a one-line “why.”

## 5. Alternatives and learning

```swift
struct AlternativeOption {
    var id: String
    var title: String
    var minutes: Int
    var effort: Effort
    var benefit: String
    var tradeoff: String
    var preserves: Set<OutcomePart>
    var doesNotPreserve: Set<OutcomePart>
    var steps: [String]
    var tags: Set<OptionTag>
}

struct AlternativeSet {
    var planItemID: UUID
    var outcome: Outcome
    var barrier: Barrier?
    var options: [AlternativeOption]
    var canDefer: Bool
    var canRest: Bool
    var source: AdviceSource
}

struct ChoiceLog {
    var id: UUID
    var shownAt: Date
    var decidedAt: Date?
    var planItemID: UUID
    var barrier: Barrier?
    var shownOptionIDs: [String]
    var action: ChoiceAction?
    var completed: Bool?
}
```

Required invariants:

- two or three primary options;
- distinct effort levels when more than one option is shown;
- `preserves ∪ doesNotPreserve == outcome.parts`;
- the two outcome-part sets do not overlap; and
- defer and intentional rest remain explicit user actions.

## 6. Foundations and notifications

```swift
struct FoundationVariant {
    var id: String
    var kind: FoundationKind
    var text: String
    var minutes: Int
    var tags: Set<OptionTag>
}

struct FoundationSetting {
    var kind: FoundationKind
    var enabled: Bool
    var selectedVariantID: String
    var preferredTime: TimeOfDay?
}

struct NudgeCandidate {
    var id: String
    var trigger: NudgeTrigger
    var type: NudgeType
    var fireAt: Date
    var title: String
    var body: String
    var actions: [NudgeAction]
    var canWait: Bool
    var rank: Int
}

struct NudgeTypeState {
    var type: NudgeType
    var recentDismissals: [Date]
    var mode: NudgeMode   // normal, reduced, paused
}
```

The pure planner returns `notification`, `todayCard`, or a typed drop reason such as quiet period, class, workout, sleep window, daily budget, or paused type.

## 7. Advisor, privacy, and validation

```swift
protocol OutboundPayload: Encodable, Sendable {}

struct AdvisorContextPacket: OutboundPayload {
    var requestKind: AdvisorRequestKind
    var localTimeDescription: String
    var sleepLabel: SleepLabel?
    var freeWindows: [TimeWindow]?
    var approximateArea: String?
    var dietaryRules: Set<DietaryRule>?
    var allergies: Set<Allergen>?
    var mealType: MealType?
    var statedGoal: String?
    var plan: PlanSummary?
    var barrier: Barrier?
    var relevantPreferences: [String]
}

struct AdvisorOption {
    var candidateID: String
    var title: String
    var reason: String
    var tradeoff: String
    var citations: [SourceCitation]
}

struct AdvisorResult {
    var options: [AdvisorOption]
    var engine: AdvisorEngine
    var validation: ValidationReport
    var pendingActions: [PendingAction]
}

struct AdvisorSession {
    var id: UUID
    var startedAt: Date
    var packetSummary: String
    var toolCalls: [ToolCallSummary]
    var result: AdvisorResult
    var dataLeftDevice: Bool
}

struct EgressRecord {
    var at: Date
    var scope: EgressScope
    var destinationHost: String
    var byteCount: Int
    var humanReadableSummary: String
}
```

The saved session contains a packet summary rather than raw HealthKit or EventKit values. `AdvisorStore` is independently clearable.

## 8. Food evidence

```swift
struct SourceCitation {
    var kind: SourceKind
    var name: String
    var url: URL?
    var checkedAt: Date
}

struct PlaceSummary {
    var sourceID: String
    var name: String
    var category: String?
    var distanceMeters: Int?
    var mapsURL: URL
    var officialWebsite: URL?
    var openStatus: OpenStatus
    var source: SourceCitation
}

struct NutritionReference {
    var referenceID: String
    var name: String
    var servingDescription: String
    var kcal: Double
    var proteinGrams: Double
    var url: URL
    var retrievedAt: Date
}

struct NutritionRange {
    var kcal: ClosedRange<Int>?
    var proteinGrams: ClosedRange<Int>?
    var basis: NutritionBasis
    var uncertaintyReasons: Set<UncertaintyReason>
}

enum AllergenEligibility {
    case eligible
    case requiresConfirmation(reason: String)
    case excluded(Set<Allergen>)
}

struct FoodCandidate {
    var id: String
    var dishName: String
    var place: PlaceSummary?
    var nutrition: NutritionRange?
    var price: SourcedPrice?
    var allergenEligibility: AllergenEligibility
    var confidence: ConfidenceLabel
    var sources: [SourceCitation]
    var whyItFits: String
}

struct FoodAdvice {
    var bestFit: FoodCandidate?
    var easiestAcceptable: FoodCandidate?
    var familiarOrFlexible: FoodCandidate?
    var excludedForAllergiesCount: Int
    var generatedBy: AdvisorEngine
    var checkedAt: Date
}

struct FoodCorrection {
    var id: UUID
    var dishID: String
    var field: CorrectedField
    var oldValue: String
    var newValue: String
    var createdAt: Date
    var remember: Bool
}
```

Only a correction with `remember == true` changes future ranking.

## 9. Weekly learning and local evaluation

```swift
struct WeeklyReview {
    var weekStart: Date
    var sections: [ReviewSection]
    var proposedChanges: [DefaultChange]
    var experiment: Experiment?
    var helpfulnessRating: Int?
}

struct DefaultChange {
    var id: UUID
    var target: DefaultTarget
    var oldValue: String
    var proposedValue: String
    var evidence: String
    var status: ProposalStatus
}

struct Experiment {
    var id: UUID
    var title: String
    var startsAt: Date
    var endsAt: Date
    var measure: String
    var result: String?
}

enum MetricEvent {
    case suggestionShown(id: String, kind: SuggestionKind)
    case suggestionAccepted(id: String)
    case alternativeCompleted(optionID: String)
    case timeToChoose(seconds: Int, screen: String)
    case sleepOpportunity(night: Date, plannedMinutes: Int, actualInBedMinutes: Int?)
    case notificationDismissed(NudgeType)
    case foodCorrection(dishID: String, field: String)
    case helpfulness(rating: Int, context: String)
}
```

Metrics are local, exportable, and never treated as analytics sent to another party.

## 10. Watch synchronization

```swift
struct WatchSnapshot {
    var generatedAt: Date
    var priorityTitle: String
    var plan: PlanSummary
    var quickAlternatives: [AlternativeOption]
    var foundation: FoundationVariant?
    var savedMeals: [SavedDishSummary]
    var lowDataMode: Bool
}

struct WatchAction {
    var id: UUID
    var createdAt: Date
    var kind: WatchActionKind
    var payload: [String: String]
}
```

The phone applies each `WatchAction.id` once, making queued delivery safe to retry.

## 11. SwiftData records

The first-release `WellnessStore` mirrors only records that need persistence:

- `ProfileRecord`
- `PlanItemRecord`
- `ChoiceLogRecord`
- `FoundationSettingRecord`
- `NudgeLogRecord`
- `SavedDishRecord`
- `FoodCorrectionRecord`
- `WeeklyReviewRecord`
- `ExperimentRecord`
- `MetricRecord`
- `AppliedWatchActionRecord`

The separately clearable `AdvisorStore` contains:

- `AdvisorSessionRecord`
- `EgressRecord`
- `LiveSourceCacheRecord` with `checkedAt` and `expiresAt`

Authorization state, raw health samples, complete calendar events, and transient nearby-search results are queried at runtime rather than persisted as personal history.
