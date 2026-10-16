import SwiftData
import SwiftUI

struct AppLaunchView: View {
    @Query(sort: \ProfileRecord.completedAt) private var profiles: [ProfileRecord]

    var body: some View {
        if let profile = profiles.first {
            RootTabView(profile: profile)
        } else {
            OnboardingView()
        }
    }
}

