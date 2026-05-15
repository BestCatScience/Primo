import Foundation

public protocol OperationRequest: Sendable {}

public protocol OperationResult: Sendable {}

public protocol OperationFailure: Error, Sendable {}

public protocol DomainCommand: Sendable {}

public protocol DomainOutcome: Sendable {}

public protocol FailureReason: Error, Sendable {}

public protocol DomainIssue: Error, Sendable {}

public protocol OperationContract {
    associatedtype Request: OperationRequest
    associatedtype Result: OperationResult
    associatedtype Failure: OperationFailure
}
