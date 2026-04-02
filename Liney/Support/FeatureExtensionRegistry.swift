//
//  FeatureExtensionRegistry.swift
//  AiyuTerm
//

import Foundation

struct AiyuTermExtensionContext {
    let selectedWorkspace: WorkspaceModel?
    let workspaces: [WorkspaceModel]
}

protocol AiyuTermFeatureExtension {
    var id: String { get }
    func commandPaletteItems(context: AiyuTermExtensionContext) -> [CommandPaletteItem]
}

struct SupportLinksExtension: AiyuTermFeatureExtension {
    let id = "support-links"

    func commandPaletteItems(context: AiyuTermExtensionContext) -> [CommandPaletteItem] {
        _ = context
        return [
            CommandPaletteItem(
                id: "extension-support-website",
                title: LocalizationManager.shared.string("extension.support.website"),
                subtitle: "liney.dev",
                group: .navigation,
                keywords: ["extension", "help", "website", "docs"],
                isGlobal: true,
                kind: .command(.openAiyuTermWebsite)
            ),
            CommandPaletteItem(
                id: "extension-support-feedback",
                title: LocalizationManager.shared.string("extension.support.feedback"),
                subtitle: "github.com/everettjf/liney/issues/new",
                group: .navigation,
                keywords: ["extension", "feedback", "issue", "bug"],
                isGlobal: true,
                kind: .command(.submitAiyuTermFeedback)
            )
        ]
    }
}

final class AiyuTermFeatureRegistry {
    static let shared = AiyuTermFeatureRegistry(extensions: [
        SupportLinksExtension()
    ])

    private(set) var extensions: [any AiyuTermFeatureExtension]

    init(extensions: [any AiyuTermFeatureExtension] = []) {
        self.extensions = extensions
    }

    func register(_ featureExtension: any AiyuTermFeatureExtension) {
        guard !extensions.contains(where: { $0.id == featureExtension.id }) else { return }
        extensions.append(featureExtension)
    }

    func commandPaletteItems(context: AiyuTermExtensionContext) -> [CommandPaletteItem] {
        extensions.flatMap { $0.commandPaletteItems(context: context) }
    }
}
