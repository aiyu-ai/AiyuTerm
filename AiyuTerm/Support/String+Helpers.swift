//
//  String+Helpers.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Foundation

extension String {
    nonisolated var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated func nonEmptyOrFallback(_ fallback: @autoclosure () -> String) -> String {
        nilIfEmpty ?? fallback()
    }
}
