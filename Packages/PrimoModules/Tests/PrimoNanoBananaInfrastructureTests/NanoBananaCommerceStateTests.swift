import Foundation
import PrimoNanoBananaDomain
import PrimoNanoBananaInfrastructure
import Testing

struct NanoBananaCommerceStateTests {
    @Test
    func snapshotReflectsEntitlementAndErrors() {
        let state = NanoBananaCommerceState(
            primaryProduct: .init(
                id: "com.bestcatscience.primo.nanobanana.monthly",
                displayName: "Monthly",
                displayPrice: "$4.99"
            ),
            isLoading: true,
            isSubscriptionActive: true,
            latestEntitlementJWS: "signed-jws",
            purchaseErrorMessage: "temporarily unavailable",
            proxyEndpoint: "https://proxy.example.com/edit"
        )

        let snapshot = state.snapshot()

        #expect(snapshot.primaryProduct?.id == "com.bestcatscience.primo.nanobanana.monthly")
        #expect(snapshot.isLoading)
        #expect(snapshot.isSubscriptionActive)
        #expect(snapshot.latestEntitlementJWS == "signed-jws")
        #expect(snapshot.purchaseErrorMessage == "temporarily unavailable")
        #expect(snapshot.proxyEndpoint == "https://proxy.example.com/edit")
    }
}
