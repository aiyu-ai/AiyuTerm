//
//  WorkspaceGitHubCoordinator.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

protocol GitHubCLIClient {
    func integrationState() async -> GitHubIntegrationState
    func status(repositoryRoot: String, branch: String) async throws -> GitHubWorktreeStatus
    func openPullRequest(repositoryRoot: String, number: Int) async throws
    func markPullRequestReady(repositoryRoot: String, number: Int) async throws
    func updatePullRequestBranch(repositoryRoot: String, number: Int) async throws
    func queuePullRequest(repositoryRoot: String, number: Int) async throws
    func releaseNoteDraft(repositoryRoot: String, number: Int) async throws -> String
    func openRun(repositoryRoot: String, runID: Int) async throws
    func rerunFailedJobs(repositoryRoot: String, runID: Int) async throws
    func latestRunLogs(repositoryRoot: String, runID: Int) async throws -> String
}

extension GitHubCLIService: GitHubCLIClient {}

struct WorkspaceGitHubStatusRefreshResult {
    let statuses: [String: GitHubWorktreeStatus]
    let integrationStateOverride: GitHubIntegrationState?
    let statusUpdate: WorkspaceCoordinatorStatusUpdate?
}

struct WorkspaceGitHubCommandResult {
    var sideEffects: [WorkspaceCoordinatorEffect]
    var activities: [WorkspaceCoordinatorActivityRecord]
    var statusUpdate: WorkspaceCoordinatorStatusUpdate?
    var workspaceIDsToRefresh: Set<UUID>
    var shouldPersist: Bool

    init(
        sideEffects: [WorkspaceCoordinatorEffect] = [],
        activities: [WorkspaceCoordinatorActivityRecord] = [],
        statusUpdate: WorkspaceCoordinatorStatusUpdate? = nil,
        workspaceIDsToRefresh: Set<UUID> = [],
        shouldPersist: Bool = false
    ) {
        self.sideEffects = sideEffects
        self.activities = activities
        self.statusUpdate = statusUpdate
        self.workspaceIDsToRefresh = workspaceIDsToRefresh
        self.shouldPersist = shouldPersist
    }
}

struct WorkspaceGitHubBatchRequest: Hashable {
    let workspace: WorkspaceModel
    let worktreePath: String

    static func == (lhs: WorkspaceGitHubBatchRequest, rhs: WorkspaceGitHubBatchRequest) -> Bool {
        lhs.workspace.id == rhs.workspace.id && lhs.worktreePath == rhs.worktreePath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(workspace.id)
        hasher.combine(worktreePath)
    }
}

enum WorkspaceGitHubBatchAction {
    case updateBranch
    case queueMerge
    case copyReleaseContext
}

@MainActor
struct WorkspaceGitHubCoordinator {
    let client: any GitHubCLIClient

    func integrationState() async -> GitHubIntegrationState {
        await client.integrationState()
    }

    func refreshStatuses(
        for workspace: WorkspaceModel,
        integrationEnabled: Bool,
        currentIntegrationState: GitHubIntegrationState
    ) async -> WorkspaceGitHubStatusRefreshResult {
        guard workspace.supportsRepositoryFeatures else {
            return WorkspaceGitHubStatusRefreshResult(statuses: [:], integrationStateOverride: nil, statusUpdate: nil)
        }
        guard integrationEnabled else {
            return WorkspaceGitHubStatusRefreshResult(statuses: [:], integrationStateOverride: nil, statusUpdate: nil)
        }
        guard case .authorized = currentIntegrationState else {
            return WorkspaceGitHubStatusRefreshResult(statuses: workspace.gitHubStatuses, integrationStateOverride: nil, statusUpdate: nil)
        }

        var statuses = workspace.gitHubStatuses.filter { path, _ in
            workspace.worktrees.contains(where: { $0.path == path })
        }

        for worktree in workspace.worktrees {
            do {
                let status = try await client.status(repositoryRoot: workspace.repositoryRoot, branch: worktree.branch ?? "")
                statuses[worktree.path] = status
            } catch GitHubCLIError.unauthorized {
                return WorkspaceGitHubStatusRefreshResult(
                    statuses: statuses,
                    integrationStateOverride: .unauthorized,
                    statusUpdate: WorkspaceCoordinatorStatusUpdate(
                        text: "GitHub CLI is not authenticated. Run `gh auth login`.",
                        tone: .warning
                    )
                )
            } catch {
                continue
            }
        }

        return WorkspaceGitHubStatusRefreshResult(statuses: statuses, integrationStateOverride: nil, statusUpdate: nil)
    }

