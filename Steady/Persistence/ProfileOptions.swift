import Foundation
import SteadyCore

extension WellnessFocus {
    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .movement: "Movement"
        case .strength: "Strength"
        case .energy: "Everyday energy"
        case .stress: "A lighter routine"
        case .general: "General wellbeing"
        }
    }
}

extension DayPeriod {
    var title: String { rawValue.capitalized }
}

extension CheckIn {
    var title: String {
        switch self {
        case .lowEnergy: "Low energy"
        case .shortOnTime: "Short on time"
        case .stressed: "A lot on my mind"
        case .sore: "Sore"
        case .nothing: "Nothing in particular"
        case .skipped: "Skip"
        }
    }
}

extension Symptom {
    var title: String {
        switch self {
        case .pain: "Pain"
        case .fainting: "Fainting"
        case .chestSymptoms: "Chest symptoms"
        case .unusualBreathlessness: "Unusual breathlessness"
        case .feelingUnwell: "Feeling unwell"
        }
    }
}

extension RecoveryStatus {
    var title: String {
        switch self {
        case .learning: "Learning your usual range"
        case .recovered: "No reason to go easier"
        case .normal: "Keep the plan flexible"
        case .goEasier: "Go easier today"
        }
    }
}



