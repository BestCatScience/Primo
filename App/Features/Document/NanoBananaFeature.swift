import ComposableArchitecture
import Foundation
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain
import PrimoNanoBananaInfrastructure

@Reducer
struct NanoBananaFeature {
    @Dependency(\.nanoBananaSettingsClient) var nanoBananaSettingsClient
    @Dependency(\.nanoBananaCommerceClient) var nanoBananaCommerceClient
    @Dependency(\.nanoBananaCommandBuilder) var nanoBananaCommandBuilder

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            coreReduce(into: &state, action: action)
        }
    }
}
