import Foundation

enum PrimoDocumentError: LocalizedError {
    case invalidDocument
    case contractViolation(String)

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "The selected Primo document is invalid."
        case let .contractViolation(message):
            return message
        }
    }
}
