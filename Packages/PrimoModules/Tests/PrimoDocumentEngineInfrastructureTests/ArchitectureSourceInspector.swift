import Foundation
import SwiftParser
import SwiftSyntax

struct ArchitectureSourceInspector {
    struct Declaration: Equatable {
        let name: String
        let kind: String
        let accessLevel: String
    }

    struct Import: Equatable {
        let moduleName: String
        let attributes: Set<String>
    }

    struct Property: Equatable {
        let name: String
        let accessLevel: String
        let type: String?
        let isStored: Bool
    }

    struct TypealiasDeclaration: Equatable {
        let name: String
        let accessLevel: String
        let assignedType: String
    }

    struct ExtensionDeclaration: Equatable {
        let extendedType: String
        let accessLevel: String
        let inheritedTypes: [String]
    }

    struct Callable: Equatable {
        struct Parameter: Equatable {
            let firstName: String?
            let secondName: String?
            let type: String
        }

        let kind: String
        let name: String
        let accessLevel: String
        let attributes: Set<String>
        let signature: String
        let parameters: [Parameter]
    }

    struct FunctionCall: Equatable {
        let expression: String
        let base: String?
        let name: String
    }

    struct MemberAccess: Equatable {
        let expression: String
        let base: String?
        let name: String
    }

    private let source: String
    private let tree: SourceFileSyntax

    init(source: String) {
        self.source = source
        self.tree = Parser.parse(source: source)
    }

    var importedModules: Set<String> {
        let visitor = ImportVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return Set(visitor.imports.map(\.moduleName))
    }

    var imports: [Import] {
        let visitor = ImportVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.imports
    }

    var topLevelDeclarations: [Declaration] {
        let visitor = TopLevelDeclarationVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.declarations
    }

    var properties: [Property] {
        let visitor = PropertyVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.properties
    }

    var typealiases: [TypealiasDeclaration] {
        let visitor = TypealiasVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.typealiases
    }

    var extensions: [ExtensionDeclaration] {
        let visitor = ExtensionVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.extensions
    }

    var initializerSignatures: [String] {
        let visitor = InitializerVisitor(source: source, viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.signatures
    }

    var functionSignatures: [String] {
        let visitor = FunctionVisitor(source: source, viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.callables.map(\.signature)
    }

    var callables: [Callable] {
        let visitor = FunctionVisitor(source: source, viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.callables
    }

    var dependencyAttributeKeys: Set<String> {
        let visitor = DependencyAttributeVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.keys
    }

    var functionCalls: [FunctionCall] {
        let visitor = FunctionCallVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.calls
    }

    var memberAccesses: [MemberAccess] {
        let visitor = MemberAccessVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.accesses
    }

    var referencedIdentifiers: Set<String> {
        let visitor = IdentifierReferenceVisitor(viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.identifiers
    }

    func declarationSource(named name: String) -> String? {
        let visitor = DeclarationSourceVisitor(source: source, name: name, viewMode: .sourceAccurate)
        visitor.walk(tree)
        return visitor.declaration
    }
}

private final class TopLevelDeclarationVisitor: SyntaxVisitor {
    var declarations: [ArchitectureSourceInspector.Declaration] = []
    private var nominalDepth = 0

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(name: node.name.text, kind: "struct", modifiers: node.modifiers)
        nominalDepth += 1
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        nominalDepth -= 1
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(name: node.name.text, kind: "enum", modifiers: node.modifiers)
        nominalDepth += 1
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        nominalDepth -= 1
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        record(name: node.name.text, kind: "protocol", modifiers: node.modifiers)
        nominalDepth += 1
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        nominalDepth -= 1
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(name: node.name.text, kind: "class", modifiers: node.modifiers)
        nominalDepth += 1
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        nominalDepth -= 1
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(name: node.name.text, kind: "actor", modifiers: node.modifiers)
        nominalDepth += 1
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        nominalDepth -= 1
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        record(name: node.name.text, kind: "typealias", modifiers: node.modifiers)
        return .skipChildren
    }

    private func record(name: String, kind: String, modifiers: DeclModifierListSyntax) {
        guard nominalDepth == 0 else { return }
        declarations.append(
            ArchitectureSourceInspector.Declaration(
                name: name,
                kind: kind,
                accessLevel: accessLevel(in: modifiers)
            )
        )
    }
}

private final class ImportVisitor: SyntaxVisitor {
    var imports: [ArchitectureSourceInspector.Import] = []

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let path = node.path.trimmedDescription
        if let module = path.split(separator: ".").first {
            imports.append(
                ArchitectureSourceInspector.Import(
                    moduleName: String(module),
                    attributes: attributeNames(in: node.attributes)
                )
            )
        }
        return .skipChildren
    }
}

private final class PropertyVisitor: SyntaxVisitor {
    var properties: [ArchitectureSourceInspector.Property] = []

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let access = accessLevel(in: node.modifiers)
        for binding in node.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
            properties.append(
                ArchitectureSourceInspector.Property(
                    name: identifier.identifier.text,
                    accessLevel: access,
                    type: binding.typeAnnotation?.type.trimmedDescription,
                    isStored: binding.accessorBlock == nil
                )
            )
        }
        return .skipChildren
    }
}

