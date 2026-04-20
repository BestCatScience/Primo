import ComposableArchitecture
import CryptoKit
import Foundation
import SwiftUI

struct BrushPresetLibraryClient: Sendable {
    var loadSavedPresets: @Sendable () -> [BrushPreset]
    var savePreset: @Sendable (BrushPreset, Bool) throws -> [BrushPreset]
    var uniqueName: @Sendable (String, [String]) -> String
    var deletePreset: @Sendable (String) throws -> [BrushPreset]
    var renamePreset: @Sendable (String, String) throws -> [BrushPreset]

    static func live(
        fileClient: FileClient,
        uuidClient: UUIDClient,
        brushTipLibraryClient: BrushTipLibraryClient
    ) -> BrushPresetLibraryClient {
        let storage = BrushPresetLibraryStorage(
            fileClient: fileClient,
            uuidClient: uuidClient,
            brushTipLibraryClient: brushTipLibraryClient
        )
        return BrushPresetLibraryClient(
            loadSavedPresets: { storage.loadSavedPresets() },
            savePreset: { try storage.savePreset($0, replacingExisting: $1) },
            uniqueName: { storage.uniqueName(basedOn: $0, existingNames: $1) },
            deletePreset: { try storage.deletePreset(named: $0) },
            renamePreset: { try storage.renamePreset(named: $0, to: $1) }
        )
    }
}

private enum BrushPresetLibraryClientKey: DependencyKey {
    static var liveValue: BrushPresetLibraryClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.uuidClient) var uuidClient
        @Dependency(\.brushTipLibraryClient) var brushTipLibraryClient
        return .live(
            fileClient: fileClient,
            uuidClient: uuidClient,
            brushTipLibraryClient: brushTipLibraryClient
        )
    }
}

extension DependencyValues {
    var brushPresetLibraryClient: BrushPresetLibraryClient {
        get { self[BrushPresetLibraryClientKey.self] }
        set { self[BrushPresetLibraryClientKey.self] = newValue }
    }
}

private struct BrushPresetLibraryStorage {
    let fileClient: FileClient
    let uuidClient: UUIDClient
    let brushTipLibraryClient: BrushTipLibraryClient

    func loadSavedPresets() -> [BrushPreset] {
        do {
            let payload = try loadPayload()
            let directory = try libraryDirectory()
            return try payload.presets.map {
                try $0.makePreset(
                    baseDirectory: directory,
                    brushTipLibraryClient: brushTipLibraryClient
                )
            }
        } catch {
            return []
        }
    }

    func savePreset(
        _ preset: BrushPreset,
        replacingExisting: Bool
    ) throws -> [BrushPreset] {
        let directory = try libraryDirectory()
        var payload = try loadPayload()
        let tipFileName = try persistTipIfNeeded(for: preset, in: directory)
        let stored = StoredBrushPreset(preset: preset, tipFileName: tipFileName)

        if let existingIndex = payload.presets.firstIndex(where: { $0.name == stored.name }) {
            if replacingExisting {
                payload.presets[existingIndex] = stored
            } else {
                payload.presets.insert(stored, at: 0)
            }
        } else {
            payload.presets.insert(stored, at: 0)
        }

        let data = try JSONEncoder().encode(payload)
        try fileClient.writeData(data, indexURL(in: directory), .atomic)
        return try payload.presets.map {
            try $0.makePreset(
                baseDirectory: directory,
                brushTipLibraryClient: brushTipLibraryClient
            )
        }
    }

