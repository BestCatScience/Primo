import Foundation

protocol OperationRequest: Sendable {}

protocol OperationResult: Sendable {}

protocol OperationFailure: Error, Sendable {}

protocol OperationContract {
    associatedtype Request: OperationRequest
    associatedtype Result: OperationResult
    associatedtype Failure: OperationFailure
}
