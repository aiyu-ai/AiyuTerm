//
//  AgentHookProtocolTests.swift
//  AiyuTermTests
//
//  Phase 1 of the CodeIsland integration: covers the vendored
//  HookProtocol types (AgentHookSocketPath, AgentHookEventNormalizer,
//  AgentHookEvent, AgentSessionSnapshot, reduceAgentHookEvent).
//

import XCTest
@testable import AiyuTerm

// MARK: - AgentHookSocketPath

final class AgentHookSocketPathTests: XCTestCase {
    override func setUp() {
        super.setUp()
        unsetenv(AgentHookSocketPath.environmentOverrideKey)
    }

    override func tearDown() {
        unsetenv(AgentHookSocketPath.environmentOverrideKey)
        super.tearDown()
    }

    func testDefaultPathLivesUnderHome() {
        let path = AgentHookSocketPath.path
        // Debug builds live under ~/.aiyuterm-debug/ and release builds
        // under ~/.aiyuterm/; both may also fall back to /tmp if the
        // home path is too long.
        let acceptableSuffixes = [
            "/.aiyuterm/hook.sock",
            "/.aiyuterm-debug/hook.sock",
        ]
        let acceptablePrefixes = [
            "/tmp/aiyuterm-hook-",
            "/tmp/aiyuterm-hook-debug-",
        ]
        let matchesSuffix = acceptableSuffixes.contains(where: path.hasSuffix)
        let matchesPrefix = acceptablePrefixes.contains(where: path.hasPrefix)
        XCTAssertTrue(
            matchesSuffix || matchesPrefix,
            "Default path should be under ~/.aiyuterm[-debug] or /tmp[-debug] fallback, got: \(path)"
        )
    }

    func testStateDirectoryNameUsesDebugSuffixInDebugBuilds() {
        #if DEBUG
        XCTAssertEqual(AgentHookSocketPath.stateDirectoryName, ".aiyuterm-debug")
        #else
        XCTAssertEqual(AgentHookSocketPath.stateDirectoryName, ".aiyuterm")
        #endif
    }

    func testEnvironmentOverrideWins() {
        setenv(AgentHookSocketPath.environmentOverrideKey, "/tmp/custom-hook.sock", 1)
        XCTAssertEqual(AgentHookSocketPath.path, "/tmp/custom-hook.sock")
    }

    func testEmptyEnvironmentOverrideFallsBackToDefault() {
        setenv(AgentHookSocketPath.environmentOverrideKey, "", 1)
        let path = AgentHookSocketPath.path
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.hasSuffix("hook.sock"))
    }

    func testResolvedPathFitsSunPathLimit() {
        XCTAssertTrue(AgentHookSocketPath.resolvedPathFitsSunPath)
    }
}

// MARK: - AgentHookEventNormalizer

final class AgentHookEventNormalizerTests: XCTestCase {
    func testCursorMappings() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("beforeSubmitPrompt"), "UserPromptSubmit")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("beforeShellExecution"), "PreToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("afterShellExecution"), "PostToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("beforeReadFile"), "PreToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("afterFileEdit"), "PostToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("beforeMCPExecution"), "PreToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("afterMCPExecution"), "PostToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("afterAgentThought"), "Notification")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("afterAgentResponse"), "AfterAgentResponse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("stop"), "Stop")
    }

    func testGeminiMappings() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("BeforeTool"), "PreToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("AfterTool"), "PostToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("BeforeAgent"), "SubagentStart")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("AfterAgent"), "SubagentStop")
    }

    func testCopilotMappings() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("sessionStart"), "SessionStart")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("sessionEnd"), "SessionEnd")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("userPromptSubmitted"), "UserPromptSubmit")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("preToolUse"), "PreToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("postToolUse"), "PostToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("errorOccurred"), "Notification")
    }

    func testUnknownEventPassesThroughUnchanged() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("Stop"), "Stop")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("UserPromptSubmit"), "UserPromptSubmit")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("CompletelyUnknown"), "CompletelyUnknown")
    }
}

// MARK: - AgentHookEvent

