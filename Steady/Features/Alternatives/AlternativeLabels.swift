import SteadyCore

extension AlternativeBarrier {
    var title: String {
        switch self {
        case .anotherOption: "Another option"
        case .lowEnergy: "Low energy"
        case .sore: "Sore"
        case .stressed: "Stressed"
        case .noTime: "No time"
        case .badWeather: "Bad weather"
        case .homeLate: "Home late"
        case .noKitchen: "No kitchen"
        case .socialPlans: "Social plans"
        case .lowBudget: "Low budget"
        case .lateHunger: "Late hunger"
        case .deliveryPreference: "Prefer delivery"
        case .sweetDrinkPreference: "Want a sweet drink"
        case .phoneUseInBed: "Phone use in bed"
        }
    }
}

extension OutcomePart {
    var title: String {
        switch self {
        case .sleepOpportunity: "Sleep opportunity"
        case .gentleMovement: "Gentle movement"
        case .strengthStimulus: "Strength stimulus"
        case .aerobicMovement: "Aerobic movement"
        case .stressRelief: "Space to unwind"
        case .dailyRoutine: "Daily routine"
        case .nourishment: "Nourishment"
        }
    }
}

extension PlanStatus {
    var title: String {
        switch self {
        case .proposed: "Your plan"
        case .scheduled: "Scheduled"
        case .completed: "Completed"
        case .deferred: "For later"
        case .intentionallyRested: "Rest on purpose"
        }
    }
}
