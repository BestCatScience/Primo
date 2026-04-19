import ComposableArchitecture
import Foundation
import PrimoNanoBananaDomain
import PrimoNanoBananaInfrastructure

@Reducer
struct NanoBananaFeature {
    @Dependency(\.nanoBananaSettingsClient) var nanoBananaSettingsClient
    @Dependency(\.nanoBananaCommerceClient) var nanoBananaCommerceClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            reduce(into: &state, action: action)
        }
    }
}