    func openPullRequest(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let number = pullRequestNumber(in: workspace, worktreePath: worktreePath) else {
            return missingPullRequestResult()
        }
        try await client.openPullRequest(repositoryRoot: workspace.repositoryRoot, number: number)
        return WorkspaceGitHubCommandResult(
            activities: [
                activity(
                    workspaceID: workspace.id,
                    kind: .github,
                    title: "Opened pull request",
                    detail: "#\(number) · \(worktreeDisplayName(in: workspace, path: worktreePath))",
                    worktreePath: worktreePath,
                    replayAction: .gitHub(.openPullRequest, worktreePath: worktreePath)
                )
            ]
        )
    }

    func markPullRequestReady(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let number = pullRequestNumber(in: workspace, worktreePath: worktreePath) else {
            return missingPullRequestResult()
        }
        try await client.markPullRequestReady(repositoryRoot: workspace.repositoryRoot, number: number)
        return WorkspaceGitHubCommandResult(
            activities: [
                activity(
                    workspaceID: workspace.id,
                    kind: .github,
                    title: "Marked PR ready",
                    detail: "#\(number) · \(worktreeDisplayName(in: workspace, path: worktreePath))",
                    worktreePath: worktreePath,
                    replayAction: .gitHub(.markPullRequestReady, worktreePath: worktreePath)
                )
            ],
            statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Marked pull request ready for review.", tone: .success),
            workspaceIDsToRefresh: [workspace.id],
            shouldPersist: true
        )
    }

    func updatePullRequestBranch(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let number = pullRequestNumber(in: workspace, worktreePath: worktreePath) else {
            return missingPullRequestResult()
        }
        try await client.updatePullRequestBranch(repositoryRoot: workspace.repositoryRoot, number: number)
        return WorkspaceGitHubCommandResult(
            activities: [
                activity(
                    workspaceID: workspace.id,
                    kind: .github,
                    title: "Rebased PR branch",
                    detail: "#\(number) · \(worktreeDisplayName(in: workspace, path: worktreePath))",
                    worktreePath: worktreePath,
                    replayAction: nil
                )
            ],
            statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Requested PR branch rebase.", tone: .success),
            workspaceIDsToRefresh: [workspace.id],
            shouldPersist: true
        )
    }

    func queuePullRequest(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let number = pullRequestNumber(in: workspace, worktreePath: worktreePath) else {
            return missingPullRequestResult()
        }
        try await client.queuePullRequest(repositoryRoot: workspace.repositoryRoot, number: number)
        return WorkspaceGitHubCommandResult(
            activities: [
                activity(
                    workspaceID: workspace.id,
                    kind: .github,
                    title: "Queued PR for merge",
                    detail: "#\(number) · \(worktreeDisplayName(in: workspace, path: worktreePath))",
                    worktreePath: worktreePath,
                    replayAction: nil
                )
            ],
            statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Queued pull request for auto-merge.", tone: .success),
            shouldPersist: true
        )
    }

    func copyPullRequestReleaseNotes(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let number = pullRequestNumber(in: workspace, worktreePath: worktreePath) else {
            return missingPullRequestResult()
        }
        let draft = try await client.releaseNoteDraft(repositoryRoot: workspace.repositoryRoot, number: number)
        return WorkspaceGitHubCommandResult(
            sideEffects: [.copyText(draft)],
            activities: [
                activity(
                    workspaceID: workspace.id,
                    kind: .release,
                    title: "Generated release context",
                    detail: "#\(number) · copied to clipboard",
                    worktreePath: worktreePath,
                    replayAction: nil
                )
            ],
            statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Release draft context copied to clipboard.", tone: .success),
            shouldPersist: true
        )
    }