final class AgentHookEventDecodingTests: XCTestCase {
    func testDecodesValidUserPromptSubmit() {
        let json = """
        {"hook_event_name":"UserPromptSubmit","session_id":"abc","cwd":"/tmp/repo","prompt":"hi"}
        """
        let data = json.data(using: .utf8)!
        let event = AgentHookEvent(from: data)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.eventName, "UserPromptSubmit")
        XCTAssertEqual(event?.sessionId, "abc")
        XCTAssertEqual(event?.rawJSON["cwd"] as? String, "/tmp/repo")
        XCTAssertEqual(event?.rawJSON["prompt"] as? String, "hi")
    }

    func testDecodesPreToolUseWithToolInput() {
        let json = """
        {"hook_event_name":"PreToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"ls -la","description":"List files"}}
        """
        let event = AgentHookEvent(from: json.data(using: .utf8)!)
        XCTAssertEqual(event?.toolName, "Bash")
        XCTAssertEqual(event?.toolDescription, "List files")
    }

    func testBashToolDescriptionPrefersDescription() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Bash",
            toolInput: ["command": "rm -rf /tmp/foo", "description": "Clean up foo"]
        )
        XCTAssertEqual(event.toolDescription, "Clean up foo")
    }

    func testBashToolDescriptionFallsBackToCommandFirstLine() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Bash",
            toolInput: ["command": "echo hello\necho world"]
        )
        XCTAssertEqual(event.toolDescription, "echo hello")
    }

    func testReadToolDescriptionIncludesOffset() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Read",
            toolInput: ["file_path": "/src/module/foo.swift", "offset": 42]
        )
        XCTAssertEqual(event.toolDescription, "foo.swift:42")
    }

    func testWebFetchExtractsHost() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "WebFetch",
            toolInput: ["url": "https://example.com/path/to/page"]
        )
        XCTAssertEqual(event.toolDescription, "example.com")
    }

    func testTodoWriteHasStaticDescription() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "TodoWrite",
            toolInput: [:]
        )
        XCTAssertEqual(event.toolDescription, "Updating tasks")
    }

    func testEditToolDescriptionShowsLastPathComponent() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Edit",
            toolInput: ["file_path": "/src/App/module/view.swift"]
        )
        XCTAssertEqual(event.toolDescription, "view.swift")
    }

    func testWriteToolDescriptionShowsLastPathComponent() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Write",
            toolInput: ["file_path": "/src/App/Helpers/helpers.swift"]
        )
        XCTAssertEqual(event.toolDescription, "helpers.swift")
    }

    func testGrepToolDescriptionIncludesSearchScope() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Grep",
            toolInput: ["pattern": "TODO", "path": "/src/App"]
        )
        XCTAssertEqual(event.toolDescription, "TODO in App")
    }

    func testGrepToolDescriptionWithoutPathOmitsScope() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Grep",
            toolInput: ["pattern": "FIXME"]
        )
        XCTAssertEqual(event.toolDescription, "FIXME")
    }

    func testGlobToolDescriptionReturnsPattern() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Glob",
            toolInput: ["pattern": "**/*.swift"]
        )
        XCTAssertEqual(event.toolDescription, "**/*.swift")
    }

    func testWebSearchToolDescriptionReturnsQuery() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "WebSearch",
            toolInput: ["query": "swift actor isolation"]
        )
        XCTAssertEqual(event.toolDescription, "swift actor isolation")
    }

    func testTaskToolDescriptionPrefersDescription() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Task",
            toolInput: ["description": "Code reviewer", "prompt": "Review the PR..."]
        )
        XCTAssertEqual(event.toolDescription, "Code reviewer")
    }

    func testTaskToolDescriptionFallsBackToPromptPrefix() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "Task",
            toolInput: ["prompt": "This is an extremely long prompt that keeps going"]
        )
        // The Models.swift implementation takes the first 40 chars of prompt.
        XCTAssertEqual(event.toolDescription, "This is an extremely long prompt that ke")
    }

    func testUnknownToolFallsBackToFilePath() {
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s",
            toolName: "SomeCustomTool",
            toolInput: ["file_path": "/tmp/foo/bar.txt"]
        )
        XCTAssertEqual(event.toolDescription, "bar.txt")
    }

    func testUnknownToolFallsBackToTopLevelMessage() {
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "s",
            rawJSON: ["message": "Something happened"]
        )
        XCTAssertEqual(event.toolDescription, "Something happened")
    }

    func testFailsWhenHookEventNameMissing() {
        let json = "{\"session_id\":\"abc\"}"
        XCTAssertNil(AgentHookEvent(from: json.data(using: .utf8)!))
    }

    func testFailsOnInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        XCTAssertNil(AgentHookEvent(from: data))
    }
}

