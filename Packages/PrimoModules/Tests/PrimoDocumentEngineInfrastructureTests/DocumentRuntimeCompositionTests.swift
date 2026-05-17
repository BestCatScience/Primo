import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime
import PrimoDocumentRuntimeLive
import PrimoDocumentStrokeApplication
@testable import PrimoDocumentPresentationContracts
@testable import PrimoDocumentRenderingContracts
@testable import PrimoDocumentRenderingInfrastructure
import Testing
@testable import PrimoDocumentEngineInfrastructure

private extension DocumentEngineRuntimeComposition {
    func withOverrides(
        queryGateway: DocumentQueryGateway? = nil,
        renderGateway: DocumentRenderGateway? = nil,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue? = nil,
        mutationGateway: DocumentMutationGateway? = nil,
        strokeGateway: StrokeInputGateway? = nil,
        historyGateway: DocumentHistoryGateway? = nil,
        persistenceGateway: DocumentPersistenceGateway? = nil,
        exportGateway: DocumentExportGateway? = nil,
        textLayerGateway: TextLayerGateway? = nil,
        layerEffectsGateway: DocumentLayerEffectsGateway? = nil,
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations? = nil,
        selectionMaskOperations: DocumentSelectionMaskOperations? = nil,
        layerTransformOperations: DocumentLayerTransformOperations? = nil,
        renderingOperations: DocumentRenderingOperations? = nil,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser? = nil
    ) -> DocumentEngineRuntimeComposition {
        DocumentEngineRuntimeComposition(
            queryGateway: queryGateway ?? self.queryGateway,
            renderGateway: renderGateway ?? self.renderGateway,
            dirtyUpdateQueue: dirtyUpdateQueue ?? self.dirtyUpdateQueue,
            mutationGateway: mutationGateway ?? self.mutationGateway,
            strokeGateway: strokeGateway ?? self.strokeGateway,
            historyGateway: historyGateway ?? self.historyGateway,
            persistenceGateway: persistenceGateway ?? self.persistenceGateway,
            exportGateway: exportGateway ?? self.exportGateway,
            textLayerGateway: textLayerGateway ?? self.textLayerGateway,
            layerEffectsGateway: layerEffectsGateway ?? self.layerEffectsGateway,
            editingGateway: editingGateway ?? self.editingGateway,
            strokeSessionUseCase: strokeSessionUseCase ?? self.strokeSessionUseCase,
            canvasPreviewOperations: canvasPreviewOperations ?? self.canvasPreviewOperations,
            selectionMaskOperations: selectionMaskOperations ?? self.selectionMaskOperations,
            layerTransformOperations: layerTransformOperations ?? self.layerTransformOperations,
            renderingOperations: renderingOperations ?? self.renderingOperations,
            surfaceHandleReleaser: surfaceHandleReleaser ?? self.surfaceHandleReleaser
        )
    }
}

private extension PrimoDocumentRuntime.DocumentRuntimeComposition {
    func withOverrides(
        queryGateway: DocumentQueryGateway? = nil,
        renderGateway: DocumentRenderGateway? = nil,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue? = nil,
        mutationGateway: DocumentMutationGateway? = nil,
        strokeGateway: StrokeInputGateway? = nil,
        historyGateway: DocumentHistoryGateway? = nil,
        persistenceGateway: DocumentPersistenceGateway? = nil,
        exportGateway: DocumentExportGateway? = nil,
        textLayerGateway: TextLayerGateway? = nil,
        layerEffectsGateway: DocumentLayerEffectsGateway? = nil,
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations? = nil,
        selectionMaskOperations: DocumentSelectionMaskOperations? = nil,
        layerTransformOperations: DocumentLayerTransformOperations? = nil,
        renderingOperations: DocumentRenderingOperations? = nil,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser? = nil
    ) -> PrimoDocumentRuntime.DocumentRuntimeComposition {
        PrimoDocumentRuntime.DocumentRuntimeComposition(
            queryGateway: queryGateway ?? self.queryGateway,
            renderGateway: renderGateway ?? self.renderGateway,
            dirtyUpdateQueue: dirtyUpdateQueue ?? self.dirtyUpdateQueue,
            mutationGateway: mutationGateway ?? self.mutationGateway,
            strokeGateway: strokeGateway ?? self.strokeGateway,
            historyGateway: historyGateway ?? self.historyGateway,
            persistenceGateway: persistenceGateway ?? self.persistenceGateway,
            exportGateway: exportGateway ?? self.exportGateway,
            textLayerGateway: textLayerGateway ?? self.textLayerGateway,
            layerEffectsGateway: layerEffectsGateway ?? self.layerEffectsGateway,
            editingGateway: editingGateway ?? self.editingGateway,
            strokeSessionUseCase: strokeSessionUseCase ?? self.strokeSessionUseCase,
            canvasPreviewOperations: canvasPreviewOperations ?? self.canvasPreviewOperations,
            selectionMaskOperations: selectionMaskOperations ?? self.selectionMaskOperations,
            layerTransformOperations: layerTransformOperations ?? self.layerTransformOperations,
            renderingOperations: renderingOperations ?? self.renderingOperations,
            surfaceHandleReleaser: surfaceHandleReleaser ?? self.surfaceHandleReleaser
        )
    }
}

