//
//  LocalizationManager.swift
//  AiyuTerm
//
//  Author: everettjf
//
import Combine
import Foundation

extension Notification.Name {
    static let aiyuTermLocalizationDidChange = Notification.Name("aiyuterm.localizationDidChange")
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    nonisolated(unsafe) private static var cachedSelectedLanguage: AppLanguage = .automatic

    @Published private(set) var selectedLanguage: AppLanguage

    init(selectedLanguage: AppLanguage = .automatic) {
        self.selectedLanguage = selectedLanguage
        Self.cachedSelectedLanguage = selectedLanguage
    }

    nonisolated static func resolveAutomaticLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferredLanguages {
            let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
            if normalized == "en" || normalized.hasPrefix("en-") {
                return .english
            }
            if normalized == "zh" || normalized.hasPrefix("zh-") {
                return .simplifiedChinese
            }
        }

        return .english
    }

    nonisolated static func stringForCurrentLanguage(_ key: String) -> String {
        let language = switch cachedSelectedLanguage {
        case .automatic:
            resolveAutomaticLanguage()
        case .english, .simplifiedChinese:
            cachedSelectedLanguage
        }
        return L10nTable.string(for: key, language: language)
    }

    var effectiveLanguage: AppLanguage {
        switch selectedLanguage {
        case .automatic:
            Self.resolveAutomaticLanguage()
        case .english, .simplifiedChinese:
            selectedLanguage
        }
    }

    func updateSelectedLanguage(_ language: AppLanguage) {
        guard selectedLanguage != language else { return }
        selectedLanguage = language
        Self.cachedSelectedLanguage = language
        NotificationCenter.default.post(name: .aiyuTermLocalizationDidChange, object: language)
    }

    func string(_ key: String) -> String {
        L10nTable.string(for: key, language: effectiveLanguage)
    }
}