// MARK: - AgentQuestionPayload

final class AgentQuestionPayloadTests: XCTestCase {
    func testBuildsFromNotificationWithExplicitQuestionField() {
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "s",
            rawJSON: ["question": "Proceed?", "options": ["yes", "no"]]
        )
        let payload = AgentQuestionPayload.from(event: event)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.question, "Proceed?")
        XCTAssertEqual(payload?.options, ["yes", "no"])
    }

    func testReturnsNilForNotificationWithoutQuestionField() {
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "s",
            rawJSON: ["message": "Task running..."]
        )
        XCTAssertNil(AgentQuestionPayload.from(event: event))
    }

    func testDoesNotUseQuestionMarkHeuristic() {
        // Intentional behaviour: plain status text ending in "?" should
        // not be misclassified as a blocking question.
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "s",
            rawJSON: ["message": "Should I update tests?"]
        )
        XCTAssertNil(AgentQuestionPayload.from(event: event))
    }
}

// MARK: - AgentSessionSnapshot / reducer

final class AgentSessionSnapshotReducerTests: XCTestCase {
    func testUserPromptSubmitTransitionsToProcessing() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        let event = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": "/tmp/repo", "prompt": "Hello"]
        )
        _ = reduceAgentHookEvent(sessions: &sessions, event: event, maxHistory: 10)
        XCTAssertEqual(sessions["s1"]?.status, .processing)
        XCTAssertEqual(sessions["s1"]?.cwd, "/tmp/repo")
        XCTAssertEqual(sessions["s1"]?.lastUserPrompt, "Hello")
    }

    func testPreToolUseSetsRunningAndRecordsTool() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "UserPromptSubmit", sessionId: "s1", rawJSON: ["prompt": "run"]),
            maxHistory: 10
        )
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "PreToolUse",
                sessionId: "s1",
                toolName: "Bash",
                toolInput: ["command": "ls", "description": "List files"]
            ),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .running)
        XCTAssertEqual(sessions["s1"]?.currentTool, "Bash")
        XCTAssertEqual(sessions["s1"]?.toolDescription, "List files")
    }

    func testPostToolUseAppendsHistoryEntry() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "PreToolUse",
                sessionId: "s1",
                toolName: "Bash",
                toolInput: ["command": "echo hi"]
            ),
            maxHistory: 10
        )
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "PostToolUse", sessionId: "s1"),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.toolHistory.count, 1)
        XCTAssertEqual(sessions["s1"]?.toolHistory.first?.tool, "Bash")
        XCTAssertTrue(sessions["s1"]?.toolHistory.first?.success ?? false)
        XCTAssertEqual(sessions["s1"]?.status, .processing)
    }

    func testStopTransitionsToIdleAndEnqueuesCompletion() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var snap = AgentSessionSnapshot()
            snap.status = .processing
            return snap
        }()
        let effects = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "Stop",
                sessionId: "s1",
                rawJSON: ["last_assistant_message": "Done"]
            ),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .idle)
        XCTAssertEqual(sessions["s1"]?.lastAssistantMessage, "Done")
        XCTAssertTrue(effects.contains(.enqueueCompletion(sessionId: "s1")))
    }

    func testNotificationWithQuestionTransitionsToWaitingQuestion() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "s1",
            rawJSON: ["question": "Continue?", "options": ["yes", "no"]]
        )
        _ = reduceAgentHookEvent(sessions: &sessions, event: event, maxHistory: 10)
        XCTAssertEqual(sessions["s1"]?.status, .waitingQuestion)
    }

    func testWaitingStatePreservedAcrossActivityUpdates() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var snap = AgentSessionSnapshot()
            snap.status = .waitingApproval
            return snap
        }()
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "PreToolUse",
                sessionId: "s1",
                toolName: "Bash",
                toolInput: ["command": "rm -rf /tmp/foo"]
            ),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .waitingApproval,
                       "Pre-existing waitingApproval state must not be overwritten by activity updates")
    }

    func testSessionStartResetsSnapshot() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var snap = AgentSessionSnapshot()
            snap.status = .running
            snap.lastUserPrompt = "old"
            return snap
        }()
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "SessionStart",
                sessionId: "s1",
                rawJSON: ["cwd": "/tmp/new", "model": "claude-opus-4-6"]
            ),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.cwd, "/tmp/new")
        XCTAssertEqual(sessions["s1"]?.model, "claude-opus-4-6")
        XCTAssertNil(sessions["s1"]?.lastUserPrompt, "SessionStart should reset the snapshot")
    }

    func testSessionEndEmitsRemoveEffect() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = AgentSessionSnapshot()
        let effects = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "SessionEnd", sessionId: "s1"),
            maxHistory: 10
        )
        XCTAssertTrue(effects.contains(.removeSession(sessionId: "s1")))
    }

    func testSubagentPreToolUseKeepsParentRunning() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "SubagentStart",
                sessionId: "s1",
                agentId: "agent-1",
                rawJSON: ["agent_type": "code-reviewer"]
            ),
            maxHistory: 10
        )
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "PreToolUse",
                sessionId: "s1",
                toolName: "Read",
                agentId: "agent-1",
                toolInput: ["file_path": "/src/foo.swift"]
            ),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .running)
        XCTAssertEqual(sessions["s1"]?.subagents["agent-1"]?.currentTool, "Read")
    }

    func testPostToolUseFailureRecordsFailedEntry() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "PreToolUse",
                sessionId: "s1",
                toolName: "Bash",
                toolInput: ["command": "rm -rf /tmp/broken"]
            ),
            maxHistory: 10
        )
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "PostToolUseFailure", sessionId: "s1"),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.toolHistory.count, 1)
        XCTAssertEqual(sessions["s1"]?.toolHistory.first?.tool, "Bash")
        XCTAssertFalse(sessions["s1"]?.toolHistory.first?.success ?? true,
                       "PostToolUseFailure must record success=false")
        XCTAssertEqual(sessions["s1"]?.status, .processing)
    }

    func testPermissionDeniedTransitionsToProcessing() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var snap = AgentSessionSnapshot()
            snap.status = .running
            snap.currentTool = "Bash"
            snap.toolDescription = "rm -rf foo"
            return snap
        }()
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "PermissionDenied", sessionId: "s1"),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .processing)
        XCTAssertNil(sessions["s1"]?.currentTool)
        XCTAssertNil(sessions["s1"]?.toolDescription)
    }

    func testPermissionDeniedDoesNotOverwriteWaitingState() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var snap = AgentSessionSnapshot()
            snap.status = .waitingApproval
            return snap
        }()
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "PermissionDenied", sessionId: "s1"),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .waitingApproval)
    }

    func testSubagentStopWithoutAgentIdRevertsParentToProcessing() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var snap = AgentSessionSnapshot()
            snap.status = .running
            snap.currentTool = "Agent"
            snap.toolDescription = "code-reviewer"
            return snap
        }()
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "SubagentStop", sessionId: "s1"),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .processing)
        XCTAssertNil(sessions["s1"]?.currentTool)
    }

    func testAfterAgentResponseCapturesAssistantMessage() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(
                eventName: "AfterAgentResponse",
                sessionId: "s1",
                rawJSON: ["text": "Here is the result of my analysis."]
            ),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.lastAssistantMessage, "Here is the result of my analysis.")
        XCTAssertEqual(sessions["s1"]?.recentMessages.last?.isUser, false)
        XCTAssertEqual(sessions["s1"]?.recentMessages.last?.text, "Here is the result of my analysis.")
        XCTAssertEqual(sessions["s1"]?.status, .processing)
    }

    func testPreCompactTransitionsToProcessingWithStatusDescription() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        _ = reduceAgentHookEvent(
            sessions: &sessions,
            event: AgentHookEvent(eventName: "PreCompact", sessionId: "s1"),
            maxHistory: 10
        )
        XCTAssertEqual(sessions["s1"]?.status, .processing)
        XCTAssertEqual(sessions["s1"]?.toolDescription, "Compacting context\u{2026}")
    }

    func testToolHistoryRespectsMaxSize() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        for i in 0 ..< 5 {
            _ = reduceAgentHookEvent(
                sessions: &sessions,
                event: AgentHookEvent(
                    eventName: "PreToolUse",
                    sessionId: "s1",
                    toolName: "Bash",
                    toolInput: ["command": "echo \(i)"]
                ),
                maxHistory: 3
            )
            _ = reduceAgentHookEvent(
                sessions: &sessions,
                event: AgentHookEvent(eventName: "PostToolUse", sessionId: "s1"),
                maxHistory: 3
            )
        }
        XCTAssertEqual(sessions["s1"]?.toolHistory.count, 3)
    }
}