    func uniqueName(
        basedOn baseName: String,
        existingNames: [String]
    ) -> String {
        let trimmed = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = trimmed.isEmpty ? "Imported Brush" : trimmed
        guard existingNames.contains(seed) else {
            return seed
        }
        for index in 2...999 {
            let candidate = "\(seed) \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }
        return "\(seed) \(uuidClient.generate().uuidString.prefix(4))"
    }

    func deletePreset(named name: String) throws -> [BrushPreset] {
        let directory = try libraryDirectory()
        var payload = try loadPayload()
        guard let index = payload.presets.firstIndex(where: { $0.name == name }) else {
            return try payload.presets.map {
                try $0.makePreset(
                    baseDirectory: directory,
                    brushTipLibraryClient: brushTipLibraryClient
                )
            }
        }

        let removed = payload.presets.remove(at: index)
        if let tipFileName = removed.tipFileName {
            let tipURL = directory.appendingPathComponent(tipFileName, isDirectory: false)
            do {
                // Best-effort cleanup for an orphaned custom tip asset after preset deletion.
                try fileClient.removeItem(tipURL)
            } catch {
            }
        }

        let data = try JSONEncoder().encode(payload)
        try fileClient.writeData(data, indexURL(in: directory), .atomic)
        return try payload.presets.map {
            try $0.makePreset(
                baseDirectory: directory,
                brushTipLibraryClient: brushTipLibraryClient
            )
        }
    }

    func renamePreset(named oldName: String, to newName: String) throws -> [BrushPreset] {
        let directory = try libraryDirectory()
        var payload = try loadPayload()
        guard let index = payload.presets.firstIndex(where: { $0.name == oldName }) else {
            return try payload.presets.map {
                try $0.makePreset(
                    baseDirectory: directory,
                    brushTipLibraryClient: brushTipLibraryClient
                )
            }
        }

        let existingNames = payload.presets.enumerated().compactMap { offset, preset in
            offset == index ? nil : preset.name
        }
        let resolvedName = uniqueName(basedOn: newName, existingNames: existingNames)
        payload.presets[index].name = resolvedName

        let data = try JSONEncoder().encode(payload)
        try fileClient.writeData(data, indexURL(in: directory), .atomic)
        return try payload.presets.map {
            try $0.makePreset(
                baseDirectory: directory,
                brushTipLibraryClient: brushTipLibraryClient
            )
        }
    }

    private func persistTipIfNeeded(
        for preset: BrushPreset,
        in directory: URL
    ) throws -> String? {
        guard let tip = preset.customTip else { return nil }
        let hash = SHA256.hash(data: tip.alphaData).compactMap { String(format: "%02x", $0) }.joined()
        let fileName = "\(sanitizeFileName(preset.name))-\(hash.prefix(12)).\(BrushTipFile.fileExtension)"
        let targetURL = directory.appendingPathComponent(fileName, isDirectory: false)
        if !fileClient.fileExists(targetURL.path) {
            let brushTip = BrushTipFile(name: preset.name, width: tip.width, height: tip.height, alphaData: tip.alphaData)
            try fileClient.writeData(brushTip.encodedData(), targetURL, .atomic)
        }
        return fileName
    }

    private func loadPayload() throws -> StoredBrushLibrary {
        let directory = try libraryDirectory()
        let url = indexURL(in: directory)
        guard fileClient.fileExists(url.path) else {
            return StoredBrushLibrary()
        }
        let data = try fileClient.readData(url)
        return try JSONDecoder().decode(StoredBrushLibrary.self, from: data)
    }

    private func libraryDirectory() throws -> URL {
        let base = fileClient.urls(.applicationSupportDirectory, .userDomainMask)[0]
        let directory = base
            .appendingPathComponent("primo", isDirectory: true)
            .appendingPathComponent("BrushLibrary", isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func indexURL(in directory: URL) -> URL {
        directory.appendingPathComponent("saved-brushes.json", isDirectory: false)
    }

    private func sanitizeFileName(_ name: String) -> String {
        let sanitized = name.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(sanitized).replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-")).lowercased()
    }
}

private struct StoredBrushLibrary: Codable {
    var presets: [StoredBrushPreset] = []
}

private struct StoredBrushPreset: Codable {
    var name: String
    let tipKindRawValue: String
    let radius: Double
    let sizeSpeedSensitivity: Double
    let taperIn: Double
    let taperOut: Double
    let opacity: Double
    let hardness: Double
    let roundness: Double
    let roundnessPressureSensitivity: Double
    let roundnessTiltSensitivity: Double
    let angle: Double
    let anglePressureSensitivity: Double
    let angleTiltSensitivity: Double
    let angleModeRawValue: String
    let spacing: Double
    let spacingJitter: Double
    let scatterEnabled: Bool
    let scatterModeRawValue: String
    let scatterLateral: Double
    let scatterLinear: Double
    let count: Int
    let countJitter: Double
    let countSizeJitter: Double
    let countOpacityJitter: Double
    let angleJitter: Double
    let roundnessJitter: Double
    let textureModeRawValue: String
    let textureStrength: Double
    let flow: Double
    let flowPressureSensitivity: Double
    let flowJitter: Double
    let velocityInfluence: Double
    let wetness: Double
    let wetnessPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let colorMixStrength: Double
    let paintLoad: Double
    let loadPressureSensitivity: Double
    let dualBrushEnabled: Bool
    let dualTipKindRawValue: String
    let dualScale: Double
    let dualSpacing: Double
    let dualScatter: Double
    let dualAngle: Double
    let dualBlendModeRawValue: String
    let grainScale: Double
    let grainContrast: Double
    let paperScale: Double
    let paperStrength: Double
    let paperThreshold: Double
    let flipX: Bool
    let flipY: Bool
    let pressureSensitivity: Double
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let tipFileName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case tipKindRawValue
        case radius
        case sizeSpeedSensitivity
        case taperIn
        case taperOut
        case opacity
        case hardness
        case roundness
        case roundnessPressureSensitivity
        case roundnessTiltSensitivity
        case angle
        case anglePressureSensitivity
        case angleTiltSensitivity
        case angleModeRawValue
        case spacing
        case spacingJitter
        case scatterEnabled
        case scatterModeRawValue
        case scatterLateral
        case scatterLinear
        case count
        case countJitter
        case countSizeJitter
        case countOpacityJitter
        case angleJitter
        case roundnessJitter
        case textureModeRawValue
        case textureStrength
        case flow
        case flowPressureSensitivity
        case flowJitter
        case velocityInfluence
        case wetness
        case wetnessPressureSensitivity
        case opacityPressureSensitivity
        case colorMixStrength
        case paintLoad
        case loadPressureSensitivity
        case dualBrushEnabled
        case dualTipKindRawValue
        case dualScale
        case dualSpacing
        case dualScatter
        case dualAngle
        case dualBlendModeRawValue
        case grainScale
        case grainContrast
        case paperScale
        case paperStrength
        case paperThreshold
        case flipX
        case flipY
        case pressureSensitivity
        case red
        case green
        case blue
        case tipFileName
    }

    init(preset: BrushPreset, tipFileName: String?) {
        name = preset.name
        tipKindRawValue = preset.tipKind.rawValue
        radius = preset.radius
        sizeSpeedSensitivity = preset.sizeSpeedSensitivity
        taperIn = preset.taperIn
        taperOut = preset.taperOut
        opacity = preset.opacity
        hardness = preset.hardness
        roundness = preset.roundness
        roundnessPressureSensitivity = preset.roundnessPressureSensitivity
        roundnessTiltSensitivity = preset.roundnessTiltSensitivity
        angle = preset.angle
        anglePressureSensitivity = preset.anglePressureSensitivity
        angleTiltSensitivity = preset.angleTiltSensitivity
        angleModeRawValue = preset.angleMode.rawValue
        spacing = preset.spacing
        spacingJitter = preset.spacingJitter
        scatterEnabled = preset.scatterEnabled
        scatterModeRawValue = preset.scatterMode.rawValue
        scatterLateral = preset.scatterLateral
        scatterLinear = preset.scatterLinear
        count = preset.count
        countJitter = preset.countJitter
        countSizeJitter = preset.countSizeJitter
        countOpacityJitter = preset.countOpacityJitter
        angleJitter = preset.angleJitter
        roundnessJitter = preset.roundnessJitter
        textureModeRawValue = preset.textureMode.rawValue
        textureStrength = preset.textureStrength
        flow = preset.flow
        flowPressureSensitivity = preset.flowPressureSensitivity
        flowJitter = preset.flowJitter
        velocityInfluence = preset.velocityInfluence
        wetness = preset.wetness
        wetnessPressureSensitivity = preset.wetnessPressureSensitivity
        opacityPressureSensitivity = preset.opacityPressureSensitivity
        colorMixStrength = preset.colorMixStrength
        paintLoad = preset.paintLoad
        loadPressureSensitivity = preset.loadPressureSensitivity
        dualBrushEnabled = preset.dualBrushEnabled
        dualTipKindRawValue = preset.dualTipKind.rawValue
        dualScale = preset.dualScale
        dualSpacing = preset.dualSpacing
        dualScatter = preset.dualScatter
        dualAngle = preset.dualAngle
        dualBlendModeRawValue = preset.dualBlendMode.rawValue
        grainScale = preset.grainScale
        grainContrast = preset.grainContrast
        paperScale = preset.paperScale
        paperStrength = preset.paperStrength
        paperThreshold = preset.paperThreshold
        flipX = preset.flipX
        flipY = preset.flipY
        pressureSensitivity = preset.pressureSensitivity
        red = preset.red
        green = preset.green
        blue = preset.blue
        self.tipFileName = tipFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        tipKindRawValue = try container.decode(String.self, forKey: .tipKindRawValue)
        radius = try container.decode(Double.self, forKey: .radius)
        sizeSpeedSensitivity = try container.decodeIfPresent(Double.self, forKey: .sizeSpeedSensitivity) ?? 0.0
        taperIn = try container.decodeIfPresent(Double.self, forKey: .taperIn) ?? 0.0
        taperOut = try container.decodeIfPresent(Double.self, forKey: .taperOut) ?? 0.0
        opacity = try container.decode(Double.self, forKey: .opacity)
        hardness = try container.decode(Double.self, forKey: .hardness)
        roundness = try container.decode(Double.self, forKey: .roundness)
        roundnessPressureSensitivity = try container.decodeIfPresent(Double.self, forKey: .roundnessPressureSensitivity) ?? 0.0
        roundnessTiltSensitivity = try container.decodeIfPresent(Double.self, forKey: .roundnessTiltSensitivity) ?? 0.0
        angle = try container.decode(Double.self, forKey: .angle)
        anglePressureSensitivity = try container.decodeIfPresent(Double.self, forKey: .anglePressureSensitivity) ?? 0.0
        angleTiltSensitivity = try container.decodeIfPresent(Double.self, forKey: .angleTiltSensitivity) ?? 0.0
        angleModeRawValue = try container.decode(String.self, forKey: .angleModeRawValue)
        spacing = try container.decode(Double.self, forKey: .spacing)
        spacingJitter = try container.decode(Double.self, forKey: .spacingJitter)
        scatterEnabled = try container.decodeIfPresent(Bool.self, forKey: .scatterEnabled) ?? false
        scatterModeRawValue = try container.decodeIfPresent(String.self, forKey: .scatterModeRawValue) ?? BrushScatterMode.directional.rawValue
        scatterLateral = try container.decode(Double.self, forKey: .scatterLateral)
        scatterLinear = try container.decode(Double.self, forKey: .scatterLinear)
        count = try container.decode(Int.self, forKey: .count)
        countJitter = try container.decode(Double.self, forKey: .countJitter)
        countSizeJitter = try container.decodeIfPresent(Double.self, forKey: .countSizeJitter) ?? 0.0
        countOpacityJitter = try container.decodeIfPresent(Double.self, forKey: .countOpacityJitter) ?? 0.0
        angleJitter = try container.decode(Double.self, forKey: .angleJitter)
        roundnessJitter = try container.decode(Double.self, forKey: .roundnessJitter)
        textureModeRawValue = try container.decode(String.self, forKey: .textureModeRawValue)
        textureStrength = try container.decode(Double.self, forKey: .textureStrength)
        flow = try container.decode(Double.self, forKey: .flow)
        flowPressureSensitivity = try container.decodeIfPresent(Double.self, forKey: .flowPressureSensitivity) ?? 0.0
        flowJitter = try container.decodeIfPresent(Double.self, forKey: .flowJitter) ?? 0.0
        velocityInfluence = try container.decodeIfPresent(Double.self, forKey: .velocityInfluence) ?? 0.0
        wetness = try container.decodeIfPresent(Double.self, forKey: .wetness) ?? 0.0
        wetnessPressureSensitivity = try container.decodeIfPresent(Double.self, forKey: .wetnessPressureSensitivity) ?? 0.0
        opacityPressureSensitivity = try container.decodeIfPresent(Double.self, forKey: .opacityPressureSensitivity) ?? 0.0
        colorMixStrength = try container.decodeIfPresent(Double.self, forKey: .colorMixStrength) ?? 0.0
        paintLoad = try container.decodeIfPresent(Double.self, forKey: .paintLoad) ?? 1.0
        loadPressureSensitivity = try container.decodeIfPresent(Double.self, forKey: .loadPressureSensitivity) ?? 0.0
        dualBrushEnabled = try container.decodeIfPresent(Bool.self, forKey: .dualBrushEnabled) ?? false
        dualTipKindRawValue = try container.decodeIfPresent(String.self, forKey: .dualTipKindRawValue) ?? BrushTipKind.ink.rawValue
        dualScale = try container.decodeIfPresent(Double.self, forKey: .dualScale) ?? 0.72
        dualSpacing = try container.decodeIfPresent(Double.self, forKey: .dualSpacing) ?? 0.26
        dualScatter = try container.decodeIfPresent(Double.self, forKey: .dualScatter) ?? 0.18
        dualAngle = try container.decodeIfPresent(Double.self, forKey: .dualAngle) ?? 0.0
        dualBlendModeRawValue = try container.decodeIfPresent(String.self, forKey: .dualBlendModeRawValue) ?? BrushDualBlendMode.multiply.rawValue
        grainScale = try container.decodeIfPresent(Double.self, forKey: .grainScale) ?? 1.35
        grainContrast = try container.decodeIfPresent(Double.self, forKey: .grainContrast) ?? 1.7
        paperScale = try container.decodeIfPresent(Double.self, forKey: .paperScale) ?? 0.12
        paperStrength = try container.decodeIfPresent(Double.self, forKey: .paperStrength) ?? 0.32
        paperThreshold = try container.decodeIfPresent(Double.self, forKey: .paperThreshold) ?? 0.42
        flipX = try container.decode(Bool.self, forKey: .flipX)
        flipY = try container.decode(Bool.self, forKey: .flipY)
        pressureSensitivity = try container.decode(Double.self, forKey: .pressureSensitivity)
        red = try container.decode(UInt8.self, forKey: .red)
        green = try container.decode(UInt8.self, forKey: .green)
        blue = try container.decode(UInt8.self, forKey: .blue)
        tipFileName = try container.decodeIfPresent(String.self, forKey: .tipFileName)
    }

    func makePreset(
        baseDirectory: URL,
        brushTipLibraryClient: BrushTipLibraryClient = .live(fileClient: .live)
    ) throws -> BrushPreset {
        let tipKind = BrushTipKind(rawValue: tipKindRawValue) ?? .ink
        let angleMode = BrushAngleMode(rawValue: angleModeRawValue) ?? .fixed
        let scatterMode = BrushScatterMode(rawValue: scatterModeRawValue) ?? .directional
        let textureMode = BrushTextureMode(rawValue: textureModeRawValue) ?? .off
        let dualTipKind = BrushTipKind(rawValue: dualTipKindRawValue) ?? .ink
        let dualBlendMode = BrushDualBlendMode(rawValue: dualBlendModeRawValue) ?? .multiply
        let customTip: BrushTipRaster?
        if let tipFileName {
            let url = baseDirectory.appendingPathComponent(tipFileName, isDirectory: false)
            customTip = try brushTipLibraryClient.loadRaster(url)
        } else {
            customTip = nil
        }

        return BrushPreset(
            name: name,
            tipKind: tipKind,
            color: Color(red: Double(red) / 255.0, green: Double(green) / 255.0, blue: Double(blue) / 255.0),
            radius: radius,
            sizeSpeedSensitivity: sizeSpeedSensitivity,
            taperIn: taperIn,
            taperOut: taperOut,
            opacity: opacity,
            hardness: hardness,
            roundness: roundness,
            roundnessPressureSensitivity: roundnessPressureSensitivity,
            roundnessTiltSensitivity: roundnessTiltSensitivity,
            angle: angle,
            anglePressureSensitivity: anglePressureSensitivity,
            angleTiltSensitivity: angleTiltSensitivity,
            angleMode: angleMode,
            spacing: spacing,
            spacingJitter: spacingJitter,
            scatterEnabled: scatterEnabled,
            scatterMode: scatterMode,
            scatterLateral: scatterLateral,
            scatterLinear: scatterLinear,
            count: count,
            countJitter: countJitter,
            countSizeJitter: countSizeJitter,
            countOpacityJitter: countOpacityJitter,
            angleJitter: angleJitter,
            roundnessJitter: roundnessJitter,
            textureMode: textureMode,
            textureStrength: textureStrength,
            flow: flow,
            flowPressureSensitivity: flowPressureSensitivity,
            flowJitter: flowJitter,
            velocityInfluence: velocityInfluence,
            wetness: wetness,
            wetnessPressureSensitivity: wetnessPressureSensitivity,
            opacityPressureSensitivity: opacityPressureSensitivity,
            colorMixStrength: colorMixStrength,
            paintLoad: paintLoad,
            loadPressureSensitivity: loadPressureSensitivity,
            dualBrushEnabled: dualBrushEnabled,
            dualTipKind: dualTipKind,
            dualScale: dualScale,
            dualSpacing: dualSpacing,
            dualScatter: dualScatter,
            dualAngle: dualAngle,
            dualBlendMode: dualBlendMode,
            grainScale: grainScale,
            grainContrast: grainContrast,
            paperScale: paperScale,
            paperStrength: paperStrength,
            paperThreshold: paperThreshold,
            flipX: flipX,
            flipY: flipY,
            customTip: customTip,
            pressureSensitivity: pressureSensitivity,
            red: red,
            green: green,
            blue: blue
        )
    }
}
