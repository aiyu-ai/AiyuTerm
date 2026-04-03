//
//  SidebarIconCatalog.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

nonisolated enum SidebarIconCatalog {
    nonisolated struct Symbol: Hashable, Identifiable {
        let title: String
        let systemName: String

        var id: String { systemName }
    }

    static let symbols: [Symbol] = [
        Symbol(title: "Branch", systemName: "arrow.triangle.branch"),
        Symbol(title: "Terminal", systemName: "terminal.fill"),
        Symbol(title: "Folder", systemName: "folder.fill"),
        Symbol(title: "Tray", systemName: "tray.full.fill"),
        Symbol(title: "Double Tray", systemName: "tray.2.fill"),
        Symbol(title: "Shipping Box", systemName: "shippingbox.fill"),
        Symbol(title: "Shipping Ring", systemName: "shippingbox.circle.fill"),
        Symbol(title: "Cube", systemName: "cube.fill"),
        Symbol(title: "Transparent Cube", systemName: "cube.transparent.fill"),
        Symbol(title: "Server", systemName: "server.rack"),
        Symbol(title: "Cloud", systemName: "cloud.fill"),
        Symbol(title: "Network", systemName: "network"),
        Symbol(title: "Globe", systemName: "globe"),
        Symbol(title: "Display", systemName: "display.2"),
        Symbol(title: "Laptop", systemName: "laptopcomputer"),
        Symbol(title: "Desktop", systemName: "desktopcomputer"),
        Symbol(title: "Hammer", systemName: "hammer.fill"),
        Symbol(title: "Bolt", systemName: "bolt.fill"),
        Symbol(title: "Bolt Shield", systemName: "bolt.shield.fill"),
        Symbol(title: "Sparkles", systemName: "sparkles"),
        Symbol(title: "Wand", systemName: "wand.and.stars"),
        Symbol(title: "Scope", systemName: "scope"),
        Symbol(title: "Target", systemName: "target"),
        Symbol(title: "Circle", systemName: "circle.fill"),
        Symbol(title: "Square", systemName: "square.fill"),
        Symbol(title: "Grid", systemName: "square.grid.3x3.fill"),
        Symbol(title: "Hexagon", systemName: "hexagon.fill"),
        Symbol(title: "Capsule", systemName: "capsule.fill"),
        Symbol(title: "Briefcase", systemName: "briefcase.fill"),
        Symbol(title: "Building", systemName: "building.2.fill"),
        Symbol(title: "Books", systemName: "books.vertical.fill"),
        Symbol(title: "Bookmark", systemName: "bookmark.fill"),
        Symbol(title: "Archive Box", systemName: "archivebox.fill"),
        Symbol(title: "Archive Ring", systemName: "archivebox.circle.fill"),
        Symbol(title: "Document", systemName: "doc.text.fill"),
        Symbol(title: "Rich Text", systemName: "doc.richtext.fill"),
        Symbol(title: "Copy Document", systemName: "doc.on.doc.fill"),
        Symbol(title: "Lock Document", systemName: "lock.doc.fill"),
        Symbol(title: "Chart Document", systemName: "chart.bar.doc.horizontal.fill"),
        Symbol(title: "Paper Plane", systemName: "paperplane.fill"),
        Symbol(title: "Antenna", systemName: "antenna.radiowaves.left.and.right"),
        Symbol(title: "CPU", systemName: "cpu.fill"),
        Symbol(title: "Memory", systemName: "memorychip.fill"),
        Symbol(title: "External Drive", systemName: "externaldrive.fill"),
        Symbol(title: "Internal Drive", systemName: "internaldrive.fill"),
        Symbol(title: "Shield", systemName: "shield.fill"),
        Symbol(title: "Key", systemName: "key.fill"),
        Symbol(title: "Wrench", systemName: "wrench.and.screwdriver.fill"),
        Symbol(title: "Pencil & Ruler", systemName: "pencil.and.ruler.fill"),
        Symbol(title: "Paint Palette", systemName: "paintpalette.fill"),
        Symbol(title: "Puzzle", systemName: "puzzlepiece.extension.fill"),
        Symbol(title: "Compass", systemName: "location.north.line.fill"),
        Symbol(title: "Binoculars", systemName: "binoculars.fill"),
        Symbol(title: "Chart Bar", systemName: "chart.bar.fill"),
        Symbol(title: "Chart Pie", systemName: "chart.pie.fill"),
        Symbol(title: "Newspaper", systemName: "newspaper.fill"),
        Symbol(title: "Scroll", systemName: "scroll.fill"),
        Symbol(title: "Megaphone", systemName: "megaphone.fill"),
        Symbol(title: "Link", systemName: "link.circle.fill"),
        Symbol(title: "People", systemName: "person.3.fill"),
        Symbol(title: "Panels", systemName: "rectangle.3.group.fill"),
        Symbol(title: "Crossed Flags", systemName: "flag.2.crossed.fill"),
        Symbol(title: "Aperture", systemName: "camera.aperture")
    ]

    static let repositorySymbolNames: [String] = symbols
        .map(\.systemName)
        .filter { !["terminal.fill", "circle.fill", "square.fill"].contains($0) }
}

