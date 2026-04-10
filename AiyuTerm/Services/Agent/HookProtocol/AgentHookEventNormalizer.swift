//
// AgentHookEventNormalizer.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIslandCore/EventNormalizer.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Maps vendor-specific hook event names (Cursor camelCase, Gemini
// PascalCase, GitHub Copilot lowerCamel, etc.) to a single canonical
// PascalCase set that the rest of AiyuTerm's agent pipeline understands.
//
// The canonical set is anchored on Claude Code's event names, because
// that is the most feature-complete hook surface.
//

import Foundation

enum AgentHookEventNormalizer {
    /// Normalize an inbound event name to AiyuTerm's canonical form.
    /// Unknown names pass through unchanged so that new events can be added
    /// at the source-CLI level without requiring a client update.
    static func normalize(_ name: String) -> String {
        switch name {
        // Cursor (camelCase)
        case "beforeSubmitPrompt":    return "UserPromptSubmit"
        case "beforeShellExecution":  return "PreToolUse"
        case "afterShellExecution":   return "PostToolUse"
        case "beforeReadFile":        return "PreToolUse"
        case "afterFileEdit":         return "PostToolUse"
        case "beforeMCPExecution":    return "PreToolUse"
        case "afterMCPExecution":     return "PostToolUse"
        case "afterAgentThought":     return "Notification"
        case "afterAgentResponse":    return "AfterAgentResponse"
        case "stop":                  return "Stop"
        // Gemini (PascalCase-ish)
        case "BeforeTool":            return "PreToolUse"
        case "AfterTool":             return "PostToolUse"
        case "BeforeAgent":           return "SubagentStart"
        case "AfterAgent":            return "SubagentStop"
        // GitHub Copilot CLI (lowerCamelCase)
        case "sessionStart":          return "SessionStart"
        case "sessionEnd":            return "SessionEnd"
        case "userPromptSubmitted":   return "UserPromptSubmit"
        case "preToolUse":            return "PreToolUse"
        case "postToolUse":           return "PostToolUse"
        case "errorOccurred":         return "Notification"
        default:                      return name
        }
    }
}
