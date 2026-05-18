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
    func proxyEndpointRequiresHTTPSAndAllowedHost() {
        #expect(ProxyEndpoint("https://proxy.bestcatscience.com/aiimage/edit")?.rawValue == "https://proxy.bestcatscience.com/aiimage/edit")
        #expect(ProxyEndpoint("http://127.0.0.1:8787/aiimage/edit") == nil)
        #expect(ProxyEndpoint("https://proxy.example.com/aiimage/edit") == nil)
        #expect(ProxyEndpoint("https://bestcatscience.com.evil.example/aiimage/edit") == nil)
    }

    @Test
    func entitlementTokenAcceptsStoreKitJWSLength() {
        let header = String(repeating: "a", count: 1200)
        let payload = String(repeating: "b", count: 3600)
        let signature = String(repeating: "c", count: 1200)
        let jws = "\(header).\(payload).\(signature)"

        #expect(AIImageEntitlementToken(jws)?.rawValue == jws)
        #expect(AIImageEntitlementToken(String(repeating: "x", count: AIImageEntitlementToken.maxCharacterCount + 1)) == nil)
    }

    @Test
    func openAIDirectEditModelsAreConfigDrivenAndDocsAligned() {
        #expect(AIImageModel.defaultOpenAIDirectEditModel == .gptImage15)
        #expect(AIImageModel.openAIDirectEditModels == [
            .gptImage15,
            .gptImage1,
            .gptImage1Mini,
        ])
        #expect(!AIImageModel.openAIDirectEditModels.contains(.gptImage2))
        #expect(!AIImageModel.openAIDirectEditModels.contains(.chatGPTImageLatest))
        #expect(AIImageModel.gptImage15.supportsOpenAIDirectImageEdit)
        #expect(AIImageModel.gptImage2.provider == .openAI)
    }
}
