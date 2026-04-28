import Foundation
import Metal

enum PrimoMetalShaderLibrary {
    static func makeDefaultLibrary(device: MTLDevice) -> MTLLibrary? {
        if let library = try? device.makeDefaultLibrary(bundle: .module) {
            return library
        }
        guard
            let shaderURL = Bundle.module.url(forResource: "PaintShaders", withExtension: "metal"),
            let source = try? String(contentsOf: shaderURL, encoding: .utf8)
        else {
            return nil
        }
        return try? device.makeLibrary(source: source, options: nil)
    }
}
