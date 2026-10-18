import Foundation
@preconcurrency import MapKit
import SteadyCore

@MainActor
final class MapKitFoodDiscoveryProvider: FoodDiscoveryProviding {
    func discover(area: String, near: FoodCoordinate?, checkedAt: Date) async throws -> [FoodPlace] {
        let typedArea = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard near != nil || !typedArea.isEmpty else { throw FoodServiceError.areaRequired }
        let request = MKLocalSearch.Request()
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .bakery, .foodMarket])
        if let near, near.latitude.isFinite, near.longitude.isFinite,
           (-90...90).contains(near.latitude), (-180...180).contains(near.longitude) {
            request.naturalLanguageQuery = "food"
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: near.latitude, longitude: near.longitude),
                latitudinalMeters: 5_000, longitudinalMeters: 5_000
            )
        } else {
            guard !typedArea.isEmpty else { throw FoodServiceError.areaRequired }
            request.naturalLanguageQuery = "food in \(String(typedArea.prefix(120))), Singapore"
        }
        let operation = FoodPlaceSearch(request: request, checkedAt: checkedAt)
        return try await withTaskCancellationHandler {
            try await operation.run()
        } onCancel: {
            Task { @MainActor in operation.cancel() }
        }
    }
}

/// Owns a single search, timeout and continuation. No MapKit object escapes this adapter.
@MainActor
private final class FoodPlaceSearch {
    private let search: MKLocalSearch
    private let checkedAt: Date
    private var continuation: CheckedContinuation<[FoodPlace], any Error>?
    private var timeout: Task<Void, Never>?

    init(request: MKLocalSearch.Request, checkedAt: Date) {
        search = MKLocalSearch(request: request)
        self.checkedAt = checkedAt
    }

    func run() async throws -> [FoodPlace] {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let checkedAt = self.checkedAt
            search.start { [weak self] response, error in
                guard let owner = self else { return }
                // Convert within the callback; never send framework objects across actors.
                let places = response.map { Self.mapPlaces($0.mapItems, checkedAt: checkedAt) }
                let failed = error != nil || places == nil
                Task { @MainActor in
                    if failed { owner.finish(.failure(FoodServiceError.unavailable)) }
                    else { owner.finish(.success(places ?? [])) }
                }
            }
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                self?.finish(.failure(FoodServiceError.unavailable))
            }
        }
    }

    func cancel() { finish(.failure(FoodServiceError.cancelled)) }

    private func finish(_ result: Result<[FoodPlace], FoodServiceError>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        search.cancel()
        switch result {
        case .success(let places): continuation.resume(returning: places)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }

    private nonisolated static func mapPlaces(_ items: [MKMapItem], checkedAt: Date) -> [FoodPlace] {
        var seen = Set<String>()
        return items.compactMap { item -> FoodPlace? in
            guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            let placemark = item.placemark
            let area = [placemark.thoroughfare, placemark.subLocality, placemark.locality, placemark.postalCode]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            // The postal/address identity is local matching context, not proof of menu ownership.
            let point = placemark.coordinate
            let identity = item.identifier.map { "mapkit|" + $0.rawValue }
                ?? "directory|\(name.lowercased())|\(area.lowercased())|\(point.latitude)|\(point.longitude)"
            guard seen.insert(identity).inserted else { return nil }
            let website = item.url.flatMap { url -> URL? in
                guard url.scheme?.lowercased() == "https", url.host != nil,
                      url.user == nil, url.password == nil else { return nil }
                return url
            }
            return FoodPlace(id: identity, name: name, area: area, websiteURL: website, checkedAt: checkedAt)
        }.prefix(12).map { $0 }
    }
}
