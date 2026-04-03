//
//  DiffChangedFileTests.swift
//  AiyuTermTests
//
//  Author: wuwenrui
//

import XCTest
@testable import AiyuTerm

final class DiffChangedFileTests: XCTestCase {
    func testParseNameStatusHandlesModifiedAndDeletedFiles() {
        let output = """
        M\tSources/App.swift
        D\tREADME.md
        """

        let files = DiffChangedFile.parseNameStatus(output)

        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].status, .modified)
        XCTAssertEqual(files[0].oldPath, "Sources/App.swift")
        XCTAssertEqual(files[0].newPath, "Sources/App.swift")
        XCTAssertEqual(files[1].status, .deleted)
        XCTAssertEqual(files[1].oldPath, "README.md")
        XCTAssertNil(files[1].newPath)
    }

    func testParseNameStatusHandlesRenameAndCopyEntries() {
        let output = """
        R100\tSources/Old.swift\tSources/New.swift
        C075\tAssets/Base.png\tAssets/Copy.png
        """

        let files = DiffChangedFile.parseNameStatus(output)

        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].status, .renamed)
        XCTAssertEqual(files[0].oldPath, "Sources/Old.swift")
        XCTAssertEqual(files[0].newPath, "Sources/New.swift")
        XCTAssertEqual(files[1].status, .copied)
        XCTAssertEqual(files[1].oldPath, "Assets/Base.png")
        XCTAssertEqual(files[1].newPath, "Assets/Copy.png")
    }
}