extension SidebarItemIcon {
    nonisolated static func random() -> SidebarItemIcon {
        SidebarItemIcon(
            symbolName: SidebarIconCatalog.symbols.randomElement()?.systemName ?? repositoryDefault.symbolName,
            palette: SidebarIconPalette.allCases.randomElement() ?? .blue,
            fillStyle: SidebarIconFillStyle.allCases.randomElement() ?? .gradient
        )
    }

    nonisolated static func randomRepository() -> SidebarItemIcon {
        randomRepository(avoiding: [])
    }

    nonisolated static func randomRepository(avoiding existingIcons: [SidebarItemIcon]) -> SidebarItemIcon {
        let usage = SidebarIconCatalog.RepositoryUsage(existingIcons: existingIcons)
        let candidates = SidebarIconCatalog.repositoryCandidates.shuffled()
        let scored = candidates.map { icon in
            (icon, SidebarIconCatalog.repositoryScore(for: icon, usage: usage, preferences: nil))
        }

        guard let bestScore = scored.map(\.1).max() else {
            return repositoryDefault
        }

        let bestCandidates = scored
            .filter { $0.1 == bestScore }
            .map(\.0)

        return bestCandidates.randomElement() ?? repositoryDefault
    }

    nonisolated static func randomRepository(
        preferredSeed: String,
        avoiding existingIcons: [SidebarItemIcon]
    ) -> SidebarItemIcon {
        let usage = SidebarIconCatalog.RepositoryUsage(existingIcons: existingIcons)
        let preferences = SidebarIconCatalog.RepositoryStylePreferences(seedSource: preferredSeed)
        let scored = SidebarIconCatalog.repositoryCandidates.map { icon in
            (icon, SidebarIconCatalog.repositoryScore(for: icon, usage: usage, preferences: preferences))
        }

        guard let bestScore = scored.map(\.1).max() else {
            return repositoryDefault
        }

        let bestCandidates = scored
            .filter { $0.1 == bestScore }
            .sorted {
                SidebarIconCatalog.seededCandidateRank(for: $0.0, seed: preferences.seed)
                    < SidebarIconCatalog.seededCandidateRank(for: $1.0, seed: preferences.seed)
            }
            .map(\.0)

        return bestCandidates.first ?? repositoryDefault
    }

    nonisolated static func generatedWorktreeIcons(
        seedSourcesByID: [String: String],
        overrides: [String: SidebarItemIcon] = [:]
    ) -> [String: SidebarItemIcon] {
        let orderedIDs = seedSourcesByID.keys.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }

        var iconsByID: [String: SidebarItemIcon] = [:]
        for id in orderedIDs {
            if let override = overrides[id] {
                iconsByID[id] = override
                continue
            }

            let preferredSeed = seedSourcesByID[id] ?? id
            iconsByID[id] = randomRepository(
                preferredSeed: preferredSeed,
                avoiding: Array(iconsByID.values)
            )
        }

        return iconsByID
    }
}

extension SidebarIconCatalog {
    nonisolated struct RepositorySemanticProfile {
        let preferredSymbolNames: [String]
        let preferredPalettes: [SidebarIconPalette]
        let preferredFillStyle: SidebarIconFillStyle?
    }

    nonisolated struct RepositoryUsage {
        let recentSymbolNames: Set<String>
        let recentPalettes: Set<SidebarIconPalette>
        let recentPairs: Set<String>
        let symbolFrequency: [String: Int]
        let paletteFrequency: [SidebarIconPalette: Int]
        let pairFrequency: [String: Int]

        init(existingIcons: [SidebarItemIcon]) {
            let recentIcons = Array(existingIcons.suffix(3))

            recentSymbolNames = Set(recentIcons.map(\.symbolName))
            recentPalettes = Set(recentIcons.map(\.palette))
            recentPairs = Set(recentIcons.map { $0.repositoryPairKey })

            var symbolFrequency: [String: Int] = [:]
            var paletteFrequency: [SidebarIconPalette: Int] = [:]
            var pairFrequency: [String: Int] = [:]

            for icon in existingIcons {
                symbolFrequency[icon.symbolName, default: 0] += 1
                paletteFrequency[icon.palette, default: 0] += 1
                pairFrequency[icon.repositoryPairKey, default: 0] += 1
            }

            self.symbolFrequency = symbolFrequency
            self.paletteFrequency = paletteFrequency
            self.pairFrequency = pairFrequency
        }
    }

