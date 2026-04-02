//
//  WorkspaceTabsTests.swift
//  AiyuTermTests
//
//  Author: everettjf
//

import XCTest
@testable import Liney

final class WorkspaceTabsTests: XCTestCase {
    func testUpsertingAndSelectingTabsKeepsLegacyFieldsInSync() throws {
        var state = WorktreeSessionStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs")
        let firstTab = try XCTUnwrap(state.selectedTab)

        let secondTab = WorkspaceTabStateRecord.makeDefault(
            for: "/tmp/aiyuterm-tabs",
            title: "Tab 2"
        )
        state.upsertTab(secondTab, selecting: true)

        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertEqual(state.selectedTabID, secondTab.id)
        XCTAssertEqual(state.focusedPaneID, secondTab.focusedPaneID)

        state.setSelectedTabID(firstTab.id)

        XCTAssertEqual(state.selectedTabID, firstTab.id)
        XCTAssertEqual(state.layout, firstTab.layout)
        XCTAssertEqual(state.focusedPaneID, firstTab.focusedPaneID)
    }

    func testRemovingSelectedTabFallsBackToRemainingTab() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-close", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-close", title: "Tab 2")
        var state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/aiyuterm-tabs-close",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab],
            selectedTabID: secondTab.id
        )

        state.removeTab(secondTab.id)

        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.selectedTabID, firstTab.id)
        XCTAssertEqual(state.selectedTab?.id, firstTab.id)
    }

    func testRenamingTabMarksItAsManualAndPreservesSelection() throws {
        var state = WorktreeSessionStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-rename")
        let secondTab = WorkspaceTabStateRecord.makeDefault(
            for: "/tmp/aiyuterm-tabs-rename",
            title: "Tab 2"
        )
        state.upsertTab(secondTab, selecting: false)

        state.renameTab(secondTab.id, title: "Review Queue")

        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertEqual(state.tabs[1].title, "Review Queue")
        XCTAssertTrue(state.tabs[1].isManuallyNamed)
        XCTAssertEqual(state.selectedTabID, state.tabs[0].id)
    }

    func testMovingTabReordersWithoutChangingSelection() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-move", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-move", title: "Tab 2")
        let thirdTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-move", title: "Tab 3")
        var state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/aiyuterm-tabs-move",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab, thirdTab],
            selectedTabID: secondTab.id
        )

        state.moveTab(secondTab.id, by: 1)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 1", "Tab 3", "Tab 2"])
        XCTAssertEqual(state.selectedTabID, secondTab.id)

        state.moveTab(secondTab.id, by: -2)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 2", "Tab 1", "Tab 3"])
        XCTAssertEqual(state.selectedTabID, secondTab.id)
    }

    func testMovingTabToExplicitIndexSupportsDragReordering() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-drop", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-drop", title: "Tab 2")
        let thirdTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-drop", title: "Tab 3")
        let fourthTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-drop", title: "Tab 4")
        var state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/aiyuterm-tabs-drop",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab, thirdTab, fourthTab],
            selectedTabID: thirdTab.id
        )

        state.moveTab(firstTab.id, to: 3)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 2", "Tab 3", "Tab 4", "Tab 1"])
        XCTAssertEqual(state.selectedTabID, thirdTab.id)

        state.moveTab(fourthTab.id, to: 0)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 4", "Tab 2", "Tab 3", "Tab 1"])
        XCTAssertEqual(state.selectedTabID, thirdTab.id)
    }

    func testTabIDLookupByIndexReturnsExpectedTabAndRejectsOutOfRangeValues() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-select", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-select", title: "Tab 2")
        let thirdTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/aiyuterm-tabs-select", title: "Tab 3")
        let state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/aiyuterm-tabs-select",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab, thirdTab],
            selectedTabID: firstTab.id
        )

        XCTAssertEqual(state.tabID(at: 0), firstTab.id)
        XCTAssertEqual(state.tabID(at: 1), secondTab.id)
        XCTAssertEqual(state.tabID(at: 2), thirdTab.id)
        XCTAssertNil(state.tabID(at: 8))
    }
}
