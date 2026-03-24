//
//  DiffRenderingEngineTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class DiffRenderingEngineTests: XCTestCase {
    func testRenderPairsModifiedBlocksInSplitRows() {
        let result = DiffRenderingEngine.render(
            old: "one\ntwo\nthree\n",
            new: "one\nTWO\nthree\n"
        )
        guard case .document(let rendered) = result else {
            return XCTFail("Expected structured diff document")
        }

        XCTAssertEqual(rendered.addedLineCount, 1)
        XCTAssertEqual(rendered.removedLineCount, 1)
        XCTAssertEqual(rendered.splitRows.count, 3)
        XCTAssertEqual(rendered.splitRows[1].left?.text, "two")
        XCTAssertEqual(rendered.splitRows[1].left?.kind, .changedRemoved)
        XCTAssertEqual(rendered.splitRows[1].right?.text, "TWO")
        XCTAssertEqual(rendered.splitRows[1].right?.kind, .changedAdded)
    }

    func testRenderProducesUnifiedInsertionAndDeletionRows() {
        let result = DiffRenderingEngine.render(
            old: "alpha\nbeta\n",
            new: "alpha\ngamma\nbeta\n"
        )
        guard case .document(let rendered) = result else {
            return XCTFail("Expected structured diff document")
        }

        XCTAssertEqual(rendered.addedLineCount, 1)
        XCTAssertEqual(rendered.removedLineCount, 0)
        XCTAssertEqual(rendered.unifiedLines.map(\.text), ["alpha", "gamma", "beta"])
        XCTAssertEqual(rendered.unifiedLines.map(\.kind), [.context, .added, .context])
        XCTAssertEqual(rendered.unifiedLines[1].newLineNumber, 2)
        XCTAssertNil(rendered.unifiedLines[1].oldLineNumber)
    }

    func testRenderPatchParsesUnifiedHunkIntoStructuredDocument() {
        let patch = """
        diff --git a/a.txt b/a.txt
        --- a/a.txt
        +++ b/a.txt
        @@ -1,3 +1,3 @@
         one
        -two
        +TWO
         three
        """

        let rendered = DiffRenderingEngine.renderPatch(patch)

        XCTAssertEqual(rendered?.addedLineCount, 1)
        XCTAssertEqual(rendered?.removedLineCount, 1)
        XCTAssertEqual(rendered?.splitRows.count, 3)
        XCTAssertEqual(rendered?.splitRows[1].left?.text, "two")
        XCTAssertEqual(rendered?.splitRows[1].right?.text, "TWO")
    }

    func testAnalyzePatchCapturesLargeFileSignals() {
        let patch = """
        diff --git a/Sources/Large.swift b/Sources/Large.swift
        --- a/Sources/Large.swift
        +++ b/Sources/Large.swift
        @@ -1998,5 +1998,420 @@
         context
        """

        let analysis = DiffRenderingEngine.analyzePatch(patch)

        XCTAssertEqual(analysis.hunkCount, 1)
        XCTAssertEqual(analysis.maxOldSpan, 5)
        XCTAssertEqual(analysis.maxNewSpan, 420)
        XCTAssertEqual(analysis.totalNewSpan, 420)
        XCTAssertEqual(analysis.maxTouchedNewLine, 2417)
    }

    func testRenderRequiresPatchFallbackForLargeFiles() {
        let old = (0..<600).map { "old-\($0)" }.joined(separator: "\n")
        let new = (0..<600).map { "new-\($0)" }.joined(separator: "\n")

        let result = DiffRenderingEngine.render(old: old, new: new)

        guard case .requiresPatchFallback(let reason) = result else {
            return XCTFail("Expected patch fallback")
        }
        XCTAssertTrue(reason.contains("Structured diff exceeded supported limits"))
    }

    func testMakeDocumentUsesPatchHunksWhenStructuredDiffFallsBack() {
        let file = DiffChangedFile(status: .modified, oldPath: "Sources/Large.swift", newPath: "Sources/Large.swift")
        let old = (0..<600).map { "old-\($0)" }.joined(separator: "\n")
        let new = (0..<600).map { "new-\($0)" }.joined(separator: "\n")
        let result = DiffRenderingEngine.render(old: old, new: new)
        let patch = """
        diff --git a/Sources/Large.swift b/Sources/Large.swift
        --- a/Sources/Large.swift
        +++ b/Sources/Large.swift
        @@ -1,3 +1,3 @@
         line-1
        -line-2
        +line-2-updated
         line-3
        """

        let document = DiffWindowState.makeDocument(
            file: file,
            oldContents: old,
            newContents: new,
            unifiedPatch: patch,
            renderResult: result,
            renderElapsedMilliseconds: 1
        )

        XCTAssertFalse(document.isPatchOnly)
        XCTAssertFalse(document.supportsFullFileExpansion)
        XCTAssertEqual(document.renderedDiff.addedLineCount, 1)
        XCTAssertEqual(document.renderedDiff.removedLineCount, 1)
        XCTAssertEqual(document.renderedDiff.splitRows[1].right?.text, "line-2-updated")
    }

    func testMakeDocumentUsesPatchOnlyWhenPatchFallbackCannotBeParsed() {
        let file = DiffChangedFile(status: .modified, oldPath: "Sources/Large.swift", newPath: "Sources/Large.swift")
        let old = (0..<600).map { "old-\($0)" }.joined(separator: "\n")
        let new = (0..<600).map { "new-\($0)" }.joined(separator: "\n")
        let result = DiffRenderingEngine.render(old: old, new: new)

        let document = DiffWindowState.makeDocument(
            file: file,
            oldContents: old,
            newContents: new,
            unifiedPatch: "diff --git a/Sources/Large.swift b/Sources/Large.swift",
            renderResult: result,
            renderElapsedMilliseconds: 1
        )

        XCTAssertTrue(document.isPatchOnly)
        XCTAssertFalse(document.supportsFullFileExpansion)
        XCTAssertTrue(document.unifiedPatch.contains("Structured diff exceeded supported limits. Showing raw patch."))
    }

    func testMakeDocumentMarksStructuredDocumentsAsSupportingFullFileExpansion() {
        let file = DiffChangedFile(status: .modified, oldPath: "Sources/App.swift", newPath: "Sources/App.swift")
        let result = DiffRenderingEngine.render(old: "one\ntwo\n", new: "one\nTWO\n")

        let document = DiffWindowState.makeDocument(
            file: file,
            oldContents: "one\ntwo\n",
            newContents: "one\nTWO\n",
            unifiedPatch: """
            diff --git a/Sources/App.swift b/Sources/App.swift
            --- a/Sources/App.swift
            +++ b/Sources/App.swift
            @@ -1,2 +1,2 @@
             one
            -two
            +TWO
            """,
            renderResult: result,
            renderElapsedMilliseconds: 1
        )

        XCTAssertFalse(document.isPatchOnly)
        XCTAssertTrue(document.supportsFullFileExpansion)
    }

    func testPatchRenderingPreferenceReasonsPreferLargePatchOrFileSignals() {
        let analysis = DiffPatchAnalysis(
            hunkCount: 1,
            totalOldSpan: 3,
            totalNewSpan: 420,
            maxOldSpan: 3,
            maxNewSpan: 420,
            maxTouchedOldLine: 1999,
            maxTouchedNewLine: 2417
        )

        let reasons = DiffWindowState.patchRenderingPreferenceReasons(
            analysis: analysis,
            patchByteCount: 160_000,
            estimatedOldFileSize: 32_000,
            estimatedNewFileSize: 400_000
        )

        XCTAssertFalse(reasons.isEmpty)
        XCTAssertTrue(reasons.contains(where: { $0.contains("patch 160000B") }))
        XCTAssertTrue(reasons.contains(where: { $0.contains("file 400000B") }))
        XCTAssertTrue(reasons.contains(where: { $0.contains("max hunk span 420") }))
        XCTAssertTrue(reasons.contains(where: { $0.contains("touched line 2417") }))
    }
}
