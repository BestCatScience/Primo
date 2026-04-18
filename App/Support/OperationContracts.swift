import Foundation

protocol OperationRequest: Sendable {}

protocol OperationResult: Sendable {}

protocol OperationFailure: Error, Sendable {}

protocol DomainCommand: Sendable {}

protocol DomainOutcome: Sendable {}

protocol FailureReason: Error, Sendable {}

protocol DomainIssue: Error, Sendable {}

protocol OperationContract {
    associatedtype Request: OperationRequest
    associatedtype Result: OperationResult
    associatedtype Failure: OperationFailure
}
