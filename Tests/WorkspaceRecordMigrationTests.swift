//
//  WorkspaceRecordMigrationTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class WorkspaceRecordMigrationTests: XCTestCase {
    func testLegacyWorkspaceRecordDecodesIntoWorktreeState() throws {
        let paneID = UUID()
        let workspaceID = UUID()
        let json = """
        {
          "id": "\(workspaceID.uuidString)",
          "name": "Repo",
          "repositoryRoot": "/tmp/repo",
          "activeWorktreePath": "/tmp/repo",
          "layout": {
            "kind": "pane",
            "pane": { "paneID": "\(paneID.uuidString)" }
          },
          "panes": [
            {
              "id": "\(paneID.uuidString)",
              "preferredWorkingDirectory": "/tmp/repo",
              "shellPath": "/bin/zsh",
              "shellArguments": ["-l"],
              "preferredEngine": "libghosttyPreferred"
            }
          ],
          "focusedPaneID": "\(paneID.uuidString)",
          "isSidebarExpanded": true
        }
        """

        let decoded = try JSONDecoder().decode(WorkspaceRecord.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.worktreeStates.count, 1)
        XCTAssertEqual(decoded.worktreeStates[0].worktreePath, "/tmp/repo")
        XCTAssertEqual(decoded.worktreeStates[0].focusedPaneID, paneID)
        XCTAssertEqual(decoded.worktreeStates[0].tabs.count, 1)
        XCTAssertEqual(decoded.worktreeStates[0].selectedTab?.focusedPaneID, paneID)
        XCTAssertEqual(decoded.kind, .repository)
        XCTAssertTrue(decoded.isSidebarExpanded)
    }

    func testWorkspaceRecordPreservesZoomedPaneOnRoundTrip() throws {
        let paneID = UUID()
        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
        let record = WorkspaceRecord(
            id: UUID(),
            kind: .repository,
            name: "Repo",
            repositoryRoot: "/tmp/repo",
            activeWorktreePath: "/tmp/repo",
            worktreeStates: [
                WorktreeSessionStateRecord(
                    worktreePath: "/tmp/repo",
                    layout: .pane(PaneLeaf(paneID: paneID)),
                    panes: [PaneSnapshot.makeDefault(id: paneID, cwd: "/tmp/repo")],
                    focusedPaneID: paneID,
                    zoomedPaneID: paneID,
                    canvasState: WorkspaceCanvasStateRecord(
                        scale: 0.84,
                        offsetX: 120,
                        offsetY: -48,
                        cardLayouts: [
                            WorkspaceCanvasCardLayoutRecord(
                                tabID: tabID,
                                centerX: 320,
                                centerY: 240,
                                width: 300,
                                height: 260
                            )
                        ]
                    ),
                    tabs: [
                        WorkspaceTabStateRecord(
                            id: tabID,
                            title: "Build",
                            layout: .pane(PaneLeaf(paneID: paneID)),
                            panes: [PaneSnapshot.makeDefault(id: paneID, cwd: "/tmp/repo")],
                            focusedPaneID: paneID,
                            zoomedPaneID: paneID
                        )
                    ],
                    selectedTabID: tabID
                )
            ],
            isSidebarExpanded: false
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(WorkspaceRecord.self, from: data)

        XCTAssertEqual(decoded.worktreeStates.first?.zoomedPaneID, paneID)
        XCTAssertEqual(decoded.worktreeStates.first?.tabs.first?.title, "Build")
        XCTAssertEqual(decoded.worktreeStates.first?.selectedTabID, UUID(uuidString: "00000000-0000-0000-0000-000000000333"))
        XCTAssertEqual(decoded.worktreeStates.first?.canvasState.scale, 0.84)
        XCTAssertEqual(decoded.worktreeStates.first?.canvasState.offsetX, 120)
        XCTAssertEqual(decoded.worktreeStates.first?.canvasState.cardLayouts.first?.tabID, tabID)
    }

    func testLegacyTabRecordDefaultsManualNameFlagToFalse() throws {
        let paneID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
        let json = """
        {
          "id": "\(tabID.uuidString)",
          "title": "Tab 1",
          "layout": {
            "kind": "pane",
            "pane": { "paneID": "\(paneID.uuidString)" }
          },
          "panes": [
            {
              "id": "\(paneID.uuidString)",
              "preferredWorkingDirectory": "/tmp/repo",
              "shellPath": "/bin/zsh",
              "shellArguments": ["-l"],
              "preferredEngine": "libghosttyPreferred"
            }
          ],
          "focusedPaneID": "\(paneID.uuidString)"
        }
        """

        let decoded = try JSONDecoder().decode(WorkspaceTabStateRecord.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.id, tabID)
        XCTAssertEqual(decoded.title, "Tab 1")
        XCTAssertFalse(decoded.isManuallyNamed)
        XCTAssertEqual(decoded.focusedPaneID, paneID)
    }

    func testTabRecordRoundTripPreservesManualNameFlag() throws {
        let paneID = UUID()
        let tab = WorkspaceTabStateRecord(
            id: UUID(),
            title: "Review Queue",
            isManuallyNamed: true,
            layout: .pane(PaneLeaf(paneID: paneID)),
            panes: [PaneSnapshot.makeDefault(id: paneID, cwd: "/tmp/repo")],
            focusedPaneID: paneID,
            zoomedPaneID: nil
        )

        let encoded = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(WorkspaceTabStateRecord.self, from: encoded)

        XCTAssertEqual(decoded.title, "Review Queue")
        XCTAssertTrue(decoded.isManuallyNamed)
    }

    func testWorktreeSessionStatePrunesCanvasLayoutsForRemovedTabs() {
        let retainedTabID = UUID()
        let removedTabID = UUID()
        let retainedPaneID = UUID()
        let removedPaneID = UUID()
        var state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/repo",
            layout: nil,
            panes: [],
            focusedPaneID: nil,
            canvasState: WorkspaceCanvasStateRecord(
                scale: 1,
                offsetX: 24,
                offsetY: -12,
                cardLayouts: [
                    WorkspaceCanvasCardLayoutRecord(
                        tabID: retainedTabID,
                        centerX: 120,
                        centerY: 180,
                        width: 300,
                        height: 260
                    ),
                    WorkspaceCanvasCardLayoutRecord(
                        tabID: removedTabID,
                        centerX: 520,
                        centerY: 180,
                        width: 300,
                        height: 260
                    )
                ]
            ),
            tabs: [
                WorkspaceTabStateRecord(
                    id: retainedTabID,
                    title: "Retained",
                    layout: .pane(PaneLeaf(paneID: retainedPaneID)),
                    panes: [PaneSnapshot.makeDefault(id: retainedPaneID, cwd: "/tmp/repo")],
                    focusedPaneID: retainedPaneID
                ),
                WorkspaceTabStateRecord(
                    id: removedTabID,
                    title: "Removed",
                    layout: .pane(PaneLeaf(paneID: removedPaneID)),
                    panes: [PaneSnapshot.makeDefault(id: removedPaneID, cwd: "/tmp/repo")],
                    focusedPaneID: removedPaneID
                )
            ],
            selectedTabID: retainedTabID
        )

        state.removeTab(removedTabID)

        XCTAssertEqual(state.canvasState.cardLayouts.count, 1)
        XCTAssertEqual(state.canvasState.cardLayouts.first?.tabID, retainedTabID)
    }

    func testPersistedWorkspaceStateRoundTripPreservesGlobalCanvasState() throws {
        let workspaceID = UUID()
        let tabID = UUID()
        let state = PersistedWorkspaceState(
            selectedWorkspaceID: workspaceID,
            workspaces: [],
            globalCanvasState: GlobalCanvasStateRecord(
                scale: 0.91,
                offsetX: 120,
                offsetY: -44,
                cardLayouts: [
                    GlobalCanvasCardLayoutRecord(
                        workspaceID: workspaceID,
                        worktreePath: "/tmp/repo",
                        tabID: tabID,
                        centerX: 420,
                        centerY: 260,
                        width: 560,
                        height: 360,
                        isMinimized: true,
                        isPinned: true,
                        colorGroup: .teal
                    )
                ]
            )
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedWorkspaceState.self, from: data)

        XCTAssertEqual(decoded.globalCanvasState.scale, 0.91)
        XCTAssertEqual(decoded.globalCanvasState.offsetX, 120)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.workspaceID, workspaceID)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.tabID, tabID)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.isMinimized, true)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.isPinned, true)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.colorGroup, .teal)
    }

    func testPersistedWorkspaceStateMigratesLegacyWorktreeCanvasLayoutsIntoGlobalCanvasState() throws {
        let workspaceID = UUID(uuidString: "00000000-0000-0000-0000-000000000555")!
        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000556")!
        let paneID = UUID(uuidString: "00000000-0000-0000-0000-000000000557")!

        let json = """
        {
          "selectedWorkspaceID": "\(workspaceID.uuidString)",
          "workspaces": [
            {
              "id": "\(workspaceID.uuidString)",
              "kind": "repository",
              "name": "Repo",
              "repositoryRoot": "/tmp/repo",
              "activeWorktreePath": "/tmp/repo",
              "worktreeStates": [
                {
                  "worktreePath": "/tmp/repo",
                  "selectedTabID": "\(tabID.uuidString)",
                  "layout": {
                    "kind": "pane",
                    "pane": { "paneID": "\(paneID.uuidString)" }
                  },
                  "panes": [
                    {
                      "id": "\(paneID.uuidString)",
                      "preferredWorkingDirectory": "/tmp/repo",
                      "shellPath": "/bin/zsh",
                      "shellArguments": ["-l"],
                      "preferredEngine": "libghosttyPreferred"
                    }
                  ],
                  "focusedPaneID": "\(paneID.uuidString)",
                  "canvasState": {
                    "scale": 0.88,
                    "offsetX": 90,
                    "offsetY": -36,
                    "cardLayouts": [
                      {
                        "tabID": "\(tabID.uuidString)",
                        "centerX": 320,
                        "centerY": 220,
                        "width": 560,
                        "height": 360
                      }
                    ]
                  },
                  "tabs": [
                    {
                      "id": "\(tabID.uuidString)",
                      "title": "Build",
                      "layout": {
                        "kind": "pane",
                        "pane": { "paneID": "\(paneID.uuidString)" }
                      },
                      "panes": [
                        {
                          "id": "\(paneID.uuidString)",
                          "preferredWorkingDirectory": "/tmp/repo",
                          "shellPath": "/bin/zsh",
                          "shellArguments": ["-l"],
                          "preferredEngine": "libghosttyPreferred"
                        }
                      ],
                      "focusedPaneID": "\(paneID.uuidString)"
                    }
                  ]
                }
              ],
              "isSidebarExpanded": false,
              "worktrees": [],
              "settings": {},
              "activityLog": []
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(PersistedWorkspaceState.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.globalCanvasState.scale, 0.88)
        XCTAssertEqual(decoded.globalCanvasState.offsetX, 90)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.count, 1)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.workspaceID, workspaceID)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.worktreePath, "/tmp/repo")
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.tabID, tabID)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.isPinned, false)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.isMinimized, false)
        XCTAssertEqual(decoded.globalCanvasState.cardLayouts.first?.colorGroup, GlobalCanvasColorGroup.none)
    }

    func testGlobalCanvasCardLayoutDecodesNewCardFlagsWithDefaults() throws {
        let workspaceID = UUID()
        let tabID = UUID()
        let json = """
        {
          "workspaceID": "\(workspaceID.uuidString)",
          "worktreePath": "/tmp/repo",
          "tabID": "\(tabID.uuidString)",
          "centerX": 200,
          "centerY": 180,
          "width": 560,
          "height": 360
        }
        """

        let decoded = try JSONDecoder().decode(GlobalCanvasCardLayoutRecord.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.isMinimized)
        XCTAssertFalse(decoded.isPinned)
        XCTAssertEqual(decoded.colorGroup, GlobalCanvasColorGroup.none)
    }

    func testLegacyPaneSnapshotDecodesIntoLocalBackendConfiguration() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "preferredWorkingDirectory": "/tmp/repo",
          "shellPath": "/bin/bash",
          "shellArguments": ["-lc", "echo hi"],
          "preferredEngine": "swiftTermFallback"
        }
        """

        let decoded = try JSONDecoder().decode(PaneSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.backendConfiguration.kind, .localShell)
        XCTAssertEqual(decoded.backendConfiguration.localShell?.shellPath, "/bin/bash")
        XCTAssertEqual(decoded.backendConfiguration.localShell?.shellArguments, ["-lc", "echo hi"])
        XCTAssertEqual(decoded.preferredEngine, .libghosttyPreferred)
    }

    func testPaneSnapshotPersistsSSHBackend() throws {
        let snapshot = PaneSnapshot(
            id: UUID(),
            preferredWorkingDirectory: "/tmp/repo",
            preferredEngine: .libghosttyPreferred,
            backendConfiguration: .ssh(
                SSHSessionConfiguration(
                    host: "example.com",
                    user: "dev",
                    port: 2222,
                    identityFilePath: "~/.ssh/id_ed25519",
                    remoteWorkingDirectory: "/srv/app",
                    remoteCommand: "tmux attach || tmux"
                )
            )
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PaneSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.backendConfiguration.kind, .ssh)
        XCTAssertEqual(decoded.backendConfiguration.ssh?.host, "example.com")
        XCTAssertEqual(decoded.backendConfiguration.ssh?.user, "dev")
        XCTAssertEqual(decoded.backendConfiguration.ssh?.port, 2222)
        XCTAssertEqual(decoded.backendConfiguration.ssh?.remoteWorkingDirectory, "/srv/app")
    }
}