// MARK: - AgentSessionSnapshot derived state

final class AgentSessionSnapshotDerivedStateTests: XCTestCase {
    func testShortModelNameForOpus() {
        var snap = AgentSessionSnapshot()
        snap.model = "claude-opus-4-6"
        XCTAssertEqual(snap.shortModelName, "opus")
    }

    func testShortModelNameForSonnet() {
        var snap = AgentSessionSnapshot()
        snap.model = "claude-sonnet-4-5"
        XCTAssertEqual(snap.shortModelName, "sonnet")
    }

    func testSourceLabelMappings() {
        var snap = AgentSessionSnapshot()
        snap.source = "droid"
        XCTAssertEqual(snap.sourceLabel, "Factory")
        snap.source = "codebuddy"
        XCTAssertEqual(snap.sourceLabel, "CodeBuddy")
        // Unknown sources pass through `String.capitalized`, which
        // uppercases the first letter of every whitespace-delimited
        // token. For a single-token source, that collapses to the
        // simple "first letter capitalized" behaviour.
        snap.source = "custom"
        XCTAssertEqual(snap.sourceLabel, "Custom")
    }

    func testDisplayNameStripsNumericSuffix() {
        var snap = AgentSessionSnapshot()
        snap.cwd = "/workspaces/myproject/20260406010126"
        XCTAssertEqual(snap.displayName, "myproject")
    }

