//
//  GitHubCLIService.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

enum GitHubCLIError: LocalizedError {
    case unavailable
    case unauthorized
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "GitHub CLI is unavailable. Install `gh` first."
        case .unauthorized:
            return "GitHub CLI is not authenticated. Run `gh auth login`."
        case .commandFailed(let message):
            return message
        }
    }
}

actor GitHubCLIService {
    private let runner = ShellCommandRunner()
    private let releaseNoteCommitLimit = 50

    func integrationState() async -> GitHubIntegrationState {
        guard await isAvailable() else {
            return .unavailable
        }
        do {
            if let auth = try await authStatus() {
                return .authorized(auth)
            }
            return .unauthorized
        } catch {
            return .unauthorized
        }
    }

    func isAvailable() async -> Bool {
        do {
            let result = try await runner.run(executable: "/usr/bin/env", arguments: ["which", "gh"])
            return result.exitCode == 0 && !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    func authStatus() async throws -> GitHubAuthStatus? {
        let result = try await runGh(arguments: ["auth", "status", "--json", "hosts"])
        guard result.exitCode == 0 else {
            if result.stderr.localizedCaseInsensitiveContains("not logged") {
                return nil
            }
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to determine GitHub auth state."))
        }

        let data = Data(result.stdout.utf8)
        let decoded = try JSONDecoder().decode(GitHubAuthStatusResponse.self, from: data)
        for (host, accounts) in decoded.hosts {
            if let active = accounts.first(where: \.active) {
                return GitHubAuthStatus(username: active.login, host: host)
            }
        }
        return nil
    }

    func status(repositoryRoot: String, branch: String) async throws -> GitHubWorktreeStatus {
        async let run = latestRun(repositoryRoot: repositoryRoot, branch: branch)
        let pr = try await pullRequest(repositoryRoot: repositoryRoot, branch: branch)
        let checksSummary: GitHubPullRequestChecksSummary?
        if let pr, pr.isOpen {
            checksSummary = try await pullRequestChecks(repositoryRoot: repositoryRoot, number: pr.number)
        } else {
            checksSummary = nil
        }
        return GitHubWorktreeStatus(
            pullRequest: pr,
            checksSummary: checksSummary,
            latestRun: try await run
        )
    }

    func openPullRequest(repositoryRoot: String, number: Int) async throws {
        let result = try await runGh(arguments: ["pr", "view", String(number), "--web"], currentDirectory: repositoryRoot)
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to open pull request."))
        }
    }

    func markPullRequestReady(repositoryRoot: String, number: Int) async throws {
        let result = try await runGh(arguments: ["pr", "ready", String(number)], currentDirectory: repositoryRoot)
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to mark pull request ready for review."))
        }
    }

    func updatePullRequestBranch(repositoryRoot: String, number: Int) async throws {
        let result = try await runGh(arguments: ["pr", "update-branch", String(number), "--rebase"], currentDirectory: repositoryRoot)
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to update pull request branch."))
        }
    }

    func queuePullRequest(repositoryRoot: String, number: Int) async throws {
        let result = try await runGh(arguments: ["pr", "merge", String(number), "--auto", "--squash"], currentDirectory: repositoryRoot)
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to queue pull request for merge."))
        }
    }

    func releaseNoteDraft(repositoryRoot: String, number: Int) async throws -> String {
        let details = try await pullRequestReleaseNoteDetails(repositoryRoot: repositoryRoot, number: number)
        return Self.renderReleaseNoteDraft(details: details, commitLimit: releaseNoteCommitLimit)
    }

    func openRun(repositoryRoot: String, runID: Int) async throws {
        let result = try await runGh(arguments: ["run", "view", String(runID), "--web"], currentDirectory: repositoryRoot)
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to open workflow run."))
        }
    }

    func rerunFailedJobs(repositoryRoot: String, runID: Int) async throws {
        let result = try await runGh(arguments: ["run", "rerun", String(runID), "--failed"], currentDirectory: repositoryRoot)
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to rerun failed jobs."))
        }
    }

    func latestRunLogs(repositoryRoot: String, runID: Int) async throws -> String {
        let result = try await runGh(arguments: ["run", "view", String(runID), "--log"], currentDirectory: repositoryRoot)
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to load workflow logs."))
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pullRequest(repositoryRoot: String, branch: String) async throws -> GitHubPullRequestSummary? {
        guard !branch.isEmpty, branch != "HEAD" else { return nil }
        let result = try await runGh(
            arguments: [
                "pr", "view", branch,
                "--json", "number,title,url,state,isDraft,headRefName,mergeStateStatus,reviewDecision,reviewRequests,latestReviews,assignees"
            ],
            currentDirectory: repositoryRoot
        )
        guard result.exitCode == 0 else {
            if result.stderr.localizedCaseInsensitiveContains("not logged") {
                throw GitHubCLIError.unauthorized
            }
            let missingPR = result.stderr.localizedCaseInsensitiveContains("no pull requests found")
                || result.stderr.localizedCaseInsensitiveContains("could not find pull request")
            if missingPR {
                return nil
            }
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to load pull request status."))
        }
        let data = Data(result.stdout.utf8)
        return try JSONDecoder().decode(GitHubPullRequestSummary.self, from: data)
    }

    private func pullRequestChecks(repositoryRoot: String, number: Int) async throws -> GitHubPullRequestChecksSummary {
        let result = try await runGh(
            arguments: ["pr", "checks", String(number), "--json", "bucket,description,link,name,state,workflow"],
            currentDirectory: repositoryRoot
        )
        guard result.exitCode == 0 || result.exitCode == 8 else {
            if result.stderr.localizedCaseInsensitiveContains("not logged") {
                throw GitHubCLIError.unauthorized
            }
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to load pull request checks."))
        }

        let data = Data(result.stdout.utf8)
        let checks = try JSONDecoder().decode([GitHubPullRequestCheck].self, from: data)
        return GitHubPullRequestChecksSummary(
            passingCount: checks.filter { $0.bucket == "pass" }.count,
            failingCount: checks.filter(\.isFailing).count,
            pendingCount: checks.filter(\.isPending).count,
            skippedCount: checks.filter { $0.bucket == "skipping" }.count,
            failingChecks: checks.filter(\.isFailing)
        )
    }

    private func latestRun(repositoryRoot: String, branch: String) async throws -> GitHubWorkflowRunSummary? {
        guard !branch.isEmpty, branch != "HEAD" else { return nil }
        let result = try await runGh(
            arguments: ["run", "list", "--branch", branch, "--limit", "1", "--json", "databaseId,workflowName,displayTitle,status,conclusion,url"],
            currentDirectory: repositoryRoot
        )
        guard result.exitCode == 0 else {
            if result.stderr.localizedCaseInsensitiveContains("not logged") {
                throw GitHubCLIError.unauthorized
            }
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to load workflow runs."))
        }
        let data = Data(result.stdout.utf8)
        let items = try JSONDecoder().decode([GitHubWorkflowRunResponse].self, from: data)
        guard let first = items.first else { return nil }
        return GitHubWorkflowRunSummary(
            id: first.databaseId,
            name: first.workflowName,
            title: first.displayTitle,
            status: first.status,
            conclusion: first.conclusion,
            url: first.url
        )
    }

    private func pullRequestReleaseNoteDetails(repositoryRoot: String, number: Int) async throws -> GitHubReleaseNoteDraftResponse {
        let result = try await runGh(
            arguments: [
                "pr", "view", String(number),
                "--json", "number,title,body,url,headRefName,baseRefName,reviewDecision,mergeStateStatus,reviewRequests,latestReviews,assignees,commits"
            ],
            currentDirectory: repositoryRoot
        )
        guard result.exitCode == 0 else {
            throw GitHubCLIError.commandFailed(result.stderr.nonEmptyOrFallback("Unable to draft release notes from the pull request."))
        }
        let data = Data(result.stdout.utf8)
        return try JSONDecoder().decode(GitHubReleaseNoteDraftResponse.self, from: data)
    }

    private func runGh(arguments: [String], currentDirectory: String? = nil) async throws -> ShellCommandResult {
        guard await isAvailable() else {
            throw GitHubCLIError.unavailable
        }
        return try await runner.run(
            executable: "/usr/bin/env",
            arguments: ["gh"] + arguments,
            currentDirectory: currentDirectory,
            environment: ["LC_ALL": "en_US.UTF-8"]
        )
    }

    nonisolated private static func renderReleaseNoteDraft(
        details: GitHubReleaseNoteDraftResponse,
        commitLimit: Int
    ) -> String {
        let summaryLines = details.body?
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let commitLines = details.commits
            .map(\.messageHeadline)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let limitedCommits = Array(commitLines.prefix(commitLimit))
        let requestedReviewers = details.reviewRequests.map(\.login)
        let assignees = details.assignees.map(\.login)
        let changesRequestedBy = Array(
            Set(
                details.latestReviews.compactMap { review in
                    review.normalizedState == "CHANGES_REQUESTED" ? review.author?.login : nil
                }
            )
        ).sorted()
        let approvedBy = Array(
            Set(
                details.latestReviews.compactMap { review in
                    review.normalizedState == "APPROVED" ? review.author?.login : nil
                }
            )
        ).sorted()

        var lines: [String] = [
            "Release Draft Context",
            "",
            "PR #\(details.number): \(details.title)",
            "Branch: \(details.headRefName) -> \(details.baseRefName)",
            "URL: \(details.url)",
            ""
        ]

        let mergeState = details.mergeStateStatus?.uppercased().nilIfEmpty ?? "UNKNOWN"
        let reviewDecision = details.reviewDecision?.uppercased().nilIfEmpty ?? "UNKNOWN"
        lines.append("Merge")
        lines.append("- State: \(mergeState)")
        lines.append("- Review: \(reviewDecision)")
        if !requestedReviewers.isEmpty {
            lines.append("- Requested reviewers: \(requestedReviewers.joined(separator: ", "))")
        }
        if !changesRequestedBy.isEmpty {
            lines.append("- Changes requested by: \(changesRequestedBy.joined(separator: ", "))")
        }
        if !approvedBy.isEmpty {
            lines.append("- Approved by: \(approvedBy.joined(separator: ", "))")
        }
        if !assignees.isEmpty {
            lines.append("- Assignees: \(assignees.joined(separator: ", "))")
        }
        lines.append("")

        if !summaryLines.isEmpty {
            lines.append("Summary")
            lines.append(contentsOf: summaryLines.map { "- \($0)" })
            lines.append("")
        }

        lines.append("Commit Headlines")
        if limitedCommits.isEmpty {
            lines.append("- No commit summaries found.")
        } else {
            lines.append(contentsOf: limitedCommits.map { "- \($0)" })
        }

        if commitLines.count > limitedCommits.count {
            lines.append("- ...and \(commitLines.count - limitedCommits.count) more commit(s)")
        }

        return lines.joined(separator: "\n")
    }
}