private final class TypealiasVisitor: SyntaxVisitor {
    var typealiases: [ArchitectureSourceInspector.TypealiasDeclaration] = []

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        typealiases.append(
            ArchitectureSourceInspector.TypealiasDeclaration(
                name: node.name.text,
                accessLevel: accessLevel(in: node.modifiers),
                assignedType: node.initializer.value.trimmedDescription
            )
        )
        return .skipChildren
    }
}

private final class ExtensionVisitor: SyntaxVisitor {
    var extensions: [ArchitectureSourceInspector.ExtensionDeclaration] = []

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        extensions.append(
            ArchitectureSourceInspector.ExtensionDeclaration(
                extendedType: node.extendedType.trimmedDescription,
                accessLevel: accessLevel(in: node.modifiers),
                inheritedTypes: node.inheritanceClause?.inheritedTypes.map {
                    $0.type.trimmedDescription
                } ?? []
            )
        )
        return .skipChildren
    }
}

private final class InitializerVisitor: SyntaxVisitor {
    var signatures: [String] = []
    private let source: String

    init(source: String, viewMode: SyntaxTreeViewMode) {
        self.source = source
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        signatures.append(signaturePrefix(for: Syntax(node), in: source))
        return .skipChildren
    }
}

private final class FunctionVisitor: SyntaxVisitor {
    var callables: [ArchitectureSourceInspector.Callable] = []
    private let source: String

    init(source: String, viewMode: SyntaxTreeViewMode) {
        self.source = source
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        callables.append(
            ArchitectureSourceInspector.Callable(
                kind: "func",
                name: node.name.text,
                accessLevel: accessLevel(in: node.modifiers),
                attributes: attributeNames(in: node.attributes),
                signature: signaturePrefix(for: Syntax(node), in: source),
                parameters: parameters(in: node.signature.parameterClause.parameters)
            )
        )
        return .skipChildren
    }
}

private final class DependencyAttributeVisitor: SyntaxVisitor {
    var keys: Set<String> = []

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        guard node.attributeName.trimmedDescription == "Dependency" else {
            return .visitChildren
        }
        guard let arguments = node.arguments?.trimmedDescription else {
            keys.insert("")
            return .skipChildren
        }
        if let key = dependencyKey(in: arguments) {
            keys.insert(key)
        } else {
            keys.insert(arguments)
        }
        return .skipChildren
    }

    private func dependencyKey(in arguments: String) -> String? {
        guard let marker = arguments.range(of: "\\.") else { return nil }
        let remainder = arguments[marker.upperBound...]
        let key = remainder.prefix { character in
            character.isLetter || character.isNumber || character == "_"
        }
        return key.isEmpty ? nil : String(key)
    }
}

private final class FunctionCallVisitor: SyntaxVisitor {
    var calls: [ArchitectureSourceInspector.FunctionCall] = []

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let expression = node.calledExpression.trimmedDescription
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self) {
            calls.append(
                ArchitectureSourceInspector.FunctionCall(
                    expression: expression,
                    base: member.base?.trimmedDescription,
                    name: member.declName.baseName.text
                )
            )
        } else if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            calls.append(
                ArchitectureSourceInspector.FunctionCall(
                    expression: expression,
                    base: nil,
                    name: reference.baseName.text
                )
            )
        } else {
            calls.append(
                ArchitectureSourceInspector.FunctionCall(
                    expression: expression,
                    base: nil,
                    name: expression
                )
            )
        }
        return .visitChildren
    }
}

