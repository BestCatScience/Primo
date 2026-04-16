import Foundation

enum PrimoDocumentError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        "The selected Primo document is invalid."
    }
}
