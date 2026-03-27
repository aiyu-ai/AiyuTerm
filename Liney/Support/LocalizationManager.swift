//
//  LocalizationManager.swift
//  Liney
//
//  Author: wuwenrui
//
import Combine
import Foundation

extension Notification.Name {
    static let lineyLocalizationDidChange = Notification.Name("liney.localizationDidChange")
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var selectedLanguage: AppLanguage

    init(selectedLanguage: AppLanguage = .automatic) {
        self.selectedLanguage = selectedLanguage
    }

    static func resolveAutomaticLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
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
        NotificationCenter.default.post(name: .lineyLocalizationDidChange, object: language)
    }

    func string(_ key: String) -> String {
        L10nTable.string(for: key, language: effectiveLanguage)
    }
}