struct DocumentRuntimeCompositionTests {
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

        let size = try #require(ValidCanvasSize(3, 3))
        let outcome = await runtime.execute(.canvas(.createSized(size)))
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

        let result: Result<Int, DocumentMutationFailure> = executor.performResult(operation: "outer") { _ in
            executor.performResult(operation: "inner") { runtime in
                .success(runtime.value)
            }
        }

        #expect(result == .failure(.rawAPIUnavailable(operation: "Reentrant document runtime access: inner")))
    }

    @Test
    func lockedRuntimeExecutorReplacementSwapsRuntimeForLaterAccess() throws {
        let executor = LockedDocumentRuntimeExecutor(runtime: MutableRuntime(value: 1))

        #expect(executor.performValue(operation: "read") { $0.value } == .success(1))
        guard case .success = executor.replaceRuntimeResult(with: MutableRuntime(value: 2), operation: "replace") else {
            Issue.record("Expected runtime replacement to succeed")
            return
        }
        #expect(executor.performValue(operation: "read") { $0.value } == .success(2))
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
        #expect(body.contains("package static func reentrantMutationFailure(operation: String) -> DocumentMutationFailure"))
        #expect(!body.contains("precondition(!isExecuting, Self.reentrantAccessMessage)"))
        #expect(body.contains("private func performResult<Success, Failure: Error>"))
        #expect(body.contains("package func performResult<Success>(\n        operation: String,"))
        #expect(body.contains("package func performThrowing<T>(\n        operation: String,"))
        #expect(body.contains("return .failure(failure())"))
        #expect(body.contains("private func replaceRuntimeResult<Failure: Error>("))
        #expect(body.contains("package func replaceRuntimeResult(\n        with newRuntime: Runtime,\n        operation: String"))
        #expect(body.contains("with newRuntime: Runtime,"))
        #expect(body.contains("failure: @autoclosure () -> Failure"))
    }


    @Test
    func editingGatewayExecutesLayerRequestsThroughSharedRuntime() throws {
        let runtime = PrimoDocumentEngineInfrastructure.DocumentEngineRuntimeCompositionFactory.live(
            gpuOperations: DocumentGpuOperationGatewayFactory.live()
        )

        let addResult = runtime.editingGateway.execute(
            .structure(.addLayer(name: "Foreground"))
        )
        let addPlan = try addResult.get()
        guard case let .structure(structurePlan) = addPlan else {
            Issue.record("Expected structure plan")
            return
        }
        #expect(structurePlan.result == .createdLayer(DocumentCreatedLayerIndex(1)))

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
    func testFixtureOverrideReturnsNewBoundaryWhilePreservingSharedRuntime() throws {
        let runtime = PrimoDocumentEngineInfrastructure.DocumentEngineRuntimeCompositionFactory.live(
            gpuOperations: DocumentGpuOperationGatewayFactory.live()
        )
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
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineRuntimeComposition.swift"
        )
        let runtimeCompositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift"
        )
        let testURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Tests/PrimoDocumentEngineInfrastructureTests/DocumentRuntimeCompositionTests.swift"
        )
        let body = try String(contentsOf: compositionURL, encoding: .utf8)
        let runtimeBody = try String(contentsOf: runtimeCompositionURL, encoding: .utf8)
        let testBody = try String(contentsOf: testURL, encoding: .utf8)

        #expect(body.contains("package struct DocumentEngineRuntimeComposition"))
        #expect(body.contains("package let queryGateway: DocumentQueryGateway"))
        #expect(body.contains("package let renderGateway: DocumentRenderGateway"))
        #expect(body.contains("package let dirtyUpdateQueue: DocumentDirtyUpdateQueue"))
        #expect(body.contains("package let mutationGateway: DocumentMutationGateway"))
        #expect(body.contains("package let strokeGateway: StrokeInputGateway"))
        #expect(!body.contains("func withOverrides("))
        #expect(!runtimeBody.contains("func withOverrides("))
        #expect(testBody.contains("func withOverrides("))
        #expect(!body.contains("public let queryGateway: DocumentQueryGateway"))
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
        let factoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let body = try String(contentsOf: factoryURL, encoding: .utf8)

        #expect(body.contains("private func validateFreshLayerIndex(_ index: ExistingLayerIndex)"))
        #expect(body.contains("return .staleLayerIndex("))
        #expect(body.contains("validationRevision: index.revision"))
        #expect(body.contains("currentRevision: currentPresentation.revision"))
    }

    @Test
    func liveEditingGatewayRejectsStaleValidatedFolderIDs() throws {
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

        #expect(body.contains("private func validateFreshFolderID(_ folderID: ExistingFolderID)"))
        #expect(body.contains("return .staleFolderID("))
        #expect(body.contains("validationRevision: folderID.revision"))
        #expect(body.contains("currentFolderIDs.contains(folderID.rawValue)"))
    }

    @Test
    func liveEditingGatewayCombinesValidationAndMutationInOneRuntimeOperation() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let factoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let gatewayFactoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineGatewayFactories.swift"
        )
        let compositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineRuntimeComposition.swift"
        )
        let factoryBody = try String(contentsOf: factoryURL, encoding: .utf8)
        let gatewayFactoryBody = try String(contentsOf: gatewayFactoryURL, encoding: .utf8)
        let compositionBody = try String(contentsOf: compositionURL, encoding: .utf8)

        #expect(gatewayFactoryBody.contains("runtimeExecutor.performResult(operation: \"executeDocumentEditorRequest\")"))
        #expect(gatewayFactoryBody.contains("let gateway = RuntimeDocumentEditorGateway("))
        #expect(factoryBody.contains("DocumentEngineEditingGatewayFactory.live(runtimeExecutor: runtimeExecutor)"))
        #expect(factoryBody.contains("DocumentEngineLayerEffectsFactory.live(runtimeExecutor: runtimeExecutor)"))
        #expect(factoryBody.contains("return runtime.clearLayer(index: index.rawValue)"))
        #expect(factoryBody.contains("return runtime.replaceLayerMask(index: index.rawValue, data: mask.bytes)"))
        #expect(factoryBody.contains("return runtime.deleteLayer(index: index.rawValue)"))
        #expect(compositionBody.contains("editingGateway: runtime.editingGateway"))
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
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineGatewayFactories.swift"
        )
        let body = try String(contentsOf: factoryURL, encoding: .utf8)

        #expect(body.contains("let snapshot = try runtimeExecutor.performThrowing("))
        #expect(body.contains("$0.projectSaveSnapshot(paperStyle: paperStyle)"))
        #expect(body.contains("try snapshot.write(to: location.fileURL, fileClient: fileClient, uuidClient: uuidClient)"))
        #expect(!body.contains("try runtimeExecutor.perform { session in\n                    try session.saveProject"))
        #expect(body.contains("SwiftDocumentRuntime.compositeExportSurface("))
        #expect(body.contains("SwiftDocumentRuntime.compositePNGData("))
        #expect(body.contains("forMaterializedSnapshot: $0"))
    }

    @Test
    func liveFactoryBuildsCapabilityGatewaysThroughFocusedHelpers() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let factoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let gatewayFactoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineGatewayFactories.swift"
        )
        let body = try String(contentsOf: factoryURL, encoding: .utf8)
        let gatewayFactoryBody = try String(contentsOf: gatewayFactoryURL, encoding: .utf8)

        #expect(body.contains("let queryGateway = DocumentEngineQueryGatewayFactory.live(runtimeExecutor: runtimeExecutor)"))
        #expect(body.contains("let mutationGateway = DocumentEngineMutationGatewayFactory.live(runtimeExecutor: runtimeExecutor)"))
        #expect(body.contains("let strokeGateway = DocumentEngineStrokeGatewayFactory.live(runtimeExecutor: runtimeExecutor)"))
        #expect(body.contains("let persistenceGateway = DocumentEnginePersistenceGatewayFactory.live("))
        #expect(body.contains("let exportGateway = DocumentEngineExportGatewayFactory.live("))
        for factoryName in [
            "DocumentEngineQueryGatewayFactory",
            "DocumentEngineRenderGatewayFactory",
            "DocumentEngineDirtyUpdateQueueFactory",
            "DocumentEngineMutationGatewayFactory",
            "DocumentEngineStrokeGatewayFactory",
            "DocumentEngineHistoryGatewayFactory",
            "DocumentEnginePersistenceGatewayFactory",
            "DocumentEngineExportGatewayFactory",
            "DocumentEngineTextLayerGatewayFactory",
            "DocumentEngineEditingGatewayFactory",
            "DocumentEngineLayerEffectsFactory"
        ] {
            #expect(gatewayFactoryBody.contains("enum \(factoryName)"), "Missing focused gateway factory \(factoryName)")
        }
        #expect(!body.contains("private static func makeQueryGateway("))
        #expect(!body.contains("private static func makeMutationGateway("))
        #expect(!body.contains("private static func makeStrokeGateway("))
        #expect(!body.contains("private static func makePersistenceGateway("))
        #expect(!body.contains("private static func makeExportGateway("))
    }

    @Test
    func runtimeServicesAreSplitIntoCapabilityGroups() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let facadeURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift"
        )
        let assemblyURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntimeLive/DocumentRuntimeServiceAssembly.swift"
        )
        let facadeBody = try String(contentsOf: facadeURL, encoding: .utf8)
        let assemblyBody = try String(contentsOf: assemblyURL, encoding: .utf8)

        #expect(!facadeBody.contains("struct DocumentRuntimeServices"))
        for services in [
            "DocumentPresentationServices",
            "DocumentMutationServices",
            "DocumentPreviewServices",
            "DocumentPersistenceServices"
        ] {
            #expect(facadeBody.contains("package struct \(services): Sendable"))
            #expect(assemblyBody.contains("package extension \(services)"))
        }
        for services in [
            "DocumentCanvasMutationServices",
            "DocumentLayerStructureMutationServices",
            "DocumentLayerContentMutationServices",
            "DocumentTextLayerMutationServices",
            "DocumentSelectionMutationServices",
            "DocumentCanvasEditingMutationServices",
            "DocumentStrokeMutationServices",
            "DocumentPreviewLeaseMutationServices"
        ] {
            #expect(facadeBody.contains("package struct \(services): Sendable"))
            #expect(assemblyBody.contains("package extension \(services)"))
        }
        for serviceSlot in [
            "package let canvas: DocumentCanvasMutationServices",
            "package let layerStructure: DocumentLayerStructureMutationServices",
            "package let layerContent: DocumentLayerContentMutationServices",
            "package let textLayer: DocumentTextLayerMutationServices",
            "package let selection: DocumentSelectionMutationServices",
            "package let canvasEditing: DocumentCanvasEditingMutationServices",
            "package let stroke: DocumentStrokeMutationServices",
            "package let previewLease: DocumentPreviewLeaseMutationServices"
        ] {
            #expect(facadeBody.contains(serviceSlot), "DocumentMutationServices should expose \(serviceSlot)")
        }
        #expect(assemblyBody.contains("let presentationServices = DocumentPresentationServices(composition: composition)"))
        #expect(assemblyBody.contains("let previewServices = DocumentPreviewServices(composition: composition)"))
        #expect(assemblyBody.contains("let mutationServices = DocumentMutationServices("))
        #expect(assemblyBody.contains("canvas: DocumentCanvasMutationServices(composition: composition)"))
        #expect(assemblyBody.contains("textLayer: DocumentTextLayerMutationServices("))
        #expect(assemblyBody.contains("stroke: DocumentStrokeMutationServices(composition: composition)"))
        #expect(assemblyBody.contains("CanvasMutationRuntime(services: mutationServices.canvas)"))
        #expect(assemblyBody.contains("CanvasStrokeRuntime(services: mutationServices.stroke)"))
        #expect(!facadeBody.contains("package var canvasCommands: DocumentCanvasCommandService"))
        #expect(!facadeBody.contains("package init(services: DocumentMutationServices)"))
        #expect(assemblyBody.contains("let persistenceServices = DocumentPersistenceServices(composition: composition)"))
        #expect(!assemblyBody.contains("DocumentRuntimeServices(composition: composition)"))
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
        #expect(body.contains("private func performValue<Success, Failure: Error>("))
        #expect(body.contains("private func performResult<Success, Failure: Error>("))
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

        let result: DocumentMutationResult = executor.performResult(operation: "outer") { _ in
            executor.performResult(operation: "inner") { _ in
                .success(())
            }
        }

        guard case let .failure(failure) = result else {
            Issue.record("Expected reentrant access failure")
            return
        }
        #expect(failure == .rawAPIUnavailable(operation: "Reentrant document runtime access: inner"))
    }

    @Test
    func lockedRuntimeExecutorPerformResultRejectsReentrantAccessFromPerform() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())
        var innerResult: DocumentMutationResult?

        let result: DocumentMutationResult = executor.performMutation(operation: "outer") { _ in
            innerResult = executor.performResult(operation: "inner") { _ in
                Result<Void, DocumentMutationFailure>.success(())
            }
        }

        guard case .success = result else {
            Issue.record("Expected outer mutation to succeed")
            return
        }
        if case let .failure(failure) = innerResult {
            #expect(failure == .rawAPIUnavailable(operation: "Reentrant document runtime access: inner"))
        } else {
            Issue.record("Expected inner result access to fail")
        }
        #expect(executor.performValue(operation: "read") { $0.value } == .success(0))
    }

    @Test
    func lockedRuntimeExecutorRejectsReentrantCallbackAccessAndKeepsOuterMutation() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())
        var callbackResult: Result<Int, DocumentMutationFailure>?

        let callback = {
            executor.performValue(operation: "callbackQuery") { runtime in
                runtime.value
            }
        }
        let result = executor.performMutation(operation: "outerMutation") { runtime in
            runtime.value = 7
            callbackResult = callback()
            runtime.value = 8
        }

        guard case .success = result else {
            Issue.record("Expected outer mutation to keep ownership of the runtime")
            return
        }
        #expect(callbackResult == .failure(.rawAPIUnavailable(operation: "Reentrant document runtime access: callbackQuery")))
        #expect(executor.performValue(operation: "read") { $0.value } == .success(8))
    }

    @Test
    func lockedRuntimeExecutorValueBoundaryRejectsNestedMutationAccess() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())

        let result = executor.performValue(operation: "outer") { _ in
            executor.performMutation(operation: "inner") { runtime in
                runtime.value = 99
            }
        }

        if case let .success(.failure(failure)) = result {
            #expect(failure == .rawAPIUnavailable(operation: "Reentrant document runtime access: inner"))
        } else {
            Issue.record("Expected nested mutation access to fail")
        }
        #expect(executor.performValue(operation: "read") { $0.value } == .success(0))
    }

    @Test
    func lockedRuntimeExecutorRejectsReentrantReplacementWithoutSwappingRuntime() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))

        let result = executor.performValue(operation: "outer") { _ in
            executor.replaceRuntimeResult(with: RuntimeCounter(value: 99), operation: "replace")
        }

        if case let .success(.failure(failure)) = result {
            #expect(failure == .rawAPIUnavailable(operation: "Reentrant document runtime access: replace"))
        } else {
            Issue.record("Expected nested replacement to fail")
        }
        #expect(executor.performValue(operation: "read") { $0.value } == .success(1))
    }

    @Test
    func lockedRuntimeExecutorThrowingBoundaryRejectsReentrantAccess() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())

        do {
            try executor.performThrowing(operation: "outer") { _ in
                _ = try executor.performThrowing(operation: "inner") { runtime in
                    runtime.value
                }
                Issue.record("Expected nested throwing access to fail")
            }
        } catch let failure as DocumentMutationFailure {
            #expect(failure == .rawAPIUnavailable(operation: "Reentrant document runtime access: inner"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func lockedRuntimeExecutorThrowingBoundaryRestoresAccessAfterBodyThrows() {
        struct ExpectedFailure: Error {}
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 3))

        do {
            try executor.performThrowing(operation: "throw") { _ in
                throw ExpectedFailure()
            }
            Issue.record("Expected body error to propagate")
        } catch is ExpectedFailure {
            #expect(executor.performValue(operation: "read") { $0.value } == .success(3))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func lockedRuntimeExecutorSerializesConcurrentSynchronousAccess() async {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter())

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    _ = executor.performMutation(operation: "concurrent") { runtime in
                        let nextValue = runtime.value + 1
                        runtime.value = nextValue
                    }
                }
            }
        }

        #expect(executor.performValue(operation: "read") { $0.value } == .success(1_000))
    }

    @Test
    func lockedRuntimeExecutorSerializesSimultaneousMutationsWithoutOverlap() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeConcurrencyProbe())
        let failures = LockedValues<DocumentMutationFailure>()

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            let result = executor.performMutation(operation: "simultaneousMutation") { runtime in
                runtime.enterMutationCriticalSection()
            }
            if case let .failure(failure) = result {
                failures.append(failure)
            }
        }

        let snapshot = executor.performValue(operation: "read") { runtime in
            (
                mutationCount: runtime.mutationCount,
                maximumActiveMutations: runtime.maximumActiveMutations,
                activeMutations: runtime.activeMutations
            )
        }
        #expect(failures.values.isEmpty)
        if case let .success(snapshot) = snapshot {
            #expect(snapshot.mutationCount == 64)
            #expect(snapshot.maximumActiveMutations == 1)
            #expect(snapshot.activeMutations == 0)
        } else {
            Issue.record("Expected serialized mutation snapshot")
        }
    }

    @Test
    func lockedRuntimeExecutorBlocksQueryDuringGpuApplySection() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))
        let applyStarted = DispatchSemaphore(value: 0)
        let releaseApply = DispatchSemaphore(value: 0)
        let applyFinished = DispatchSemaphore(value: 0)
        let queryFinished = DispatchSemaphore(value: 0)
        let applyResults = LockedValues<DocumentMutationResult>()
        let queryResults = LockedValues<Result<Int, DocumentMutationFailure>>()

        DispatchQueue.global(qos: .userInitiated).async {
            let result: DocumentMutationResult = executor.performResult(operation: "applyGpuPayload") { runtime in
                applyStarted.signal()
                _ = releaseApply.wait(timeout: .now() + 2)
                runtime.value = 42
                return .success(())
            }
            applyResults.append(result)
            applyFinished.signal()
        }

        guard applyStarted.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected GPU apply section to enter the runtime boundary")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            queryResults.append(
                executor.performValue(operation: "queryDuringGpuApply") { runtime in
                    runtime.value
                }
            )
            queryFinished.signal()
        }

        #expect(queryFinished.wait(timeout: .now() + 0.1) == .timedOut)
        releaseApply.signal()

        guard applyFinished.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected GPU apply section to finish")
            return
        }
        guard queryFinished.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected query to resume after GPU apply releases the runtime boundary")
            return
        }
        #expect(applyResults.values.count == 1)
        if case .success = applyResults.values.first {
        } else {
            Issue.record("Expected GPU apply mutation to succeed")
        }
        #expect(queryResults.values == [.success(42)])
    }

    @Test
    func lockedRuntimeExecutorReplacementUsesSameSynchronousBoundary() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))

        _ = executor.replaceRuntimeResult(with: RuntimeCounter(value: 42), operation: "replace")

        #expect(executor.performValue(operation: "read") { $0.value } == .success(42))
    }

    @Test
    func lockedRuntimeExecutorReplacementWaitsForInFlightRead() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))
        let readStarted = DispatchSemaphore(value: 0)
        let releaseRead = DispatchSemaphore(value: 0)
        let readFinished = DispatchSemaphore(value: 0)
        let replacementFinished = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            _ = executor.performMutation(operation: "read") { runtime in
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
            _ = executor.replaceRuntimeResult(with: RuntimeCounter(value: 42), operation: "replace")
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
        #expect(executor.performValue(operation: "read") { $0.value } == .success(42))
    }

    @Test
    func lockedRuntimeExecutorReplacementDuringQueryWaitsAndPreservesQuerySnapshot() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))
        let queryStarted = DispatchSemaphore(value: 0)
        let releaseQuery = DispatchSemaphore(value: 0)
        let queryFinished = DispatchSemaphore(value: 0)
        let replacementFinished = DispatchSemaphore(value: 0)
        let queryResults = LockedValues<Result<Int, DocumentMutationFailure>>()
        let replacementResults = LockedValues<DocumentMutationResult>()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = executor.performValue(operation: "longQuery") { runtime in
                let snapshot = runtime.value
                queryStarted.signal()
                _ = releaseQuery.wait(timeout: .now() + 2)
                return snapshot
            }
            queryResults.append(result)
            queryFinished.signal()
        }

        guard queryStarted.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected in-flight query to start")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            replacementResults.append(
                executor.replaceRuntimeResult(with: RuntimeCounter(value: 99), operation: "replaceDuringQuery")
            )
            replacementFinished.signal()
        }

        #expect(replacementFinished.wait(timeout: .now() + 0.1) == .timedOut)
        releaseQuery.signal()

        guard queryFinished.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected in-flight query to finish")
            return
        }
        guard replacementFinished.wait(timeout: .now() + 2) == .success else {
            Issue.record("Expected replacement to finish after query releases the runtime boundary")
            return
        }
        #expect(queryResults.values == [.success(1)])
        if case .success = replacementResults.values.first {
        } else {
            Issue.record("Expected runtime replacement to succeed")
        }
        #expect(executor.performValue(operation: "read") { $0.value } == .success(99))
    }

    @Test
    func lockedRuntimeExecutorUnlocksAfterResultFailure() {
        let executor = LockedDocumentRuntimeExecutor(runtime: RuntimeCounter(value: 1))

        let failure: DocumentMutationResult = executor.performResult(operation: "failingMutation") { _ in
            .failure(.emptyInput)
        }
        if case let .failure(documentFailure) = failure {
            #expect(documentFailure == .emptyInput)
        } else {
            Issue.record("Expected explicit failure result")
        }

        let mutation = executor.performMutation(operation: "afterFailure") { runtime in
            runtime.value = 5
        }
        guard case .success = mutation else {
            Issue.record("Expected later mutation to acquire the runtime boundary after failure")
            return
        }
        guard case .success = executor.replaceRuntimeResult(with: RuntimeCounter(value: 6), operation: "replaceAfterFailure") else {
            Issue.record("Expected later replacement to acquire the runtime boundary after failure")
            return
        }
        #expect(executor.performValue(operation: "read") { $0.value } == .success(6))
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

        let size = try #require(ValidCanvasSize(7, 7))
        let outcome = await runtime.execute(.canvas(.createSized(size)))
        guard case .mutation(.success) = outcome else {
            Issue.record("Expected create command to succeed")
            return
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(presentations.count == countAfterCancellation)
    }

    @Test
    func presentationObservationHandlesPublishAndCancellationRace() async throws {
        let runtime = PrimoDocumentRuntimeLive.DocumentRuntimeFactory.live()
        let receivedCounts = LockedValues<Int>()

        let consumers = (0..<40).map { _ in
            Task {
                var count = 0
                for await _ in runtime.observePresentation() {
                    count += 1
                    if count >= 2 {
                        break
                    }
                }
                receivedCounts.append(count)
            }
        }

        try await waitUntil {
            receivedCounts.count < consumers.count
        }
        for sizeValue in 3..<12 {
            let size = try #require(ValidCanvasSize(sizeValue, sizeValue))
            _ = await runtime.execute(.canvas(.createSized(size)))
        }
        for consumer in consumers {
            consumer.cancel()
            _ = await consumer.value
        }

        #expect(receivedCounts.count == consumers.count)
        #expect(receivedCounts.values.allSatisfy { $0 >= 1 })
    }

    @Test
    func presentationBroadcasterInstallsTerminationHandlerBeforeInitialRead() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntimeLive/DocumentRuntimePresentationBroadcaster.swift"
        )
        let body = try String(contentsOf: sourceURL, encoding: .utf8)
        let terminationRange = try #require(body.range(of: "continuation.onTermination ="))
        let firstReadRange = try #require(body.range(of: "currentPresentation()"))

        #expect(terminationRange.lowerBound < firstReadRange.lowerBound)
    }

    @Test
    func runtimeFacadesReleasePreviewLeasesThroughSharedSurfaceBoundary() {
        let releasedHandles = LockedValues<MetalBufferHandle?>()
        let composition = PrimoDocumentRuntime.DocumentRuntimeComposition(
            PrimoDocumentEngineInfrastructure.DocumentEngineRuntimeCompositionFactory.live(
                gpuOperations: DocumentGpuOperationGatewayFactory.live()
            )
        )
        .withOverrides(
            surfaceHandleReleaser: DocumentSurfaceHandleReleaser { handle in
                releasedHandles.append(handle)
            }
        )
        let runtime = PrimoDocumentRuntime.DocumentApplicationRuntime(
            composition: composition
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
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineGatewayFactories.swift"
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
        #expect(body.contains("let planResult = runtimeExecutor.performResult(operation: \"makeLayerProcessingPlan\")"))
        #expect(body.contains("return DocumentEngineGpuPayloadApplier.apply(\n                operation: \"applyLayerProcessingPlan\""))
        #expect(body.contains("let planResult = runtimeExecutor.performResult(operation: \"makeFillPlan\")"))
        #expect(body.contains("return DocumentEngineGpuPayloadApplier.apply(\n                operation: \"applyFillPlan\""))
        #expect(body.contains("let planResult = runtimeExecutor.performResult(operation: \"makeStrokeCommitPlan\")"))
        #expect(body.contains("return DocumentEngineGpuPayloadApplier.apply(\n                operation: \"applyStrokeCommitPlan\""))
        #expect(body.contains("let reservationResult = runtimeExecutor.performResult(operation: \"reserveBlurSession\")"))
        #expect(body.contains("let planResult = runtimeExecutor.performResult(operation: \"makeBlurPlan\")"))
        #expect(body.contains("let mutationResult = DocumentEngineGpuPayloadApplier.apply(\n                operation: \"applyBlurPlan\""))
        #expect(body.contains("rollbackBlurSessionReservation(reservation, runtimeExecutor: runtimeExecutor)"))
        #expect(body.contains("let payloadLease = GpuMutationPayloadLease(handle: handle, services: gpuServices)"))
        #expect(body.contains("payloadLease.withTransferredOwnership"))
        #expect(!body.contains("didTransferPayloadOwnershipToRuntime"))
    }

    @Test
    func runtimeFailureMappingPreservesTypedFailures() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let factoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let layerContractsURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerMutationContracts.swift"
        )
        let body = try String(contentsOf: factoryURL, encoding: .utf8)
        let layerContractsBody = try String(contentsOf: layerContractsURL, encoding: .utf8)

        let coreFailures: [DocumentMutationCoreFailure] = [
            .alphaLocked(1),
            .invalidCanvasSize(width: 2, height: 3),
            .emptyInput,
            .noUndoState,
            .incompatibleLayerType(4),
            .rollbackFailed(operation: "rollback", underlying: .layerLocked(5)),
            .transactionFailure(primary: .invalidFolderID(6), rollback: .noRedoState)
        ]
        for coreFailure in coreFailures {
            #expect(DocumentMutationFailure(coreFailure: coreFailure).coreFailure == coreFailure)
            #expect(DocumentLayerMutationFailure(coreFailure: coreFailure).coreFailure == coreFailure)
        }

        #expect(layerContractsBody.contains("public typealias DocumentLayerMutationFailure = DocumentMutationFailure"))
        #expect(!layerContractsBody.contains("public enum DocumentLayerMutationFailure"))
        #expect(body.contains("func mapDocumentEditorFailure(_ failure: DocumentLayerMutationFailure) -> DocumentMutationFailure"))
        #expect(body.contains("func mapDocumentRuntimeFailure(_ failure: DocumentMutationFailure) -> DocumentLayerMutationFailure"))
        #expect(body.contains("failure\n}"))
        #expect(!body.contains("DocumentMutationFailure(coreFailure: failure.coreFailure)"))
        #expect(!body.contains("DocumentLayerMutationFailure(coreFailure: failure.coreFailure)"))
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

private final class RuntimeConcurrencyProbe {
    private(set) var mutationCount = 0
    private(set) var activeMutations = 0
    private(set) var maximumActiveMutations = 0

    func enterMutationCriticalSection() {
        activeMutations += 1
        maximumActiveMutations = max(maximumActiveMutations, activeMutations)
        Thread.sleep(forTimeInterval: 0.001)
        mutationCount += 1
        activeMutations -= 1
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
