import SteadyCore
import SwiftUI

struct PriorityPickerSheet: View {
    let choose: (PriorityKind?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button("Let Steady choose") { choose(nil) }
                ForEach(selectablePriorities, id: \.rawValue) { priority in
                    Button(priority.title) { choose(priority) }
                }
            }
            .navigationTitle("Choose a priority")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var selectablePriorities: [PriorityKind] {
        [.protectBedtime, .recover, .keepItSmall, .strength, .getMoving, .lighterDay, .steadyDay]
    }
}

extension PriorityKind {
    var title: String {
        switch self {
        case .lookAfterYourself: "Look after yourself"
        case .protectBedtime: "Protect bedtime"
        case .recover: "Go easier"
        case .keepItSmall: "Keep it small"
        case .strength: "Make room for strength"
        case .getMoving: "Get moving"
        case .lighterDay: "Keep today lighter"
        case .followPlan: "Follow today's plan"
        case .steadyDay: "Have a steady day"
        }
    }
}
