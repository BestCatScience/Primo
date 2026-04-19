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
        Reduce { [self] state, action in
            self.coreReduce(into: &state, action: action)
        }
    }
}
