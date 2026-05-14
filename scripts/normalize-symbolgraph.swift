#!/usr/bin/env swift

import Foundation

struct SymbolRecord: Comparable {
    let kind: String
    let preciseIdentifier: String
    let path: String
    let title: String
    let declaration: String

    static func < (lhs: SymbolRecord, rhs: SymbolRecord) -> Bool {
        lhs.line < rhs.line
    }

    var line: String {
        [
            kind,
            preciseIdentifier,
            path,
            title,
            declaration
        ].joined(separator: "\t")
    }
}

func stringValue(_ value: Any?) -> String? {
    value as? String
}

func dictionaryValue(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
}

func stringArray(_ value: Any?) -> [String]? {
    value as? [String]
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: normalize-symbolgraph.swift <symbolgraph-json>\n".utf8))
    exit(64)
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: url)
guard
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    let symbols = root["symbols"] as? [[String: Any]]
else {
    FileHandle.standardError.write(Data("invalid symbol graph: \(url.path)\n".utf8))
    exit(65)
}

let records = symbols.compactMap { symbol -> SymbolRecord? in
    guard stringValue(symbol["accessLevel"]) == "public" else { return nil }
    guard
        let kind = stringValue(dictionaryValue(symbol["kind"])?["identifier"]),
        let preciseIdentifier = stringValue(dictionaryValue(symbol["identifier"])?["precise"]),
        let pathComponents = stringArray(symbol["pathComponents"]),
        let title = stringValue(dictionaryValue(symbol["names"])?["title"])
    else {
        return nil
    }
    let declaration = (symbol["declarationFragments"] as? [[String: Any]])?
        .compactMap { stringValue($0["spelling"]) }
        .joined() ?? ""
    return SymbolRecord(
        kind: kind,
        preciseIdentifier: preciseIdentifier,
        path: pathComponents.joined(separator: "."),
        title: title,
        declaration: declaration
    )
}

let output = records.sorted().map(\.line).joined(separator: "\n") + "\n"
FileHandle.standardOutput.write(Data(output.utf8))
