//
//  WorkspaceCoordinatorSupport.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

enum WorkspaceCoordinatorEffect: Hashable {
    case openURL(URL)
    case copyText(String)
}

struct WorkspaceCoordinatorActivityRecord: Hashable {
    let workspaceID: UUID
    let kind: WorkspaceActivityKind
    let title: String
    let detail: String
    let worktreePath: String?
    let replayAction: WorkspaceReplayAction?
}

struct WorkspaceCoordinatorStatusUpdate: Hashable {
    let text: String
    let tone: WorkspaceStatusTone
}
