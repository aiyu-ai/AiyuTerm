//
//  PathFormattingTests.swift
//  AiyuTermTests
//
//  Author: everettjf
//

import XCTest
@testable import AiyuTerm

final class PathFormattingTests: XCTestCase {
    func testShellQuotedEscapesSingleQuotes() {
        XCTAssertEqual("/tmp/it's-aiyuterm".shellQuoted, "'/tmp/it'\\''s-aiyuterm'")
    }

    func testAbbreviatedPathUsesTildeInsideHomeDirectory() {
        let home = NSHomeDirectory()
        XCTAssertEqual("\(home)/src/aiyuterm".abbreviatedPath, "~/src/aiyuterm")
    }
}
