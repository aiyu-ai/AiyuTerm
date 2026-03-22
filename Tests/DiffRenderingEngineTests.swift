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
        XCTAssertTrue(document.unifiedPatch.contains("Structured diff exceeded supported limits. Showing raw patch."))
    }
}
