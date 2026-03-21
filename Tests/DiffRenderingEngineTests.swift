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
        let rendered = DiffRenderingEngine.render(
            old: "one\ntwo\nthree\n",
            new: "one\nTWO\nthree\n"
        )

        XCTAssertEqual(rendered.addedLineCount, 1)
        XCTAssertEqual(rendered.removedLineCount, 1)
        XCTAssertEqual(rendered.splitRows.count, 3)
        XCTAssertEqual(rendered.splitRows[1].left?.text, "two")
        XCTAssertEqual(rendered.splitRows[1].left?.kind, .changedRemoved)
        XCTAssertEqual(rendered.splitRows[1].right?.text, "TWO")
        XCTAssertEqual(rendered.splitRows[1].right?.kind, .changedAdded)
    }

    func testRenderProducesUnifiedInsertionAndDeletionRows() {
        let rendered = DiffRenderingEngine.render(
            old: "alpha\nbeta\n",
            new: "alpha\ngamma\nbeta\n"
        )

        XCTAssertEqual(rendered.addedLineCount, 1)
        XCTAssertEqual(rendered.removedLineCount, 0)
        XCTAssertEqual(rendered.unifiedLines.map(\.text), ["alpha", "gamma", "beta"])
        XCTAssertEqual(rendered.unifiedLines.map(\.kind), [.context, .added, .context])
        XCTAssertEqual(rendered.unifiedLines[1].newLineNumber, 2)
        XCTAssertNil(rendered.unifiedLines[1].oldLineNumber)
    }
}
