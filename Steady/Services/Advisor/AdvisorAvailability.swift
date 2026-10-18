import Foundation
import SteadyCore
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AdvisorAvailability: Equatable, Sendable {
    case ready, sample, olderSystem, unsupported, disabled, preparing, unavailable

    var message: String {
        switch self {
        case .ready: "On-device ordering is available. The usual options always remain available."
        case .sample: "Sample mode always uses deterministic template ordering."
        case .olderSystem: "This system uses deterministic templates. Optional ordering needs a supported newer system."
        case .unsupported: "This device does not support the on-device model. Templates work as usual."
        case .disabled: "Apple Intelligence is off. Templates work as usual."
        case .preparing: "The on-device model is not ready, possibly while downloading. Templates work as usual."
        case .unavailable: "The on-device model is unavailable. Templates work as usual."
        }
    }
}

@MainActor
enum AdvisorProviderFactory {
    static func availability(sample: Bool) -> AdvisorAvailability {
        guard !sample else { return .sample }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .ready
            case .unavailable(.deviceNotEligible): return .unsupported
            case .unavailable(.appleIntelligenceNotEnabled): return .disabled
            case .unavailable(.modelNotReady): return .preparing
            case .unavailable: return .unavailable
            @unknown default: return .unavailable
            }
        }
        #endif
        return .olderSystem
    }

    static func optionalProvider(sample: Bool) -> (any AdvisorProviding)? {
        guard availability(sample: sample) == .ready else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return OnDeviceAdvisor() }
        #endif
        return nil
    }
}
