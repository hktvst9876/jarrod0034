@preconcurrency import CoreLocation
import Foundation
import SteadyCore

@MainActor
final class ApproximateFoodLocationProvider: FoodLocationProviding {
    private let clock: any SteadyCore.Clock

    init(clock: any SteadyCore.Clock) { self.clock = clock }

    func approximateLocation() async throws -> FoodCoordinate {
        // Constructing the manager is deferred until the user asks, not app launch.
        let operation = FoodLocationRequest(clock: clock)
        return try await withTaskCancellationHandler {
            try await operation.run()
        } onCancel: {
            Task { @MainActor in operation.cancel() }
        }
    }
}

@MainActor
private final class FoodLocationRequest: NSObject, CLLocationManagerDelegate {
    private let clock: any SteadyCore.Clock
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<FoodCoordinate, any Error>?
    private var timeout: Task<Void, Never>?
    private var requestedFix = false
    private var requestedAuthorization = false

    init(clock: any SteadyCore.Clock) { self.clock = clock }

    func run() async throws -> FoodCoordinate {
        try Task.checkCancellation()
        guard let explanation = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String,
              !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodServiceError.locationSetupRequired
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let manager = CLLocationManager()
            self.manager = manager
            manager.desiredAccuracy = kCLLocationAccuracyReduced
            manager.delegate = self
            authorizationChanged()
            guard self.continuation != nil else { return }
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.finish(.failure(FoodServiceError.locationUnavailable))
            }
        }
    }

    func cancel() { finish(.failure(FoodServiceError.cancelled)) }

    private func authorizationChanged() {
        guard continuation != nil, let manager else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            guard !requestedAuthorization else { return }
            requestedAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            guard !requestedFix else { return }
            requestedFix = true
            manager.requestLocation()
        case .denied, .restricted: finish(.failure(FoodServiceError.locationDenied))
        @unknown default: finish(.failure(FoodServiceError.locationUnavailable))
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.authorizationChanged() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Round before the actor hop. Exact device coordinates are never retained or returned.
        let fixes = locations.filter { $0.horizontalAccuracy >= 0 }.map {
            FoodLocationFix(
                latitude: ($0.coordinate.latitude * 100).rounded() / 100,
                longitude: ($0.coordinate.longitude * 100).rounded() / 100,
                timestamp: $0.timestamp
            )
        }
        Task { @MainActor [weak self] in self?.received(fixes) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor [weak self] in self?.finish(.failure(FoodServiceError.locationUnavailable)) }
    }

    private func received(_ fixes: [FoodLocationFix]) {
        guard let fix = fixes.last, fix.latitude.isFinite, fix.longitude.isFinite,
              (-90...90).contains(fix.latitude), (-180...180).contains(fix.longitude),
              abs(clock.now.timeIntervalSince(fix.timestamp)) <= 300 else {
            finish(.failure(FoodServiceError.locationUnavailable))
            return
        }
        finish(.success(FoodCoordinate(latitude: fix.latitude, longitude: fix.longitude)))
    }

    private func finish(_ result: Result<FoodCoordinate, FoodServiceError>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        manager?.stopUpdatingLocation()
        manager?.delegate = nil
        manager = nil
        switch result {
        case .success(let coordinate): continuation.resume(returning: coordinate)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }
}

private struct FoodLocationFix: Sendable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}
