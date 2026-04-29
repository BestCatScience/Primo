import PrimoAIImageDomain
import Testing

struct AIImageDomainTests {
    @Test
    func descriptorRetainsMaskAndOutputConfiguration() {
        let request = AIImageEditDescriptor(
            prompt: NonEmptyPrompt("Refine the lighting")!,
            accessMode: .appManaged,
            model: .flashImage31Preview,
            inputLayerIndex: 2,
            editScope: .selectedArea,
            outputMode: .newLayer,
            maskSettings: AIImageMaskSettings(
                expansion: 12,
                isInverted: true
            )
        )

        #expect(request.prompt.rawValue == "Refine the lighting")
        #expect(request.accessMode == .appManaged)
        #expect(request.model == .flashImage31Preview)
        #expect(request.inputLayerIndex == 2)
        #expect(request.editScope == .selectedArea)
        #expect(request.outputMode == .newLayer)
        #expect(request.maskSettings.expansion == 12)
        #expect(request.maskSettings.isInverted)
    }

    @Test
    func proxyEndpointRequiresHTTPS() {
        #expect(ProxyEndpoint("https://proxy.example.com/aiimage/edit")?.rawValue == "https://proxy.example.com/aiimage/edit")
        #expect(ProxyEndpoint("http://127.0.0.1:8787/aiimage/edit") == nil)
    }
}
