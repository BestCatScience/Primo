import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentRuntime
import PrimoDocumentRuntimeLive
@testable import PrimoDocumentPresentationContracts
@testable import PrimoDocumentRenderingContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct DocumentRuntimeCompositionTests {
    private enum ReentrantFailure: Error, Equatable {
        case rejected
    }

    private final class MutableRuntime: @unchecked Sendable {
        var value: Int

        init(value: Int) {
            self.value = value
        }
    }

    @Test
    func runtimePresentationObservationPublishesInitialAndMutationSnapshots() async throws {
        let runtime = PrimoDocumentRuntimeLive.DocumentRuntimeFactory.live()
        var iterator = runtime.observePresentation().makeAsyncIterator()

        let initial = await iterator.next()
        #expect(initial?.canvasSize.width != 3)

        let outcome = await runtime.execute(.canvas(.create(width: 3, height: 3)))
        guard case .mutation(.success) = outcome else {
            Issue.record("Expected create command to succeed")
            return
        }

        let updated = await iterator.next()
        #expect(updated?.canvasSize.width == 3)
        #expect(updated?.canvasSize.height == 3)
    }

    @Test
    func runtimePresentationObservationPublishesInitialAndMutationSnapshotsToMultipleSubscribers() async throws {
        let runtime = PrimoDocumentRuntimeLive.DocumentRuntimeFactory.live()
        var first = runtime.observePresentation().makeAsyncIterator()
        var second = runtime.observePresentation().makeAsyncIterator()

        #expect(await first.next()?.canvasSize.width != 4)
        #expect(await second.next()?.canvasSize.width != 4)

        let size = try #require(ValidCanvasSize(4, 4))
        let outcome = await runtime.execute(.canvas(.createSized(size)))
        guard case .mutation(.success) = outcome else {
            Issue.record("Expected typed create command to succeed")
            return
        }

        #expect(await first.next()?.canvasSize.width == 4)
        #expect(await second.next()?.canvasSize.width == 4)
    }

    @Test
    func lockedRuntimeExecutorPerformResultRejectsReentrantAccessAsFailure() throws {
        let executor = LockedDocumentRuntimeExecutor(runtime: MutableRuntime(value: 1))

        let result: Result<Int, ReentrantFailure> = executor.performResult(failure: .rejected) { _ in
            executor.performResult(failure: .rejected) { runtime in
                .success(runtime.value)
            }
        }

        #expect(result == .failure(.rejected))
    }

    @Test
    func lockedRuntimeExecutorReplacementSwapsRuntimeForLaterAccess() throws {
        let executor = LockedDocumentRuntimeExecutor(runtime: MutableRuntime(value: 1))

        #expect(executor.performValue(failure: ReentrantFailure.rejected) { $0.value } == .success(1))
        guard case .success = executor.replaceRuntimeResult(with: MutableRuntime(value: 2), failure: ReentrantFailure.rejected) else {
            Issue.record("Expected runtime replacement to succeed")
            return
        }
        #expect(executor.performValue(failure: ReentrantFailure.rejected) { $0.value } == .success(2))
    }

    @Test
    func lockedRuntimeExecutorPreconditionBoundariesStayExplicit() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/DocumentRuntimeSupport.swift"
        )
        let body = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(body.contains("package static var reentrantAccessMessage"))
        #expect(!body.contains("precondition(!isExecuting, Self.reentrantAccessMessage)"))
        #expect(body.contains("package func performResult<Success, Failure: Error>"))
        #expect(body.contains("return .failure(failure())"))
        #expect(body.contains("package func replaceRuntimeResult<Failure: Error>("))
        #expect(body.contains("with newRuntime: Runtime,"))
        #expect(body.contains("failure: @autoclosure () -> Failure"))
    }


    @Test
    func editingGatewayExecutesLayerRequestsThroughSharedRuntime() throws {
        let runtime = PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live()

        let addResult = runtime.editingGateway.execute(
            .structure(.addLayer(name: "Foreground"))
        )
        let addPlan = try addResult.get()
        guard case let .structure(structurePlan) = addPlan else {
            Issue.record("Expected structure plan")
            return
        }
        #expect(structurePlan.resultingIndex == 1)

        let renameResult = runtime.editingGateway.execute(
            .attribute(.setLayerName(index: 1, name: "Ink"))
        )
        _ = try renameResult.get()

        let presentation = try runtime.queryGateway.lightweightPresentation().get()
        #expect(presentation.activeLayerIndex == 1)
        #expect(presentation.layerRows.count == 2)
        #expect(presentation.layerRows.first(where: { $0.index == 1 })?.name == "Ink")
    }

    @Test
    func compositionOverridesReturnNewBoundaryWhilePreservingSharedRuntime() throws {
        let runtime = PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live()
        let overridden = runtime.withOverrides(
            historyGateway: DocumentHistoryGateway(
                canUndo: { .success(false) },
                canRedo: { .success(false) },
                undo: { .failure(.noUndoState) },
                redo: { .failure(.noRedoState) }
            )
        )

        _ = try overridden.editingGateway.execute(
            .structure(.addLayer(name: "Foreground"))
        ).get()

        let presentation = try runtime.queryGateway.lightweightPresentation().get()
        #expect(presentation.layerRows.count == 2)
        #expect(try overridden.historyGateway.canUndo().get() == false)
        #expect(try runtime.historyGateway.canUndo().get())
    }

    @Test
    func compositionStoresGatewaysAsImmutablePublicBoundary() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let compositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift"
        )
        let body = try String(contentsOf: compositionURL, encoding: .utf8)

        #expect(body.contains("package struct DocumentRuntimeComposition"))
        #expect(body.contains("package let queryGateway: DocumentQueryGateway"))
        #expect(body.contains("package let renderGateway: DocumentRenderGateway"))
        #expect(body.contains("package let dirtyUpdateQueue: DocumentDirtyUpdateQueue"))
        #expect(body.contains("package let mutationGateway: DocumentMutationGateway"))
        #expect(body.contains("package let strokeGateway: StrokeInputGateway"))
        #expect(body.contains("package func withOverrides("))
        #expect(!body.contains("public let queryGateway: DocumentQueryGateway"))
        #expect(!body.contains("public func withOverrides("))
        #expect(!body.contains("public var queryGateway: DocumentQueryGateway"))
    }

    @Test
    func liveEditingGatewayRejectsStaleValidatedLayerIndexes() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let compositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift"
        )
        let body = try String(contentsOf: compositionURL, encoding: .utf8)

        #expect(body.contains("private func validateFreshLayerIndex(_ index: ExistingLayerIndex)"))
        #expect(body.contains("return .staleLayerIndex("))
        #expect(body.contains("validationRevision: index.revision"))
        #expect(body.contains("currentRevision: currentRevision"))
    }

    @Test
    func liveGatewayKeepsHeavyPersistenceAndExportWorkOutsideRuntimeLock() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let factoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let body = try String(contentsOf: factoryURL, encoding: .utf8)

        #expect(body.contains("let snapshot = try runtimeExecutor.performThrowing("))
        #expect(body.contains("$0.projectSaveSnapshot(paperStyle: paperStyle)"))
        #expect(body.contains("try snapshot.write(to: url, fileClient: fileClient, uuidClient: uuidClient)"))
        #expect(!body.contains("try runtimeExecutor.perform { session in\n                    try session.saveProject"))
        #expect(body.contains("SwiftDocumentRuntime.compositeExportSurface("))
        #expect(body.contains("SwiftDocumentRuntime.compositePNGData("))
        #expect(body.contains("forMaterializedSnapshot: $0"))
    }

    @Test
    func lockedRuntimeExecutorGuardsAgainstReentrantAccess() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let supportURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/DocumentRuntimeSupport.swift"
        )
        let body = try String(contentsOf: supportURL, encoding: .utf8)

        #expect(body.contains("package final class LockedDocumentRuntimeExecutor"))
        #expect(body.contains("package func performValue<Success, Failure: Error>("))
        #expect(body.contains("package func performResult<Success, Failure: Error>("))
        #expect(body.contains("private var isExecuting = false"))
        #expect(!body.contains("precondition(!isExecuting, Self.reentrantAccessMessage)"))
        #expect(body.contains("return .failure(failure())"))
        #expect(body.contains("NSRecursiveLock()"))
    }

    @Test
    func uncheckedSendableRuntimeInternalsStayPackageScoped() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceFiles = [
            "Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/DocumentRuntimeSupport.swift",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentStore.swift",
        ]
        let body = try sourceFiles
            .map { try String(contentsOf: repoRoot.appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")

        #expect(!body.contains("public actor DocumentRuntimeBox"))
        #expect(!body.contains("public final class LockedDocumentRuntimeExecutor"))
        #expect(!body.contains("public final class GpuResourceLease"))
        #expect(!body.contains("public final class SwiftDocumentRuntime"))
        #expect(!body.contains("public final class SwiftDocumentStore"))
        #expect(body.contains("package final class LockedDocumentRuntimeExecutor"))
        #expect(body.contains("final class GpuResourceLease: @unchecked Sendable"))
        #expect(body.contains("final class SwiftDocumentRuntime: @unchecked Sendable"))
        #expect(body.contains("final class SwiftDocumentStore: @unchecked Sendable"))
    }

    @Test
    func lockedRuntimeExecutorResultBoundaryReturnsFailureForReentrantAccess() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())

        let result: DocumentMutationResult = executor.performResult(failure: .emptyInput) { _ in
            executor.performResult(failure: .bridgeMutationFailed("reentrant")) { _ in
                .success(())
            }
        }

        guard case let .failure(failure) = result else {
            Issue.record("Expected reentrant access failure")
            return
        }
        #expect(failure == .bridgeMutationFailed("reentrant"))
    }

    @Test
    func lockedRuntimeExecutorPerformResultRejectsReentrantAccessFromPerform() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())

        let result: DocumentMutationResult = executor.performResult(failure: .bridgeMutationFailed("perform reentrant outer")) { _ in
            executor.performResult(failure: .bridgeMutationFailed("perform reentrant")) { _ in
                .success(())
            }
        }

        guard case let .failure(failure) = result else {
            Issue.record("Expected reentrant access failure")
            return
        }
        #expect(failure == .bridgeMutationFailed("perform reentrant"))
    }

    @Test
    func lockedRuntimeExecutorSerializesConcurrentSynchronousAccess() async {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    _ = executor.performMutation(failure: DocumentMutationFailure.bridgeMutationFailed("concurrent")) { runtime in
                        let nextValue = runtime.value + 1
                        runtime.value = nextValue
                    }
                }
            }
        }

        #expect(executor.performValue(failure: DocumentMutationFailure.bridgeMutationFailed("read")) { $0.value } == .success(1_000))
    }

    @Test
    func lockedRuntimeExecutorReplacementUsesSameSynchronousBoundary() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))

        _ = executor.replaceRuntimeResult(with: RuntimeCounter(value: 42), failure: DocumentMutationFailure.bridgeMutationFailed("replace"))

        #expect(executor.performValue(failure: DocumentMutationFailure.bridgeMutationFailed("read")) { $0.value } == .success(42))
    }

    @Test
    func lockedRuntimeExecutorReplacementWaitsForInFlightRead() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))
        let readStarted = DispatchSemaphore(value: 0)
        let releaseRead = DispatchSemaphore(value: 0)
        let readFinished = DispatchSemaphore(value: 0)
        let replacementFinished = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            _ = executor.performMutation(failure: DocumentMutationFailure.bridgeMutationFailed("read")) { runtime in
                #expect(runtime.value == 1)
                readStarted.signal()
                _ = releaseRead.wait(timeout: .now() + 2)
            }
            readFinished.signal()
        }

        guard readStarted.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected in-flight runtime read to start")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            _ = executor.replaceRuntimeResult(with: RuntimeCounter(value: 42), failure: DocumentMutationFailure.bridgeMutationFailed("replace"))
            replacementFinished.signal()
        }

        #expect(replacementFinished.wait(timeout: .now() + 0.1) == .timedOut)
        releaseRead.signal()

        guard readFinished.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected in-flight runtime read to finish")
            return
        }
        guard replacementFinished.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected runtime replacement to finish after read releases the lock")
            return
        }
        #expect(executor.performValue(failure: DocumentMutationFailure.bridgeMutationFailed("read")) { $0.value } == .success(42))
    }

    @Test
    func presentationObservationStopsRecordingAfterCancellation() async throws {
        let runtime = PrimoDocumentRuntimeLive.DocumentRuntimeFactory.live()
        let presentations = LockedValues<CGSize>()

        let consumer = Task {
            for await presentation in runtime.observePresentation() {
                presentations.append(presentation.canvasSize)
            }
        }

        try await waitUntil {
            presentations.count >= 1
        }
        consumer.cancel()
        await consumer.value
        let countAfterCancellation = presentations.count

        let outcome = await runtime.execute(.canvas(.create(width: 7, height: 7)))
        guard case .mutation(.success) = outcome else {
            Issue.record("Expected create command to succeed")
            return
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(presentations.count == countAfterCancellation)
    }

    @Test
    func runtimeFacadesReleasePreviewLeasesThroughSharedSurfaceBoundary() {
        let releasedHandles = LockedValues<MetalBufferHandle?>()
        let composition = PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live()
            .withOverrides(
                surfaceHandleReleaser: DocumentSurfaceHandleReleaser { handle in
                    releasedHandles.append(handle)
                }
            )
        let runtime = PrimoDocumentRuntime.DocumentApplicationRuntime(
            composition: PrimoDocumentRuntime.DocumentRuntimeComposition(composition)
        )
        let strokeHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let layerHandle = MetalBufferHandle.unsafeUnchecked(width: 3, height: 3, bytesPerRow: 12)

        runtime.workflows.strokeEditing.discardPreviewLease(StrokePreviewLease(surfaceHandle: strokeHandle))
        runtime.workflows.layerEditing.discardPreviewLease(StrokePreviewLease(surfaceHandle: layerHandle))

        #expect(releasedHandles.values == [strokeHandle, layerHandle])
    }

    @Test
    func liveGatewayKeepsGpuWorkBetweenRuntimeLockSections() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let factoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let body = try String(contentsOf: factoryURL, encoding: .utf8)
        let gpuOperations = [
            "plan.gpuServices.processLayer(",
            "plan.gpuServices.fillPixels(",
            "plan.gpuServices.commitStrokeMutation(",
            "plan.gpuServices.blurPixels("
        ]

        for operation in gpuOperations {
            #expect(body.contains(operation), "DocumentEngineLive should keep \(operation) visible outside runtime executor bodies")
        }
        #expect(body.contains("let planResult = runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"makeLayerProcessingPlan\"))"))
        #expect(body.contains("return runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"applyLayerProcessingPlan\"))"))
        #expect(body.contains("let planResult = runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"makeFillPlan\"))"))
        #expect(body.contains("return runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"applyFillPlan\"))"))
        #expect(body.contains("let planResult = runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"makeStrokeCommitPlan\"))"))
        #expect(body.contains("return runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"applyStrokeCommitPlan\"))"))
        #expect(body.contains("let reservationResult = runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"reserveBlurSession\"))"))
        #expect(body.contains("let planResult = runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"makeBlurPlan\"))"))
        #expect(body.contains("let mutationResult = runtimeExecutor.performResult(failure: reentrantRuntimeFailure(\"applyBlurPlan\"))"))
        #expect(body.contains("rollbackBlurSessionReservation(reservation, runtimeExecutor: runtimeExecutor)"))
    }

    @Test
    func runtimeFailureMappingPreservesTypedFailures() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let compositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift"
        )
        let body = try String(contentsOf: compositionURL, encoding: .utf8)

        #expect(body.contains("case let .alphaLocked(index):\n        return .alphaLocked(index)"))
        #expect(body.contains("case let .invalidCanvasSize(width, height):\n        return .invalidCanvasSize(width: width, height: height)"))
        #expect(body.contains("case .emptyInput:\n        return .emptyInput"))
        #expect(body.contains("case .noUndoState:\n        return .noUndoState"))
        #expect(body.contains("case let .incompatibleLayerType(index):\n        return .incompatibleLayerType(index)"))
        #expect(!body.contains("bridgeMutationFailed(\"alphaLocked\")"))
        #expect(!body.contains("bridgeMutationFailed(\"invalidCanvasSize\")"))
        #expect(!body.contains("bridgeMutationFailed(\"emptyInput\")"))
        #expect(!body.contains("bridgeMutationFailed(\"noUndoState\")"))
        #expect(!body.contains("bridgeMutationFailed(\"incompatibleLayerType\")"))
    }
}

private final class RuntimeCounter {
    var value: Int

    init(value: Int = 0) {
        self.value = value
    }
}

private final class LockedValues<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    func append(_ value: Value) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: @escaping @Sendable () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int(timeoutNanoseconds)))
    while !condition() {
        if ContinuousClock.now >= deadline {
            Issue.record("Timed out waiting for condition")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}
