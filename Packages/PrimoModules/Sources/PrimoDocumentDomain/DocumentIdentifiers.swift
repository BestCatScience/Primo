import Foundation

public struct DocumentLayerIndex: Hashable, Codable, Sendable, Identifiable, Comparable {
    public let rawValue: Int

    public init(validating rawValue: Int) throws {
        guard rawValue >= 0 else {
            throw DocumentWorkspaceError.invalidLayerIndex(rawValue)
        }
        self.rawValue = rawValue
    }

    public init(unchecked rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func unchecked(_ rawValue: Int) -> Self {
        Self(unchecked: rawValue)
    }

    public var id: Int { rawValue }

    public static func < (lhs: DocumentLayerIndex, rhs: DocumentLayerIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        do {
            try self.init(validating: rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid layer index: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct DocumentFolderID: Hashable, Codable, Sendable, Identifiable, Comparable {
    public let rawValue: Int

    public init(validating rawValue: Int) throws {
        guard rawValue >= 0 else {
            throw DocumentWorkspaceError.invalidFolderID(rawValue)
        }
        self.rawValue = rawValue
    }

    public init(unchecked rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func unchecked(_ rawValue: Int) -> Self {
        Self(unchecked: rawValue)
    }

    public var id: Int { rawValue }

    public static func < (lhs: DocumentFolderID, rhs: DocumentFolderID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        do {
            try self.init(validating: rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid folder ID: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
