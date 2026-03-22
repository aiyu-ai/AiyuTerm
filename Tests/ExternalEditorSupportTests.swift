//
//  ExternalEditorSupportTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class ExternalEditorSupportTests: XCTestCase {
    func testLegacySettingsDecodeDefaultsPreferredExternalEditor() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))

        XCTAssertEqual(settings.preferredExternalEditor, .cursor)
    }

    func testInvalidPreferredExternalEditorFallsBackToDefault() throws {
        let settings = try JSONDecoder().decode(
            AppSettings.self,
            from: Data(#"{"preferredExternalEditor":"atom"}"#.utf8)
        )

        XCTAssertEqual(settings.preferredExternalEditor, .cursor)
    }

    func testEffectiveEditorPrefersInstalledDefault() {
        let cursor = ExternalEditorDescriptor(
            editor: .cursor,
            applicationName: "Cursor",
            applicationPath: "/Applications/Cursor.app"
        )
        let zed = ExternalEditorDescriptor(
            editor: .zed,
            applicationName: "Zed",
            applicationPath: "/Applications/Zed.app"
        )

        let resolved = ExternalEditorCatalog.effectiveEditor(preferred: .zed, among: [cursor, zed])

        XCTAssertEqual(resolved?.editor, .zed)
    }

    func testEffectiveEditorFallsBackToFirstAvailableEditor() {
        let zed = ExternalEditorDescriptor(
            editor: .zed,
            applicationName: "Zed",
            applicationPath: "/Applications/Zed.app"
        )
        let code = ExternalEditorDescriptor(
            editor: .visualStudioCode,
            applicationName: "Visual Studio Code",
            applicationPath: "/Applications/Visual Studio Code.app"
        )

        let resolved = ExternalEditorCatalog.effectiveEditor(preferred: .cursor, among: [zed, code])

        XCTAssertEqual(resolved?.editor, .zed)
    }
}
