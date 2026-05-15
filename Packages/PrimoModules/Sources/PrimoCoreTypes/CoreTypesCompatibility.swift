@_exported import PrimoCoreContracts
@_exported import PrimoSystemContracts

public typealias OperationRequest = PrimoCoreContracts.OperationRequest
public typealias OperationResult = PrimoCoreContracts.OperationResult
public typealias OperationFailure = PrimoCoreContracts.OperationFailure
public typealias DomainCommand = PrimoCoreContracts.DomainCommand
public typealias DomainOutcome = PrimoCoreContracts.DomainOutcome
public typealias FailureReason = PrimoCoreContracts.FailureReason
public typealias DomainIssue = PrimoCoreContracts.DomainIssue
public typealias OperationContract = PrimoCoreContracts.OperationContract

public typealias ProcessEnvironmentClient = PrimoSystemContracts.ProcessEnvironmentClient
public typealias MainQueueClient = PrimoSystemContracts.MainQueueClient
public typealias DateClient = PrimoSystemContracts.DateClient
public typealias UUIDClient = PrimoSystemContracts.UUIDClient
public typealias FileClient = PrimoSystemContracts.FileClient
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias HTTPClient = PrimoSystemContracts.HTTPClient
public typealias KeyValueStoreClient = PrimoSystemContracts.KeyValueStoreClient
public typealias SecretStoreError = PrimoSystemContracts.SecretStoreError
public typealias SecretStoreClient = PrimoSystemContracts.SecretStoreClient
public typealias SecurityScopedResourceClient = PrimoSystemContracts.SecurityScopedResourceClient
