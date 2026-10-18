import Foundation
import Testing
@testable import SteadyCore

struct WeeklyMetricsTests {
    @Test func noHistoricalTelemetryMeansUnknownDenominatorsNotZeroRates() {
        let summary = WeeklyMetricAggregator.summarize([], window: weeklyWindow())
        #expect(summary.suggestionsShown == nil)
        #expect(summary.suggestionsAccepted == nil)
        #expect(summary.alternativesCompleted == nil)
        #expect(summary.correctionRate == nil)
        #expect(summary.helpfulnessFraction == nil)
        #expect(summary.meanDecisionSeconds == nil)
    }

    @Test func explicitShownAcceptedAndCompletedAreCorrelatedAndDeduplicated() {
        let shown = weeklyMetric("show", .suggestionShown, at: weeklyNow.addingTimeInterval(-120))
        let accepted = weeklyMetric("accept", .suggestionAccepted, at: weeklyNow.addingTimeInterval(-60), seconds: 60)
        let done = weeklyMetric("done", .alternativeCompleted)
        let summary = WeeklyMetricAggregator.summarize([shown, shown, accepted, done, done], window: weeklyWindow())
        #expect(summary.suggestionsShown == 1)
        #expect(summary.suggestionsAccepted == 1)
        #expect(summary.alternativesCompleted == 1)
        #expect(summary.meanDecisionSeconds == 60)
        #expect(summary.decisionTimeSamples == 1)
    }

    @Test func orphanAcceptAndCompletionDoNotInventShownTelemetry() {
        let summary = WeeklyMetricAggregator.summarize([
            weeklyMetric("accept", .suggestionAccepted, seconds: 10), weeklyMetric("done", .alternativeCompleted)
        ], window: weeklyWindow())
        #expect(summary.suggestionsShown == nil)
        #expect(summary.suggestionsAccepted == nil)
        #expect(summary.alternativesCompleted == nil)
        #expect(summary.meanDecisionSeconds == nil)
    }

    @Test func recordedExposureWithNoResponseIsKnownZeroAccepted() {
        let summary = WeeklyMetricAggregator.summarize([weeklyMetric("show", .suggestionShown)], window: weeklyWindow())
        #expect(summary.suggestionsShown == 1)
        #expect(summary.suggestionsAccepted == 0)
        #expect(summary.alternativesCompleted == nil)
    }

    @Test func earlierResponseDoesNotMatchLaterExposure() {
        let summary = WeeklyMetricAggregator.summarize([
            weeklyMetric("show", .suggestionShown),
            weeklyMetric("accept", .suggestionAccepted, at: weeklyNow.addingTimeInterval(-5), seconds: 0)
        ], window: weeklyWindow())
        #expect(summary.suggestionsAccepted == 0)
        #expect(summary.meanDecisionSeconds == nil)
    }

    @Test func invalidOrImplausibleDecisionTimesStayUnknown() {
        for seconds in [Double.nan, Double.infinity, -1, 86_401, 61] {
            let summary = WeeklyMetricAggregator.summarize([
                weeklyMetric("show", .suggestionShown, at: weeklyNow.addingTimeInterval(-30)),
                weeklyMetric("accept", .suggestionAccepted, seconds: seconds)
            ], window: weeklyWindow())
            #expect(summary.meanDecisionSeconds == nil)
            #expect(summary.suggestionsAccepted == 1)
        }
    }

    @Test func correctionRateUsesOnlyLinkedFoodExposuresNotSavedMealCount() {
        let summary = WeeklyMetricAggregator.summarize([
            weeklyMetric("shown-a", .foodShown, subject: "a", at: weeklyNow.addingTimeInterval(-60)),
            weeklyMetric("shown-b", .foodShown, subject: "b", at: weeklyNow.addingTimeInterval(-60)),
            weeklyMetric("correction-a", .foodCorrection, subject: "a"),
            weeklyMetric("correction-again", .foodCorrection, subject: "a"),
            weeklyMetric("orphan-correction", .foodCorrection, subject: "not-shown")
        ], window: weeklyWindow())
        #expect(summary.foodExposures == 2)
        #expect(summary.correctedFoodExposures == 1)
        #expect(summary.correctionRate == 0.5)
    }

    @Test func helpfulnessIsExplicitAndMixedIsNotPromotedToHelpful() {
        let summary = WeeklyMetricAggregator.summarize([
            weeklyMetric("h1", .helpfulness, subject: "review-a", helpfulness: .helpful),
            weeklyMetric("h2", .helpfulness, subject: "review-b", helpfulness: .mixed),
            weeklyMetric("h3", .helpfulness, subject: "review-c", helpfulness: .notHelpful)
        ], window: weeklyWindow())
        #expect(summary.helpfulResponses == 1)
        #expect(summary.mixedResponses == 1)
        #expect(summary.notHelpfulResponses == 1)
        #expect(summary.helpfulnessFraction == 1.0 / 3.0)
    }

    @Test func conflictingDuplicateMetricIDAndFutureEventsAreDiscarded() {
        let summary = WeeklyMetricAggregator.summarize([
            weeklyMetric("conflict", .suggestionShown, subject: "a"),
            weeklyMetric("conflict", .suggestionShown, subject: "b"),
            weeklyMetric("future", .suggestionShown, at: weeklyNow.addingTimeInterval(10)),
            weeklyMetric("", .suggestionShown)
        ], window: weeklyWindow())
        #expect(summary.suggestionsShown == nil)
    }
}