    func executeBatch(
        _ action: WorkspaceGitHubBatchAction,
        requests: [WorkspaceGitHubBatchRequest]
    ) async throws -> WorkspaceGitHubCommandResult {
        let normalizedRequests = Self.normalize(requests)
        guard !normalizedRequests.isEmpty else {
            return WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: emptyBatchMessage(for: action), tone: .warning))
        }
        let orderedRequests: [WorkspaceGitHubBatchRequest]
        switch action {
        case .copyReleaseContext:
            orderedRequests = normalizedRequests.sorted(by: Self.releaseContextSort)
        case .updateBranch, .queueMerge:
            orderedRequests = normalizedRequests
        }

        var succeeded = 0
        var failed = 0
        var refreshIDs = Set<UUID>()
        var activities: [WorkspaceCoordinatorActivityRecord] = []
        var drafts: [String] = []

        for request in orderedRequests {
            guard let number = pullRequestNumber(in: request.workspace, worktreePath: request.worktreePath) else {
                failed += 1
                continue
            }

            do {
                switch action {
                case .updateBranch:
                    try await client.updatePullRequestBranch(repositoryRoot: request.workspace.repositoryRoot, number: number)
                    activities.append(
                        activity(
                            workspaceID: request.workspace.id,
                            kind: .github,
                            title: "Rebased PR branch",
                            detail: "#\(number) · \(worktreeDisplayName(in: request.workspace, path: request.worktreePath))",
                            worktreePath: request.worktreePath,
                            replayAction: nil
                        )
                    )
                    refreshIDs.insert(request.workspace.id)
                case .queueMerge:
                    try await client.queuePullRequest(repositoryRoot: request.workspace.repositoryRoot, number: number)
                    activities.append(
                        activity(
                            workspaceID: request.workspace.id,
                            kind: .github,
                            title: "Queued PR for merge",
                            detail: "#\(number) · \(worktreeDisplayName(in: request.workspace, path: request.worktreePath))",
                            worktreePath: request.worktreePath,
                            replayAction: nil
                        )
                    )
                case .copyReleaseContext:
                    let draft = try await client.releaseNoteDraft(repositoryRoot: request.workspace.repositoryRoot, number: number)
                    drafts.append(["## \(request.workspace.name) · PR #\(number)", draft].joined(separator: "\n"))
                    activities.append(
                        activity(
                            workspaceID: request.workspace.id,
                            kind: .release,
                            title: "Generated release context",
                            detail: "#\(number) · included in batch draft",
                            worktreePath: request.worktreePath,
                            replayAction: nil
                        )
                    )
                }
                succeeded += 1
            } catch {
                failed += 1
            }
        }

        var result = WorkspaceGitHubCommandResult(
            activities: activities,
            statusUpdate: WorkspaceCoordinatorStatusUpdate(
                text: batchSummary(action: action, success: succeeded, failed: failed),
                tone: failed > 0 ? .warning : .success
            ),
            workspaceIDsToRefresh: refreshIDs,
            shouldPersist: succeeded > 0
        )

        if action == .copyReleaseContext, !drafts.isEmpty {
            result.sideEffects.append(.copyText(drafts.joined(separator: "\n\n---\n\n")))
        } else if action == .copyReleaseContext, drafts.isEmpty {
            result.statusUpdate = WorkspaceCoordinatorStatusUpdate(
                text: "Unable to generate release context for the selected pull requests.",
                tone: .warning
            )
        }

        return result
    }

    func openLatestRun(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let latestRun = workspace.gitHubStatus(for: worktreePath)?.latestRun else {
            return WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "No CI run found for this worktree.", tone: .warning))
        }
        try await client.openRun(repositoryRoot: workspace.repositoryRoot, runID: latestRun.id)
        return WorkspaceGitHubCommandResult(
            activities: [
                activity(
                    workspaceID: workspace.id,
                    kind: .github,
                    title: "Opened latest CI run",
                    detail: worktreeDisplayName(in: workspace, path: worktreePath),
                    worktreePath: worktreePath,
                    replayAction: .gitHub(.openLatestRun, worktreePath: worktreePath)
                )
            ]
        )
    }

    func openFailingCheckDetails(workspace: WorkspaceModel, worktreePath: String) -> WorkspaceGitHubCommandResult {
        guard let urlString = workspace.gitHubStatus(for: worktreePath)?.checksSummary?.failingChecks.first?.link,
              let url = URL(string: urlString) else {
            return WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "No failing check details found for this worktree.", tone: .warning))
        }
        return WorkspaceGitHubCommandResult(sideEffects: [.openURL(url)])
    }

    func copyFailingCheckURL(workspace: WorkspaceModel, worktreePath: String) -> WorkspaceGitHubCommandResult {
        guard let urlString = workspace.gitHubStatus(for: worktreePath)?.checksSummary?.failingChecks.first?.link else {
            return WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "No failing check URL found for this worktree.", tone: .warning))
        }
        return WorkspaceGitHubCommandResult(
            sideEffects: [.copyText(urlString)],
            statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Failing check URL copied to clipboard.", tone: .success)
        )
    }

    func rerunLatestFailedJobs(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let latestRun = workspace.gitHubStatus(for: worktreePath)?.latestRun else {
            return WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "No CI run found for this worktree.", tone: .warning))
        }
        guard latestRun.isFailing else {
            return WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Latest CI run is not failing.", tone: .neutral))
        }
        try await client.rerunFailedJobs(repositoryRoot: workspace.repositoryRoot, runID: latestRun.id)
        return WorkspaceGitHubCommandResult(
            statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Requested rerun for failed jobs.", tone: .success)
        )
    }

    func copyLatestRunLogs(workspace: WorkspaceModel, worktreePath: String) async throws -> WorkspaceGitHubCommandResult {
        guard let latestRun = workspace.gitHubStatus(for: worktreePath)?.latestRun else {
            return WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "No CI run found for this worktree.", tone: .warning))
        }
        let logs = try await client.latestRunLogs(repositoryRoot: workspace.repositoryRoot, runID: latestRun.id)
        return WorkspaceGitHubCommandResult(
            sideEffects: [.copyText(logs)],
            statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "Latest CI logs copied to clipboard.", tone: .success)
        )
    }

    private func pullRequestNumber(in workspace: WorkspaceModel, worktreePath: String) -> Int? {
        workspace.gitHubStatus(for: worktreePath)?.pullRequest?.number
    }

    private func worktreeDisplayName(in workspace: WorkspaceModel, path: String) -> String {
        workspace.worktrees.first(where: { $0.path == path })?.displayName ?? URL(fileURLWithPath: path).lastPathComponent
    }

    private func missingPullRequestResult() -> WorkspaceGitHubCommandResult {
        WorkspaceGitHubCommandResult(statusUpdate: WorkspaceCoordinatorStatusUpdate(text: "No pull request found for this worktree.", tone: .warning))
    }

    private func activity(
        workspaceID: UUID,
        kind: WorkspaceActivityKind,
        title: String,
        detail: String,
        worktreePath: String?,
        replayAction: WorkspaceReplayAction?
    ) -> WorkspaceCoordinatorActivityRecord {
        WorkspaceCoordinatorActivityRecord(
            workspaceID: workspaceID,
            kind: kind,
            title: title,
            detail: detail,
            worktreePath: worktreePath,
            replayAction: replayAction
        )
    }

    private func emptyBatchMessage(for action: WorkspaceGitHubBatchAction) -> String {
        switch action {
        case .updateBranch:
            return "No pull requests are available for batch update."
        case .queueMerge:
            return "No merge-ready pull requests are available."
        case .copyReleaseContext:
            return "No pull requests are available for release context."
        }
    }

    private func batchSummary(action: WorkspaceGitHubBatchAction, success: Int, failed: Int) -> String {
        let successMessage: String
        switch action {
        case .updateBranch:
            successMessage = "Updated PR branches."
        case .queueMerge:
            successMessage = "Queued pull requests for auto-merge."
        case .copyReleaseContext:
            successMessage = "Combined release context copied to clipboard."
        }

        if success == 0, failed > 0 {
            return "Batch action failed for \(failed) pull request(s)."
        }
        if failed > 0 {
            return "\(successMessage) \(success) succeeded, \(failed) failed."
        }
        return "\(successMessage) \(success) total."
    }

    private static func normalize(_ requests: [WorkspaceGitHubBatchRequest]) -> [WorkspaceGitHubBatchRequest] {
        var seen = Set<WorkspaceGitHubBatchRequest>()
        var result: [WorkspaceGitHubBatchRequest] = []
        for request in requests where seen.insert(request).inserted {
            result.append(request)
        }
        return result
    }

    private static func releaseContextSort(lhs: WorkspaceGitHubBatchRequest, rhs: WorkspaceGitHubBatchRequest) -> Bool {
        let nameComparison = lhs.workspace.name.localizedCaseInsensitiveCompare(rhs.workspace.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        if lhs.workspace.repositoryRoot != rhs.workspace.repositoryRoot {
            return lhs.workspace.repositoryRoot < rhs.workspace.repositoryRoot
        }
        return lhs.worktreePath < rhs.worktreePath
    }
}