private final class MemberAccessVisitor: SyntaxVisitor {
    var accesses: [ArchitectureSourceInspector.MemberAccess] = []

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        accesses.append(
            ArchitectureSourceInspector.MemberAccess(
                expression: node.trimmedDescription,
                base: node.base?.trimmedDescription,
                name: node.declName.baseName.text
            )
        )
        return .visitChildren
    }
}

private final class IdentifierReferenceVisitor: SyntaxVisitor {
    var identifiers: Set<String> = []

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        identifiers.insert(node.baseName.text)
        return .skipChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        identifiers.insert(node.name.text)
        return .visitChildren
    }
}

private final class DeclarationSourceVisitor: SyntaxVisitor {
    var declaration: String?
    private let source: String
    private let name: String

    init(source: String, name: String, viewMode: SyntaxTreeViewMode) {
        self.source = source
        self.name = name
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { record(node, named: node.name.text) }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { record(node, named: node.name.text) }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { record(node, named: node.name.text) }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { record(node, named: node.name.text) }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { record(node, named: node.name.text) }
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { record(node, named: node.name.text) }

    private func record(_ node: some SyntaxProtocol, named candidate: String) -> SyntaxVisitorContinueKind {
        guard declaration == nil, candidate == name else {
            return declaration == nil ? .visitChildren : .skipChildren
        }
        declaration = sourceSlice(for: Syntax(node), in: source)
        return .skipChildren
    }
}

private func accessLevel(in modifiers: DeclModifierListSyntax) -> String {
    for modifier in modifiers {
        let text = modifier.name.text
        if ["public", "package", "private", "fileprivate", "internal"].contains(text) {
            return text
        }
    }
    return "internal"
}

private func attributeNames(in attributes: AttributeListSyntax) -> Set<String> {
    Set(attributes.compactMap { element in
        element.as(AttributeSyntax.self)?.attributeName.trimmedDescription
    })
}

private func parameters(
    in parameters: FunctionParameterListSyntax
) -> [ArchitectureSourceInspector.Callable.Parameter] {
    parameters.map { parameter in
        ArchitectureSourceInspector.Callable.Parameter(
            firstName: parameter.firstName.text == "_" ? "_" : parameter.firstName.text,
            secondName: parameter.secondName?.text,
            type: parameter.type.trimmedDescription
        )
    }
}

private func signaturePrefix(for node: Syntax, in source: String) -> String {
    let declaration = sourceSlice(for: node, in: source)
    guard let openParen = declaration.firstIndex(of: "("),
          let closeParen = matchingDelimiter(in: declaration, open: openParen, opening: "(", closing: ")") else {
        return normalizedSignature(declaration)
    }
    return normalizedSignature(String(declaration[..<declaration.index(after: closeParen)]))
}

private func sourceSlice(for node: Syntax, in source: String) -> String {
    let start = node.positionAfterSkippingLeadingTrivia.utf8Offset
    let end = node.endPositionBeforeTrailingTrivia.utf8Offset
    let bytes = Array(source.utf8)
    guard start >= 0, end >= start, end <= bytes.count else { return "" }
    return String(decoding: bytes[start..<end], as: UTF8.self)
}

private func normalizedSignature(_ signature: String) -> String {
    signature
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .joined(separator: " ")
        .replacingOccurrences(of: #" +"#, with: " ", options: .regularExpression)
}

private func matchingDelimiter(
    in text: String,
    open: String.Index,
    opening: Character,
    closing: Character
) -> String.Index? {
    var depth = 0
    var cursor = open
    while cursor < text.endIndex {
        let character = text[cursor]
        if character == opening {
            depth += 1
        } else if character == closing {
            depth -= 1
            if depth == 0 { return cursor }
        }
        cursor = text.index(after: cursor)
    }
    return nil
}
