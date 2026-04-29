import ComposableArchitecture
import Foundation
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain
import PrimoNanoBananaInfrastructure

@Reducer
struct AIImageFeature {
    @Dependency(\.aiImageSettingsClient) var aiImageSettingsClient
    @Dependency(\.aiImageCommerceClient) var aiImageCommerceClient
    @Dependency(\.aiImageCommandBuilder) var aiImageCommandBuilder

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            coreReduce(into: &state, action: action)
        }
    }
}
