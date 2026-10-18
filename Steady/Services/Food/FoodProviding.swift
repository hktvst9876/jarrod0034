import Foundation
import SteadyCore

/// Only this explicit search boundary sends an area or approximate point to Apple.
/// Dietary rules, allergies, Health data and free-form context never enter it.
@MainActor
protocol FoodDiscoveryProviding {
    func discover(area: String, near: FoodCoordinate?, checkedAt: Date) async throws -> [FoodPlace]
}

@MainActor
protocol FoodLocationProviding {
    func approximateLocation() async throws -> FoodCoordinate
}

enum FoodServiceError: LocalizedError, Sendable {
    case areaRequired
    case unavailable
    case locationDenied
    case locationUnavailable
    case locationSetupRequired
    case cancelled

    var errorDescription: String? {
        switch self {
        case .areaRequired: "Enter an area, or explicitly choose approximate location."
        case .unavailable: "Place search is unavailable. You can still review saved dishes or add an observation manually."
        case .locationDenied: "Location is off. Enter an area or review saved dishes instead."
        case .locationUnavailable: "An approximate location is unavailable. Enter an area instead."
        case .locationSetupRequired: "Location has not been configured in this build. Enter an area instead."
        case .cancelled: "The request was cancelled. Nothing was saved."
        }
    }
}

/// Sample mode cannot make a network request or trigger a real permission prompt.
@MainActor
struct SampleFoodDiscoveryProvider: FoodDiscoveryProviding {
    func discover(area: String, near: FoodCoordinate?, checkedAt: Date) async throws -> [FoodPlace] { [] }
}

@MainActor
struct SampleFoodLocationProvider: FoodLocationProviding {
    func approximateLocation() async throws -> FoodCoordinate { throw FoodServiceError.locationUnavailable }
}
