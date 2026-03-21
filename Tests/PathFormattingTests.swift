//
//  PathFormattingTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class PathFormattingTests: XCTestCase {
    func testShellQuotedEscapesSingleQuotes() {
        XCTAssertEqual("/tmp/it's-liney".shellQuoted, "'/tmp/it'\\''s-liney'")
    }

    func testAbbreviatedPathUsesTildeInsideHomeDirectory() {
        let home = NSHomeDirectory()
        XCTAssertEqual("\(home)/src/liney".abbreviatedPath, "~/src/liney")
    }
}
