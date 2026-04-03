//
//  AiyuTermGhosttyInputSupportTests.swift
//  AiyuTermTests
//
//  Author: everettjf
//

import AppKit
import Carbon
import GhosttyKit
import XCTest
@testable import AiyuTerm

final class AiyuTermGhosttyInputSupportTests: XCTestCase {
    private let returnKeyCode = UInt16(kVK_Return)
    private let keypadEnterKeyCode = UInt16(kVK_ANSI_KeypadEnter)

    func testShiftReturnUsesTextInputRouting() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: returnKeyCode,
                modifierFlags: [.shift]
            )
        )
    }

    func testCommandReturnStillUsesRawKeyRouting() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: returnKeyCode,
                modifierFlags: [.command]
            )
        )
    }

    func testOptionKeypadEnterStillUsesRawKeyRouting() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: keypadEnterKeyCode,
                modifierFlags: [.option]
            )
        )
    }

    func testOptionLeftArrowUsesRawKeyRouting() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option]
            )
        )
    }

    func testOptionDeleteUsesRawKeyRouting() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_Delete),
                modifierFlags: [.option]
            )
        )
    }

    func testOptionPrintableKeyStillUsesTextInputRouting() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_ANSI_B),
                modifierFlags: [.option]
            )
        )
    }

    func testSSHOptionLeftArrowUsesBackwardWordEscapeSequence() {
        XCTAssertEqual(
            aiyuTermGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}b"
        )
    }

    func testSSHOptionRightArrowUsesForwardWordEscapeSequence() {
        XCTAssertEqual(
            aiyuTermGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_RightArrow),
                modifierFlags: [.option],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}f"
        )
    }

    func testLocalOptionArrowDoesNotUseSSHWordNavigationEscapeSequence() {
        XCTAssertNil(
            aiyuTermGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option],
                backendConfiguration: .local()
            )
        )
    }

    func testSSHCommandOptionArrowDoesNotUseSSHWordNavigationEscapeSequence() {
        XCTAssertNil(
            aiyuTermGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.command, .option],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            )
        )
    }

    func testSSHOptionArrowAllowsAdditionalSystemModifierBits() {
        XCTAssertEqual(
            aiyuTermGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option, .numericPad],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}b"
        )
    }

    func testSSHLeftOptionArrowUsesBackwardWordEscapeSequenceWithRawAltBit() {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICELALTKEYMASK))

        XCTAssertEqual(
            aiyuTermGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: flags,
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}b"
        )
    }

    func testSSHRightOptionArrowUsesForwardWordEscapeSequenceWithRawAltBit() {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICERALTKEYMASK))

        XCTAssertEqual(
            aiyuTermGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_RightArrow),
                modifierFlags: flags,
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}f"
        )
    }

    func testPlainReturnDoesNotUseRawKeyRouting() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: returnKeyCode,
                modifierFlags: []
            )
        )
    }

    func testNonReturnKeyNeverUsesRawKeyRouting() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_ANSI_A),
                modifierFlags: [.command]
            )
        )
    }

    func testRawKeyDispatchStaysComposingWhileMarkedTextIsActive() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldMarkRawKeyEventAsComposing(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: true
            )
        )
    }

    func testRawKeyDispatchStaysComposingWhenMarkedTextWasJustCleared() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldMarkRawKeyEventAsComposing(
                hadMarkedTextBeforeInterpretation: true,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testRawKeyDispatchIsPlainOutsideComposition() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldMarkRawKeyEventAsComposing(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testImeMarkedTextUpdateSkipsRawFallback() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldDispatchRawKeyFallbackAfterTextInterpretation(
                accumulatedText: "",
                handledTextInputCommand: false,
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: true
            )
        )
    }

    func testImeMarkedTextClearSkipsRawFallback() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldDispatchRawKeyFallbackAfterTextInterpretation(
                accumulatedText: "",
                handledTextInputCommand: false,
                hadMarkedTextBeforeInterpretation: true,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testImeMarkedTextUpdateSyncsPreedit() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldSyncPreeditAfterTextInterpretation(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: true
            )
        )
    }

    func testImeMarkedTextClearSyncsPreedit() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldSyncPreeditAfterTextInterpretation(
                hadMarkedTextBeforeInterpretation: true,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testPlainUnhandledKeyDoesNotSyncPreedit() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldSyncPreeditAfterTextInterpretation(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testPlainUnhandledKeyStillUsesRawFallback() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldDispatchRawKeyFallbackAfterTextInterpretation(
                accumulatedText: "",
                handledTextInputCommand: false,
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testDeleteEventKeepsInsertedAsciiAsMarkedTextWhileComposing() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "n",
                keyCode: UInt16(kVK_Delete),
                hadMarkedTextBeforeDeletion: true
            )
        )
    }

    func testDeleteEventKeepsInsertedCjkTextAsMarkedTextWhileComposing() {
        XCTAssertTrue(
            AiyuTermGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "你",
                keyCode: UInt16(kVK_Delete),
                hadMarkedTextBeforeDeletion: true
            )
        )
    }

    func testDeleteEventWithoutMarkedTextDoesNotCreateMarkedText() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "n",
                keyCode: UInt16(kVK_Delete),
                hadMarkedTextBeforeDeletion: false
            )
        )
    }

    func testNonDeleteEventStillCommitsInsertedText() {
        XCTAssertFalse(
            AiyuTermGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "n",
                keyCode: UInt16(kVK_ANSI_N),
                hadMarkedTextBeforeDeletion: true
            )
        )
    }

    func testDeleteBackwardByDecomposingSelectorDeletesMarkedText() {
        XCTAssertEqual(
            AiyuTermGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.deleteBackwardByDecomposingPreviousCharacter(_:)),
                hasMarkedText: true
            ),
            .deleteBackwardInMarkedText
        )
    }

    func testCancelOperationClearsMarkedText() {
        XCTAssertEqual(
            AiyuTermGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.cancelOperation(_:)),
                hasMarkedText: true
            ),
            .cancelMarkedText
        )
    }

    func testCancelOperationWithoutMarkedTextFallsThrough() {
        XCTAssertEqual(
            AiyuTermGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.cancelOperation(_:)),
                hasMarkedText: false
            ),
            .none
        )
    }

    func testMoveWordLeftSelectorResolvesToBackwardWordCommand() {
        XCTAssertEqual(
            AiyuTermGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.moveWordLeft(_:)),
                hasMarkedText: false
            ),
            .moveBackwardWord
        )
    }

    func testMoveWordRightSelectorResolvesToForwardWordCommand() {
        XCTAssertEqual(
            AiyuTermGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.moveWordRight(_:)),
                hasMarkedText: false
            ),
            .moveForwardWord
        )
    }

    func testImeDebugLoggingCanBeEnabledByEnvironment() {
        XCTAssertTrue(
            aiyuTermGhosttyShouldEnableIMEDebugLogging(environment: ["LINEY_DEBUG_IME": "1"])
        )
    }

    func testImeDebugLoggingDefaultsToEnabled() {
        XCTAssertTrue(aiyuTermGhosttyShouldEnableIMEDebugLogging(environment: [:]))
    }

    func testReturnIsNotSentAsLiteralText() {
        XCTAssertFalse(shouldSendGhosttyText("\r"))
        XCTAssertFalse(shouldSendGhosttyText("\n"))
    }

    func testPrintableTextIsStillSent() {
        XCTAssertTrue(shouldSendGhosttyText("a"))
        XCTAssertTrue(shouldSendGhosttyText("你"))
    }

    func testCtrlLetterDoesNotAttachPrintableTextToGhosttyKeyEvent() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{19}",
            charactersIgnoringModifiers: "y",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_Y)
        )

        XCTAssertNotNil(event)
        XCTAssertNil(textForGhosttyKeyEvent(event!))
    }

    func testCtrlReturnDoesNotAttachTextToGhosttyKeyEvent() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: UInt16(kVK_Return)
        )

        XCTAssertNotNil(event)
        XCTAssertNil(textForGhosttyKeyEvent(event!))
    }

    func testConsumedBindingWithoutActiveSequencesAttemptsMenu() {
        XCTAssertTrue(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue),
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testPerformableBindingDoesNotAttemptMenu() {
        XCTAssertFalse(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(
                    GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue | GHOSTTY_BINDING_FLAGS_PERFORMABLE.rawValue
                ),
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testActiveKeySequenceSuppressesMenuAttempt() {
        XCTAssertFalse(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue),
                hasActiveKeySequence: true,
                hasActiveKeyTable: false
            )
        )
    }

    func testAllBindingDoesNotAttemptMenu() {
        XCTAssertFalse(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(
                    GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue | GHOSTTY_BINDING_FLAGS_ALL.rawValue
                ),
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testUnboundOptionShortcutStillAttemptsMenu() {
        XCTAssertTrue(
            aiyuTermGhosttyShouldAttemptMenuKeyEquivalent(
                bindingFlags: nil,
                modifierFlags: [.option],
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testPlainUnboundKeyDoesNotAttemptMenu() {
        XCTAssertFalse(
            aiyuTermGhosttyShouldAttemptMenuKeyEquivalent(
                bindingFlags: nil,
                modifierFlags: [],
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testUnboundShortcutSkipsMenuDuringActiveKeySequence() {
        XCTAssertFalse(
            aiyuTermGhosttyShouldAttemptMenuKeyEquivalent(
                bindingFlags: nil,
                modifierFlags: [.option],
                hasActiveKeySequence: true,
                hasActiveKeyTable: false
            )
        )
    }

    func testGhosttySplitRightStopsDispatchingWhenShortcutIsCustomized() {
        var settings = AppSettings()
        AiyuTermKeyboardShortcuts.setShortcut(
            StoredShortcut(key: "d", command: false, shift: false, option: true, control: false),
            for: .splitRight,
            in: &settings
        )

        XCTAssertFalse(
            aiyuTermGhosttyShouldDispatchWorkspaceSplitAction(
                GHOSTTY_SPLIT_DIRECTION_RIGHT,
                settings: settings
            )
        )
    }

    func testGhosttySplitDownStopsDispatchingWhenShortcutIsDisabled() {
        var settings = AppSettings()
        AiyuTermKeyboardShortcuts.disableShortcut(for: .splitDown, in: &settings)

        XCTAssertFalse(
            aiyuTermGhosttyShouldDispatchWorkspaceSplitAction(
                GHOSTTY_SPLIT_DIRECTION_DOWN,
                settings: settings
            )
        )
    }

    func testGhosttySplitRightStillDispatchesWithDefaultShortcut() {
        XCTAssertTrue(
            aiyuTermGhosttyShouldDispatchWorkspaceSplitAction(
                GHOSTTY_SPLIT_DIRECTION_RIGHT,
                settings: AppSettings()
            )
        )
    }

    func testCtrlReturnEquivalentKeyStaysReturn() {
        let resolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "\r",
            characters: "\r",
            modifierFlags: [.control],
            eventTimestamp: 42,
            lastPerformKeyEvent: nil
        )

        XCTAssertEqual(resolution.equivalent, "\r")
        XCTAssertNil(resolution.nextLastPerformKeyEvent)
    }

    func testCommandKeyEquivalentRequiresSecondPassToRedispatch() {
        let firstResolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "k",
            characters: "k",
            modifierFlags: [.command],
            eventTimestamp: 42,
            lastPerformKeyEvent: nil
        )
        XCTAssertNil(firstResolution.equivalent)
        XCTAssertEqual(firstResolution.nextLastPerformKeyEvent, 42)

        let secondResolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "k",
            characters: "k",
            modifierFlags: [.command],
            eventTimestamp: 42,
            lastPerformKeyEvent: firstResolution.nextLastPerformKeyEvent
        )
        XCTAssertEqual(secondResolution.equivalent, "k")
        XCTAssertNil(secondResolution.nextLastPerformKeyEvent)
    }

    func testCtrlSlashEquivalentKeyBecomesUnderscore() {
        let resolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "/",
            characters: "/",
            modifierFlags: [.control],
            eventTimestamp: 42,
            lastPerformKeyEvent: nil
        )

        XCTAssertEqual(resolution.equivalent, "_")
        XCTAssertNil(resolution.nextLastPerformKeyEvent)
    }

    func testZeroTimestampDoesNotRedispatchEquivalentKey() {
        let resolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "k",
            characters: "k",
            modifierFlags: [.command],
            eventTimestamp: 0,
            lastPerformKeyEvent: 99
        )

        XCTAssertNil(resolution.equivalent)
        XCTAssertEqual(resolution.nextLastPerformKeyEvent, 99)
    }

    func testClampUsesTextLengthForNotFoundSelection() {
        XCTAssertEqual(
            AiyuTermGhosttyMarkedTextState.clamp(NSRange(location: NSNotFound, length: 3), textLength: 5),
            NSRange(location: 5, length: 0)
        )
    }

    func testClampCollapsesEmptyTextSelections() {
        XCTAssertEqual(
            AiyuTermGhosttyMarkedTextState.clamp(NSRange(location: 4, length: 2), textLength: 0),
            NSRange(location: 0, length: 0)
        )
    }

    func testTextFinderActionResolvesFromMenuItemTag() {
        let menuItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "f")
        menuItem.tag = NSTextFinder.Action.showFindInterface.rawValue

        XCTAssertEqual(aiyuTermTextFinderAction(for: menuItem), .showFindInterface)
    }

    func testTextFinderActionIgnoresUnsupportedSender() {
        XCTAssertNil(aiyuTermTextFinderAction(for: NSObject()))
    }

    func testGhosttySearchBindingActionUsesSearchPrefix() {
        XCTAssertEqual(
            aiyuTermGhosttySearchBindingAction(for: "needle"),
            "search:needle"
        )
    }

    func testGhosttySearchBindingActionPreservesLiteralQueryText() {
        XCTAssertEqual(
            aiyuTermGhosttySearchBindingAction(for: "error: timeout /tmp/a b"),
            "search:error: timeout /tmp/a b"
        )
    }

    func testGhosttySearchBindingActionAllowsEmptyQuery() {
        XCTAssertEqual(
            aiyuTermGhosttySearchBindingAction(for: ""),
            "search:"
        )
    }

    func testGhosttySearchNavigationBindingActionUsesNavigateSearchAction() {
        XCTAssertEqual(
            aiyuTermGhosttySearchNavigationBindingAction(.next),
            "navigate_search:next"
        )
        XCTAssertEqual(
            aiyuTermGhosttySearchNavigationBindingAction(.previous),
            "navigate_search:previous"
        )
    }

    func testTerminalDropTextQuotesFilePathsForShells() {
        let fileURLs = [
            URL(fileURLWithPath: "/tmp/aiyuterm screenshot.png"),
            URL(fileURLWithPath: "/tmp/it's-aiyuterm.jpg"),
        ]

        XCTAssertEqual(
            aiyuTermTerminalDropText(fileURLs: fileURLs, plainText: nil),
            "'/tmp/aiyuterm screenshot.png' '/tmp/it'\\''s-liney.jpg'"
        )
    }

    func testTerminalDropTextFallsBackToPlainText() {
        XCTAssertEqual(
            aiyuTermTerminalDropText(fileURLs: [], plainText: "dragged prompt"),
            "dragged prompt"
        )
    }

    func testDeleteBackwardRemovesSingleComposedCharacter() {
        var state = AiyuTermGhosttyMarkedTextState(
            text: "你好",
            selectedRange: NSRange(location: 2, length: 0)
        )

        state.deleteBackward()

        XCTAssertEqual(state.text, "你")
        XCTAssertEqual(state.selectedRange, NSRange(location: 1, length: 0))
    }

    func testDeleteBackwardRemovesSingleCharacterWhenImeSelectionSpansMarkedText() {
        var state = AiyuTermGhosttyMarkedTextState(
            text: "你好",
            selectedRange: NSRange(location: 0, length: 2)
        )

        state.deleteBackward()

        XCTAssertEqual(state.text, "你")
        XCTAssertEqual(state.selectedRange, NSRange(location: 1, length: 0))
    }

    func testSetMarkedTextHonorsReplacementRangeAndOffsetsSelection() {
        var state = AiyuTermGhosttyMarkedTextState(
            text: "nihao",
            selectedRange: NSRange(location: 5, length: 0)
        )

        state.setMarkedText(
            "u",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: 4, length: 1)
        )

        XCTAssertEqual(state.text, "nihau")
        XCTAssertEqual(state.selectedRange, NSRange(location: 5, length: 0))
    }

    func testAppKitModsReplacesDirectionalModifiersButPreservesFallbackFlags() {
        let mods = ghostty_input_mods_e(GHOSTTY_MODS_ALT.rawValue | GHOSTTY_MODS_SHIFT.rawValue)
        let resolved = appKitMods(mods, fallback: [.capsLock, .command])

        XCTAssertEqual(resolved.intersection([.shift, .option, .command, .capsLock]), [.shift, .option, .capsLock])
    }

    func testModifierActionReleasesControlEvenWhenAnotherModifierRemainsPressed() {
        XCTAssertEqual(
            aiyuTermGhosttyModifierAction(
                keyCode: UInt16(kVK_Control),
                modifierFlags: [.command]
            ),
            GHOSTTY_ACTION_RELEASE
        )
    }

    func testModifierActionPressesRightControlOnlyWhenDirectionalBitIsSet() {
        let flags = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.control.rawValue | UInt(NX_DEVICERCTLKEYMASK)
        )

        XCTAssertEqual(
            aiyuTermGhosttyModifierAction(
                keyCode: UInt16(kVK_RightControl),
                modifierFlags: flags
            ),
            GHOSTTY_ACTION_PRESS
        )
    }

    func testModifierActionIgnoresNonModifierKeys() {
        XCTAssertNil(
            aiyuTermGhosttyModifierAction(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlags: [.control]
            )
        )
    }
}
