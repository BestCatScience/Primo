import PrimoNanoBananaDomain
import Testing

struct NanoBananaDomainTests {
    @Test
    func requestRetainsMaskAndOutputConfiguration() {
        let request = NanoBananaGenerationRequest(
            prompt: "Refine the lighting",
            config: NanoBananaRequestConfig(
                accessMode: .appManaged,
                credential: "token",
                endpoint: "https://proxy.example.com/edit"
            ),
            model: .flashImage31Preview,
            inputLayerIndex: 2,
            editScope: .selectedArea,
            outputMode: .newLayer,
            maskSettings: NanoBananaMaskSettings(
                expansion: 12,
                isInverted: true
            )
        )

        #expect(request.prompt == "Refine the lighting")
        #expect(request.config.accessMode == .appManaged)
        #expect(request.model == .flashImage31Preview)
        #expect(request.inputLayerIndex == 2)
        #expect(request.editScope == .selectedArea)
        #expect(request.outputMode == .newLayer)
        #expect(request.maskSettings.expansion == 12)
        #expect(request.maskSettings.isInverted)
    }
}
