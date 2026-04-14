//
//  AiyuTermGhosttyConfigTests.swift
//  AiyuTermTests
//
//  Author: wuwenrui
//

import XCTest
@testable import AiyuTerm

final class AiyuTermGhosttyConfigTests: XCTestCase {
    func testManagedConfigContentsIncludeFontOverrides() {
        let contents = AiyuTermGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalFontFamily: "JetBrains Mono",
                terminalFontSize: 14.2
            )
        )

        XCTAssertTrue(contents.contains("font-family = \"JetBrains Mono\""))
        XCTAssertTrue(contents.contains("font-size = 14"))
    }

    func testManagedConfigContentsOnlyContainHeaderWithoutOverrides() {
        let contents = AiyuTermGhosttyConfigManager.managedConfigContents(settings: AppSettings())

        XCTAssertEqual(
            contents,
            "# Managed by AiyuTerm. Manual edits will be overwritten.\nscrollbar-visible = false\n"
        )
    }
}