    nonisolated struct RepositoryStylePreferences {
        let seed: UInt64
        let primarySymbolName: String
        let secondarySymbolName: String
        let primaryPalette: SidebarIconPalette
        let secondaryPalette: SidebarIconPalette
        let preferredFillStyle: SidebarIconFillStyle
        let semanticProfile: RepositorySemanticProfile?

        init(seedSource: String) {
            let normalizedSeedSource = seedSource
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let seed = SidebarIconCatalog.stableHash(normalizedSeedSource.nilIfEmpty ?? "repository")
            self.seed = seed

            let orderedSymbols = SidebarIconCatalog.seededSymbolNames(seed: seed)
            primarySymbolName = orderedSymbols.first ?? SidebarItemIcon.repositoryDefault.symbolName
            secondarySymbolName = orderedSymbols.dropFirst().first ?? primarySymbolName

            let orderedPalettes = SidebarIconCatalog.seededPalettes(seed: seed)
            primaryPalette = orderedPalettes.first ?? .blue
            secondaryPalette = orderedPalettes.dropFirst().first ?? primaryPalette

            preferredFillStyle = SidebarIconCatalog.mix64(seed ^ 0x51ed270b29a1c53d).isMultiple(of: 3) ? .solid : .gradient
            semanticProfile = SidebarIconCatalog.semanticProfile(for: normalizedSeedSource)
        }
    }

    nonisolated static let repositoryCandidates: [SidebarItemIcon] = repositorySymbolNames.flatMap { symbolName in
        SidebarIconPalette.allCases.flatMap { palette in
            SidebarIconFillStyle.allCases.map { fillStyle in
                SidebarItemIcon(
                    symbolName: symbolName,
                    palette: palette,
                    fillStyle: fillStyle
                )
            }
        }
    }

    nonisolated static func repositoryScore(
        for icon: SidebarItemIcon,
        usage: RepositoryUsage,
        preferences: RepositoryStylePreferences?
    ) -> Int {
        var score = 0

        score -= usage.pairFrequency[icon.repositoryPairKey, default: 0] * 12
        score -= usage.symbolFrequency[icon.symbolName, default: 0] * 4
        score -= usage.paletteFrequency[icon.palette, default: 0] * 3

        if usage.recentPairs.contains(icon.repositoryPairKey) {
            score -= 16
        }
        if usage.recentSymbolNames.contains(icon.symbolName) {
            score -= 10
        }
        if usage.recentPalettes.contains(icon.palette) {
            score -= 8
        }

        if let preferences {
            if let semanticProfile = preferences.semanticProfile {
                if let symbolIndex = semanticProfile.preferredSymbolNames.firstIndex(of: icon.symbolName) {
                    switch symbolIndex {
                    case 0:
                        score += 42
                    case 1:
                        score += 28
                    case 2:
                        score += 16
                    default:
                        score += 8
                    }
                }

                if let paletteIndex = semanticProfile.preferredPalettes.firstIndex(of: icon.palette) {
                    switch paletteIndex {
                    case 0:
                        score += 14
                    case 1:
                        score += 9
                    case 2:
                        score += 5
                    default:
                        score += 3
                    }
                }

                if icon.fillStyle == semanticProfile.preferredFillStyle {
                    score += 3
                }
            }

            if icon.symbolName == preferences.primarySymbolName {
                score += 18
            } else if icon.symbolName == preferences.secondarySymbolName {
                score += 9
            }

            if icon.palette == preferences.primaryPalette {
                score += 14
            } else if icon.palette == preferences.secondaryPalette {
                score += 7
            }

            if icon.fillStyle == preferences.preferredFillStyle {
                score += 4
            }
        } else if icon.fillStyle == .gradient {
            score += 2
        }

        return score
    }

    nonisolated static func seededCandidateRank(for icon: SidebarItemIcon, seed: UInt64) -> UInt64 {
        mix64(seed ^ stableHash("\(icon.symbolName)|\(icon.palette.rawValue)|\(icon.fillStyle.rawValue)"))
    }

    nonisolated private static func seededSymbolNames(seed: UInt64) -> [String] {
        repositorySymbolNames.sorted {
            mix64(seed ^ stableHash($0) ^ 0x3c79ac492ba7b653)
                < mix64(seed ^ stableHash($1) ^ 0x3c79ac492ba7b653)
        }
    }

