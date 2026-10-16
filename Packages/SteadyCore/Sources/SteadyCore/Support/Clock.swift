import Foundation

/// Supplies the current time to SteadyCore without coupling decision logic to the system clock.
public protocol Clock: Sendable {
    var now: Date { get }
}

/// The live clock used at the app boundary. Decision functions still receive time explicitly.
public struct SystemClock: Clock, Sendable {
    public init() {}

    public var now: Date {
        Date.now
    }
}

/// A clock for previews, sample providers, and deterministic tests.
public struct FixedClock: Clock, Codable, Equatable, Sendable {
    public let now: Date

    public init(now: Date) {
        self.now = now
    }
}