private struct GitHubAuthStatusResponse: Sendable {
    let hosts: [String: [GitHubAuthAccount]]
}

private struct GitHubAuthAccount: Sendable {
    let active: Bool
    let login: String
}

private struct GitHubWorkflowRunResponse: Sendable {
    let databaseId: Int
    let workflowName: String
    let displayTitle: String
    let status: String
    let conclusion: String?
    let url: String?
}

private struct GitHubReleaseNoteDraftResponse: Sendable {
    let number: Int
    let title: String
    let body: String?
    let url: String
    let headRefName: String
    let baseRefName: String
    let reviewDecision: String?
    let mergeStateStatus: String?
    let reviewRequests: [GitHubPullRequestActor]
    let latestReviews: [GitHubPullRequestReviewSummary]
    let assignees: [GitHubPullRequestActor]
    let commits: [GitHubReleaseNoteCommit]
}

private struct GitHubReleaseNoteCommit: Sendable {
    let messageHeadline: String
}

private struct GitHubReleaseListEntry: Sendable {
    let tagName: String
    let name: String
    let isDraft: Bool
    let isPrerelease: Bool
    let publishedAt: String
}

extension GitHubAuthStatusResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case hosts
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hosts = try container.decode([String: [GitHubAuthAccount]].self, forKey: .hosts)
    }
}