    nonisolated private static func seededPalettes(seed: UInt64) -> [SidebarIconPalette] {
        SidebarIconPalette.allCases.sorted {
            mix64(seed ^ stableHash($0.rawValue) ^ 0x1c69b3f74ac4ae35)
                < mix64(seed ^ stableHash($1.rawValue) ^ 0x1c69b3f74ac4ae35)
        }
    }

    nonisolated private static func semanticProfile(for normalizedName: String) -> RepositorySemanticProfile? {
        guard !normalizedName.isEmpty else { return nil }

        let categoryProfiles: [([String], RepositorySemanticProfile)] = [
            (
                ["api", "backend", "server", "service", "worker", "daemon", "rpc", "gateway"],
                RepositorySemanticProfile(
                    preferredSymbolNames: ["server.rack", "cpu.fill", "network", "antenna.radiowaves.left.and.right"],
                    preferredPalettes: [.navy, .steel, .cyan, .indigo],
                    preferredFillStyle: .gradient
                )
            ),
            (
                ["web", "site", "ui", "frontend", "client", "app", "landing", "portal"],
                RepositorySemanticProfile(
                    preferredSymbolNames: ["globe", "sparkles", "wand.and.stars", "paintpalette.fill"],
                    preferredPalettes: [.aqua, .sky, .orchid, .violet],
                    preferredFillStyle: .gradient
                )
            ),
            (
                ["docs", "doc", "blog", "wiki", "guide", "manual", "notes"],
                RepositorySemanticProfile(
                    preferredSymbolNames: ["doc.text.fill", "doc.richtext.fill", "books.vertical.fill", "archivebox.fill"],
                    preferredPalettes: [.sand, .amber, .bronze, .gold],
                    preferredFillStyle: .solid
                )
            ),
            (
                ["infra", "ops", "deploy", "release", "terraform", "k8s", "kubernetes", "devops", "cluster", "platform"],
                RepositorySemanticProfile(
                    preferredSymbolNames: ["wrench.and.screwdriver.fill", "shippingbox.fill", "bolt.shield.fill", "shield.fill"],
                    preferredPalettes: [.charcoal, .steel, .graphite, .copper],
                    preferredFillStyle: .solid
                )
            ),
            (
                ["data", "db", "database", "cache", "queue", "search", "index", "storage"],
                RepositorySemanticProfile(
                    preferredSymbolNames: ["externaldrive.fill", "internaldrive.fill", "memorychip.fill", "chart.bar.fill"],
                    preferredPalettes: [.aqua, .teal, .blue, .navy],
                    preferredFillStyle: .gradient
                )
            ),
            (
                ["auth", "secure", "security", "secret", "crypto", "vault", "token", "key"],
                RepositorySemanticProfile(
                    preferredSymbolNames: ["shield.fill", "key.fill", "lock.doc.fill", "bolt.shield.fill"],
                    preferredPalettes: [.ruby, .crimson, .navy, .charcoal],
                    preferredFillStyle: .solid
                )
            )
        ]

        var matchedSymbols: [String] = []
        var matchedPalettes: [SidebarIconPalette] = []
        var preferredFillStyle: SidebarIconFillStyle?

        for (keywords, profile) in categoryProfiles {
            guard keywords.contains(where: { keyword in normalizedName.contains(keyword) }) else {
                continue
            }

            for symbolName in profile.preferredSymbolNames where !matchedSymbols.contains(symbolName) {
                matchedSymbols.append(symbolName)
            }
            for palette in profile.preferredPalettes where !matchedPalettes.contains(palette) {
                matchedPalettes.append(palette)
            }
            preferredFillStyle = preferredFillStyle ?? profile.preferredFillStyle
        }

        guard !matchedSymbols.isEmpty || !matchedPalettes.isEmpty || preferredFillStyle != nil else {
            return nil
        }

        return RepositorySemanticProfile(
            preferredSymbolNames: matchedSymbols,
            preferredPalettes: matchedPalettes,
            preferredFillStyle: preferredFillStyle
        )
    }

    nonisolated static func stableHash(_ value: String) -> UInt64 {
        let offsetBasis: UInt64 = 1469598103934665603
        let prime: UInt64 = 1099511628211

        return value.utf8.reduce(offsetBasis) { partialResult, byte in
            (partialResult ^ UInt64(byte)) &* prime
        }
    }

    nonisolated static func mix64(_ value: UInt64) -> UInt64 {
        var state = value &+ 0x9e3779b97f4a7c15
        state = (state ^ (state >> 30)) &* 0xbf58476d1ce4e5b9
        state = (state ^ (state >> 27)) &* 0x94d049bb133111eb
        return state ^ (state >> 31)
    }
}

private extension SidebarItemIcon {
    nonisolated var repositoryPairKey: String {
        "\(symbolName)|\(palette.rawValue)"
    }
}