    func testTerminalNameRecognizesAiyuTerm() {
        var snap = AgentSessionSnapshot()
        snap.termBundleId = "com.aiyuai.aiyuterm"
        XCTAssertEqual(snap.terminalName, "AiyuTerm")
    }

    func testTerminalNameRecognizesGhostty() {
        var snap = AgentSessionSnapshot()
        snap.termBundleId = "com.mitchellh.ghostty"
        XCTAssertEqual(snap.terminalName, "Ghostty")
    }

    func testNormalizedSupportedSourceAccepts() {
        XCTAssertEqual(AgentSessionSnapshot.normalizedSupportedSource("Claude"), "claude")
        XCTAssertEqual(AgentSessionSnapshot.normalizedSupportedSource("  codex  "), "codex")
        XCTAssertNil(AgentSessionSnapshot.normalizedSupportedSource("unknown"))
        XCTAssertNil(AgentSessionSnapshot.normalizedSupportedSource(nil))
    }
}

// MARK: - deriveAgentSessionSummary

final class AgentSessionSummaryTests: XCTestCase {
    func testWaitingApprovalHasHighestPriority() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var s = AgentSessionSnapshot()
            s.status = .running
            s.source = "codex"
            return s
        }()
        sessions["s2"] = {
            var s = AgentSessionSnapshot()
            s.status = .waitingApproval
            s.source = "claude"
            return s
        }()
        let summary = deriveAgentSessionSummary(from: sessions)
        XCTAssertEqual(summary.status, .waitingApproval)
        XCTAssertEqual(summary.primarySource, "claude")
        XCTAssertEqual(summary.activeSessionCount, 2)
    }

    func testIdleFallsBackToMostRecentSource() {
        let now = Date()
        var sessions: [String: AgentSessionSnapshot] = [:]
        sessions["s1"] = {
            var s = AgentSessionSnapshot()
            s.status = .idle
            s.source = "claude"
            s.lastActivity = now.addingTimeInterval(-60)
            return s
        }()
        sessions["s2"] = {
            var s = AgentSessionSnapshot()
            s.status = .idle
            s.source = "gemini"
            s.lastActivity = now
            return s
        }()
        let summary = deriveAgentSessionSummary(from: sessions)
        XCTAssertEqual(summary.status, .idle)
        XCTAssertEqual(summary.primarySource, "gemini")
    }
}