extension GitHubAuthAccount: Decodable {
    private enum CodingKeys: String, CodingKey {
        case active
        case login
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        active = try container.decode(Bool.self, forKey: .active)
        login = try container.decode(String.self, forKey: .login)
    }
}

extension GitHubWorkflowRunResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case databaseId
        case workflowName
        case displayTitle
        case status
        case conclusion
        case url
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        databaseId = try container.decode(Int.self, forKey: .databaseId)
        workflowName = try container.decode(String.self, forKey: .workflowName)
        displayTitle = try container.decode(String.self, forKey: .displayTitle)
        status = try container.decode(String.self, forKey: .status)
        conclusion = try container.decodeIfPresent(String.self, forKey: .conclusion)
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }
}

extension GitHubReleaseNoteDraftResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case number
        case title
        case body
        case url
        case headRefName
        case baseRefName
        case reviewDecision
        case mergeStateStatus
        case reviewRequests
        case latestReviews
        case assignees
        case commits
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        url = try container.decode(String.self, forKey: .url)
        headRefName = try container.decode(String.self, forKey: .headRefName)
        baseRefName = try container.decode(String.self, forKey: .baseRefName)
        reviewDecision = try container.decodeIfPresent(String.self, forKey: .reviewDecision)
        mergeStateStatus = try container.decodeIfPresent(String.self, forKey: .mergeStateStatus)
        reviewRequests = try container.decodeIfPresent([GitHubPullRequestActor].self, forKey: .reviewRequests) ?? []
        latestReviews = try container.decodeIfPresent([GitHubPullRequestReviewSummary].self, forKey: .latestReviews) ?? []
        assignees = try container.decodeIfPresent([GitHubPullRequestActor].self, forKey: .assignees) ?? []
        commits = try container.decode([GitHubReleaseNoteCommit].self, forKey: .commits)
    }
}

extension GitHubReleaseNoteCommit: Decodable {
    private enum CodingKeys: String, CodingKey {
        case messageHeadline
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageHeadline = try container.decode(String.self, forKey: .messageHeadline)
    }
}

extension GitHubReleaseListEntry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case tagName
        case name
        case isDraft
        case isPrerelease
        case publishedAt
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        name = try container.decode(String.self, forKey: .name)
        isDraft = try container.decode(Bool.self, forKey: .isDraft)
        isPrerelease = try container.decode(Bool.self, forKey: .isPrerelease)
        publishedAt = try container.decode(String.self, forKey: .publishedAt)
    }
}
