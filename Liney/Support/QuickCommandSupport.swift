//
//  QuickCommandSupport.swift
//  Liney
//
//  Author: wuwenrui
//

import AppKit
import Foundation

nonisolated struct QuickCommandCategory: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var symbolName: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case symbolName
    }

    init(id: String, title: String, symbolName: String) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? UUID().uuidString
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Commands"
        self.symbolName = symbolName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "tag"
    }

    static let general = QuickCommandCategory(id: "general", title: "General", symbolName: "square.grid.2x2")
    static let codex = QuickCommandCategory(id: "codex", title: "Codex", symbolName: "command")
    static let claude = QuickCommandCategory(id: "claude", title: "Claude", symbolName: "text.bubble")
    static let cloud = QuickCommandCategory(id: "cloud", title: "Cloud", symbolName: "cloud.fill")
    static let linux = QuickCommandCategory(id: "linux", title: "Linux", symbolName: "terminal")
    static let files = QuickCommandCategory(id: "files", title: "Files", symbolName: "folder")
    static let search = QuickCommandCategory(id: "search", title: "Search", symbolName: "magnifyingglass")
    static let text = QuickCommandCategory(id: "text", title: "Text", symbolName: "doc.text")
    static let processes = QuickCommandCategory(id: "processes", title: "Processes", symbolName: "waveform.path.ecg")
    static let network = QuickCommandCategory(id: "network", title: "Network", symbolName: "network")
    static let system = QuickCommandCategory(id: "system", title: "System", symbolName: "gearshape.2")
    static let complex = QuickCommandCategory(id: "complex", title: "Complex", symbolName: "slider.horizontal.3")
    static let archives = QuickCommandCategory(id: "archives", title: "Archives", symbolName: "archivebox")
    static let git = QuickCommandCategory(id: "git", title: "Git", symbolName: "point.topleft.down.curvedto.point.bottomright.up")
    static let homebrew = QuickCommandCategory(id: "homebrew", title: "Homebrew", symbolName: "cup.and.saucer.fill")
    static let macos = QuickCommandCategory(id: "macos", title: "macOS", symbolName: "apple.logo")

    static let builtInCategories: [QuickCommandCategory] = [
        .general,
        .codex,
        .claude,
        .cloud,
        .linux,
        .files,
        .search,
        .text,
        .processes,
        .network,
        .system,
        .complex,
        .archives,
        .git,
        .homebrew,
        .macos,
    ]

    static let builtInByID = Dictionary(uniqueKeysWithValues: builtInCategories.map { ($0.id, $0) })
    static let defaultCategory = QuickCommandCategory.codex
    static let fallbackCategory = QuickCommandCategory.general

    var isBuiltIn: Bool {
        Self.builtInByID[id] != nil
    }

    var normalized: QuickCommandCategory {
        if let builtIn = Self.builtInByID[id] {
            return builtIn
        }
        return QuickCommandCategory(
            id: id,
            title: title,
            symbolName: symbolName
        )
    }

    init(from decoder: any Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let legacyID = try? singleValue.decode(String.self) {
            self = Self.builtInByID[legacyID] ?? QuickCommandCategory(id: legacyID, title: legacyID.capitalized, symbolName: "tag")
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "Commands",
            symbolName: try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "tag"
        )
    }
}

nonisolated struct QuickCommandPreset: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var command: String
    var categoryID: String
    var shortcut: StoredShortcut?
    var submitsReturn: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        command: String,
        categoryID: String,
        shortcut: StoredShortcut? = nil,
        submitsReturn: Bool = false
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? UUID().uuidString
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.command = command
        self.categoryID = categoryID.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? QuickCommandCategory.defaultCategory.id
        self.shortcut = shortcut
        self.submitsReturn = submitsReturn
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        command: String,
        category: QuickCommandCategory,
        shortcut: StoredShortcut? = nil,
        submitsReturn: Bool = false
    ) {
        self.init(
            id: id,
            title: title,
            command: command,
            categoryID: category.id,
            shortcut: shortcut,
            submitsReturn: submitsReturn
        )
    }

    var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? fallbackTitle
    }

    var normalizedCommand: String {
        command.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var fallbackTitle: String {
        normalizedCommand
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? QuickCommandCategory.defaultCategory.title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case command
        case categoryID
        case category
        case shortcut
        case submitsReturn
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString,
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            command: try container.decodeIfPresent(String.self, forKey: .command) ?? "",
            categoryID: Self.decodeCategoryID(from: container),
            shortcut: try container.decodeIfPresent(StoredShortcut.self, forKey: .shortcut),
            submitsReturn: try container.decodeIfPresent(Bool.self, forKey: .submitsReturn) ?? false
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(command, forKey: .command)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(shortcut, forKey: .shortcut)
        try container.encode(submitsReturn, forKey: .submitsReturn)
    }

    private static func decodeCategoryID(from container: KeyedDecodingContainer<CodingKeys>) -> String {
        if let categoryID = try? container.decodeIfPresent(String.self, forKey: .categoryID),
           !categoryID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return categoryID
        }
        if let legacyID = try? container.decodeIfPresent(String.self, forKey: .category),
           !legacyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return legacyID
        }
        if let legacyCategory = try? container.decodeIfPresent(QuickCommandCategory.self, forKey: .category) {
            return legacyCategory.id
        }
        return QuickCommandCategory.defaultCategory.id
    }
}

enum QuickCommandCatalog {
    static let maxRecentCount = 6
    static let recommendedComplexCommandOrder: [String] = [
        "library-complex-list-listening-ports",
        "library-complex-port-3000-ownership",
        "library-complex-disk-usage-top-20",
        "library-complex-largest-files",
        "library-complex-top-cpu-processes",
        "library-complex-tail-and-filter-errors",
        "library-complex-find-todo-and-fixme",
        "library-complex-git-files-changed-most",
        "library-complex-package-scripts",
        "library-complex-swift-test-failures-summary",
        "library-complex-http-timing-breakdown",
        "library-complex-search-secrets-patterns",
    ]
    static let recommendedComplexCommandIDs = Set(recommendedComplexCommandOrder)

    static let defaultCommands: [QuickCommandPreset] = [
        QuickCommandPreset(
            id: "codex",
            title: "codex",
            command: "codex",
            categoryID: QuickCommandCategory.codex.id
        ),
        QuickCommandPreset(
            id: "codex-bypass",
            title: "codex --dangerously-bypass-approvals-and-sandbox",
            command: "codex --dangerously-bypass-approvals-and-sandbox",
            categoryID: QuickCommandCategory.codex.id
        ),
        QuickCommandPreset(
            id: "codex-resume",
            title: "codex resume",
            command: "codex resume",
            categoryID: QuickCommandCategory.codex.id
        ),
        QuickCommandPreset(
            id: "claude",
            title: "claude",
            command: "claude",
            categoryID: QuickCommandCategory.claude.id
        ),
        QuickCommandPreset(
            id: "claude-skip-permissions",
            title: "claude --dangerously-skip-permissions",
            command: "claude --dangerously-skip-permissions",
            categoryID: QuickCommandCategory.claude.id
        ),
        QuickCommandPreset(
            id: "claude-resume",
            title: "claude --resume",
            command: "claude --resume",
            categoryID: QuickCommandCategory.claude.id
        ),
    ]

    static let defaultCategories = QuickCommandCategory.builtInCategories

    static let predefinedCommands: [QuickCommandPreset] = [
        library("pwd", "pwd", .files),
        library("ls", "ls -lah", .files),
        library("tree", "tree -L 2", .files),
        library("mkdir", "mkdir -p new-folder", .files),
        library("cp", "cp -R source target", .files),
        library("mv", "mv old-name new-name", .files),
        library("rm", "rm -rf path", .files),
        library("du", "du -sh * | sort -h", .files),
        library("df", "df -h", .files),
        library("stat", "stat file.txt", .files),
        library("touch", "touch file.txt", .files),
        library("ln", "ln -s target shortcut", .files),
        library("which", "which git", .search),
        library("whereis", "whereis ssh", .search),
        library("find name", "find . -name \"*.swift\"", .search),
        library("find size", "find . -type f -size +50M", .search),
        library("mdfind", "mdfind \"kMDItemFSName == '*.png'\"", .search),
        library("grep", "grep -R \"TODO\" .", .search),
        library("rg", "rg \"WorkspaceStore\"", .search),
        library("fd", "fd \"swift$\"", .search),
        library("locate", "locate hosts", .search),
        library("man", "man ssh", .search),
        library("head", "head -n 20 file.txt", .text),
        library("tail", "tail -n 50 file.txt", .text),
        library("tail follow", "tail -f app.log", .text),
        library("cat", "cat file.txt", .text),
        library("less", "less file.txt", .text),
        library("sort", "sort file.txt | uniq -c", .text),
        library("cut", "cut -d ',' -f 1 data.csv", .text),
        library("paste", "paste -d ',' file1 file2", .text),
        library("tr", "tr '[:lower:]' '[:upper:]' < file.txt", .text),
        library("sed replace", "sed -E 's/foo/bar/g' file.txt", .text),
        library("awk column", "awk '{print $1, $NF}' file.txt", .text),
        library("jq", "jq '.' data.json", .text),
        library("pbcopy", "cat file.txt | pbcopy", .text),
        library("pbpaste", "pbpaste", .text),
        library("wc", "wc -l file.txt", .text),
        library("ps", "ps aux | grep process", .processes),
        library("top", "top -o cpu", .processes),
        library("htop", "htop", .processes),
        library("kill", "kill -9 PID", .processes),
        library("pkill", "pkill -f server-name", .processes),
        library("lsof", "lsof -i :3000", .processes),
        library("jobs", "jobs -l", .processes),
        library("fg", "fg %1", .processes),
        library("bg", "bg %1", .processes),
        library("nohup", "nohup npm run dev > app.log 2>&1 &", .processes),
        library("time", "time make test", .processes),
        library("watch", "watch -n 2 \"ls -lah\"", .processes),
        library("curl", "curl -L https://example.com", .network),
        library("curl headers", "curl -I https://example.com", .network),
        library("curl json post", "curl -X POST https://example.com/api -H 'Content-Type: application/json' -d '{}'", .network),
        library("wget", "wget https://example.com/archive.zip", .network),
        library("ssh", "ssh user@host", .network),
        library("scp", "scp file.txt user@host:/tmp/", .network),
        library("rsync", "rsync -avz ./ user@host:/srv/app/", .network),
        library("ping", "ping -c 5 example.com", .network),
        library("dig", "dig example.com", .network),
        library("nslookup", "nslookup example.com", .network),
        library("nc", "nc -vz 127.0.0.1 8080", .network),
        library("ifconfig", "ifconfig", .network),
        library("netstat", "netstat -an | grep LISTEN", .network),
        library("ssh keygen", "ssh-keygen -t ed25519 -C \"me@example.com\"", .network),
        library("env", "env | sort", .system),
        library("printenv", "printenv PATH", .system),
        library("export", "export PATH=\"$HOME/.local/bin:$PATH\"", .system),
        library("source", "source ~/.zshrc", .system),
        library("uname", "uname -a", .system),
        library("whoami", "whoami", .system),
        library("id", "id", .system),
        library("date", "date", .system),
        library("uptime", "uptime", .system),
        library("history", "history | tail -n 50", .system),
        library("clear", "clear", .system),
        library("disk usage top 20", "du -xhd 1 . | sort -hr | head -20", .complex),
        library("largest files", "find . -type f -print0 | xargs -0 du -h | sort -hr | head -20", .complex),
        library("disk summary", "df -h && echo && du -sh ~/* 2>/dev/null | sort -h", .complex),
        library("recent large logs", "find /var/log -type f -mtime -7 -size +1M -print | xargs ls -lh", .complex),
        library("list listening ports", "lsof -nP -iTCP -sTCP:LISTEN", .complex),
        library("top memory processes", "ps aux | sort -rk 4,4 | head -15", .complex),
        library("top cpu processes", "ps aux | sort -rk 3,3 | head -15", .complex),
        library("git branches merged", "git branch --merged | grep -v '\\*' | grep -v 'main' | grep -v 'master'", .complex),
        library("git recent authors", "git shortlog -sn --all | head -20", .complex),
        library("find TODO and FIXME", "rg -n \"TODO|FIXME|HACK|XXX\" .", .complex),
        library("json pretty from clipboard", "pbpaste | jq '.' | pbcopy", .complex),
        library("find duplicate files", "find . -type f -exec shasum {} + | sort", .complex),
        library("empty directories", "find . -type d -empty -print", .complex),
        library("ports in use summary", "netstat -anv | grep LISTEN", .complex),
        library("public ip", "curl -s https://ifconfig.me && echo", .complex),
        library("ssl certificate dates", "echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -dates", .complex),
        library("tail and filter errors", "tail -f app.log | grep --line-buffered -i \"error\\|warn\\|fatal\"", .complex),
        library("failed login history", "last | head -20", .complex),
        library("homebrew leaves", "brew leaves | sort", .complex),
        library("macOS battery and thermals", "pmset -g batt && echo && sudo powermetrics --samplers smc -n 1", .complex),
        library("largest directories under home", "du -xhd 1 ~ 2>/dev/null | sort -hr | head -20", .complex),
        library("largest files in downloads", "find ~/Downloads -type f -print0 | xargs -0 du -h 2>/dev/null | sort -hr | head -20", .complex),
        library("recently modified files", "find . -type f -mtime -2 | xargs ls -lt | head -30", .complex),
        library("files changed today", "find . -type f -newermt \"$(date +%F)\" -print | head -50", .complex),
        library("line counts by file type", "find . -type f \\( -name '*.swift' -o -name '*.ts' -o -name '*.js' \\) -print0 | xargs -0 wc -l | sort -nr | head -30", .complex),
        library("largest node modules folders", "find . -type d -name node_modules -prune -print0 | xargs -0 du -sh 2>/dev/null | sort -hr", .complex),
        library("git changed files by author", "git log --format='%an' --name-only --since='30 days ago' | awk 'NF==0{next} /^[^[:space:]]/{author=$0; next} {count[author]++} END {for (a in count) print count[a], a}' | sort -nr", .complex),
        library("git commits last 30 days", "git log --since='30 days ago' --oneline --decorate --graph", .complex),
        library("git files changed most", "git log --pretty=format: --name-only | sed '/^$/d' | sort | uniq -c | sort -nr | head -30", .complex),
        library("git unstaged summary", "git diff --name-only && echo && git diff --stat", .complex),
        library("git staged summary", "git diff --cached --name-only && echo && git diff --cached --stat", .complex),
        library("git deleted branches cleanup", "git fetch --prune && git branch -vv | grep ': gone]' | awk '{print $1}'", .complex),
        library("open pull request branch candidates", "git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(committerdate:relative)' | head -20", .complex),
        library("search secrets patterns", "rg -n --hidden --glob '!*.lock' --glob '!*.png' '(AKIA|SECRET_KEY|BEGIN RSA PRIVATE KEY|xoxb-|ghp_)' .", .complex),
        library("json logs pretty stream", "tail -f app.log | jq -R 'fromjson? // {message:.}'", .complex),
        library("extract error counts", "rg -o 'ERROR|WARN|FATAL' app.log | sort | uniq -c | sort -nr", .complex),
        library("top file extensions", "find . -type f | awk -F. 'NF>1 {print $NF}' | sort | uniq -c | sort -nr | head -20", .complex),
        library("empty files", "find . -type f -empty -print | head -50", .complex),
        library("symlinks report", "find . -type l -exec ls -l {} + | head -50", .complex),
        library("recent crash logs", "find ~/Library/Logs/DiagnosticReports -type f -mtime -7 | xargs ls -lt | head -20", .complex),
        library("processes listening with paths", "lsof -nP -iTCP -sTCP:LISTEN | awk 'NR==1 || /TCP/'", .complex),
        library("network connections by process", "lsof -i -nP | awk 'NR>1 {print $1}' | sort | uniq -c | sort -nr | head -20", .complex),
        library("dns trace", "dig +trace example.com", .complex),
        library("http timing breakdown", "curl -o /dev/null -s -w 'dns:%{time_namelookup} connect:%{time_connect} tls:%{time_appconnect} ttfb:%{time_starttransfer} total:%{time_total}\\n' https://example.com", .complex),
        library("ssl certificate subject and issuer", "echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -subject -issuer", .complex),
        library("top launch agents", "launchctl list | awk 'NR>1 {print $3}' | sort | head -50", .complex),
        library("brew size hogs", "du -sh /opt/homebrew/Cellar/* 2>/dev/null | sort -hr | head -20", .complex),
        library("login items and agents", "osascript -e 'tell application \"System Events\" to get the name of every login item' && echo && launchctl list | head -30", .complex),
        library("memory pressure snapshot", "memory_pressure && echo && vm_stat", .complex),
        library("zombie and defunct processes", "ps aux | awk '$8 ~ /Z/ || $11 ~ /defunct/ {print}'", .complex),
        library("docker containers summary", "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'", .complex),
        library("docker images largest", "docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | sort -k2 -hr | head -20", .complex),
        library("docker disk usage", "docker system df && echo && docker volume ls", .complex),
        library("docker compose logs errors", "docker compose logs --tail=200 | rg -i 'error|warn|fatal|exception'", .complex),
        library("docker exited containers", "docker ps -a --filter status=exited --format 'table {{.Names}}\\t{{.Status}}\\t{{.RunningFor}}'", .complex),
        library("node processes", "ps aux | rg 'node|npm|pnpm|yarn|vite|next|webpack' | rg -v rg", .complex),
        library("package scripts", "jq -r '.scripts // {} | to_entries[] | \"\\(.key): \\(.value)\"' package.json", .complex),
        library("largest npm dependencies", "jq -r '.dependencies // {} + .devDependencies // {} | keys[]' package.json | while read -r dep; do du -sh \"node_modules/$dep\" 2>/dev/null; done | sort -hr | head -20", .complex),
        library("typescript errors summary", "rg -n 'error TS[0-9]+' . | sed -E 's/.*(TS[0-9]+).*/\\1/' | sort | uniq -c | sort -nr", .complex),
        library("test files inventory", "find . -type f \\( -name '*test*' -o -name '*spec*' \\) | sed 's#^./##' | sort | head -100", .complex),
        library("python processes", "ps aux | rg 'python|uvicorn|gunicorn|pytest|jupyter' | rg -v rg", .complex),
        library("python packages top size", "du -sh .venv/lib/python*/site-packages/* 2>/dev/null | sort -hr | head -20", .complex),
        library("python import errors", "python -m compileall . 2>&1 | rg -i 'error|failed|exception'", .complex),
        library("pytest failure summary", "pytest -q 2>&1 | tee /tmp/pytest-output.log && echo && rg '=+ FAILURES =+|FAILED|ERROR' /tmp/pytest-output.log", .complex),
        library("swift package targets", "swift package dump-package | jq -r '.targets[].name'", .complex),
        library("swift files inventory", "find . -type f -name '*.swift' | sed 's#^./##' | sort | head -200", .complex),
        library("swift test failures summary", "swift test 2>&1 | tee /tmp/swift-test-output.log && echo && rg 'Test Case .* failed|error:' /tmp/swift-test-output.log", .complex),
        library("xcode derived data size", "du -sh ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null | sort -hr | head -20", .complex),
        library("build artifacts cleanup candidates", "find . \\( -name .build -o -name build -o -name DerivedData -o -name dist -o -name coverage \\) -prune -exec du -sh {} + 2>/dev/null | sort -hr", .complex),
        library("port 3000 ownership", "lsof -nP -iTCP:3000 -sTCP:LISTEN && echo && ps -p $(lsof -tiTCP:3000 -sTCP:LISTEN) -o pid,ppid,%cpu,%mem,command", .complex),
        library("open", "open .", .macos),
        library("open app", "open -a \"Visual Studio Code\" .", .macos),
        library("qlmanage", "qlmanage -p file.pdf", .macos),
        library("defaults read", "defaults read com.apple.finder", .macos),
        library("defaults write", "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder", .macos),
        library("system_profiler", "system_profiler SPHardwareDataType", .macos),
        library("diskutil list", "diskutil list", .macos),
        library("networksetup", "networksetup -listallhardwareports", .macos),
        library("scutil name", "scutil --get ComputerName", .macos),
        library("pmset", "pmset -g batt", .macos),
        library("screencapture", "screencapture -i ~/Desktop/capture.png", .macos),
        library("say", "say \"Build finished\"", .macos),
        library("tar create", "tar -czf archive.tar.gz folder/", .archives),
        library("tar extract", "tar -xzf archive.tar.gz", .archives),
        library("zip", "zip -r archive.zip folder/", .archives),
        library("unzip", "unzip archive.zip", .archives),
        library("gzip", "gzip large.log", .archives),
        library("gunzip", "gunzip large.log.gz", .archives),
        library("xz", "xz -z file.log", .archives),
        library("7z", "7z a archive.7z folder/", .archives),
        library("git status", "git status --short", .git),
        library("git branch", "git branch -vv", .git),
        library("git checkout", "git checkout -b feature/name", .git),
        library("git switch", "git switch main", .git),
        library("git fetch", "git fetch --all --prune", .git),
        library("git pull rebase", "git pull --rebase", .git),
        library("git log", "git log --oneline --graph --decorate -20", .git),
        library("git diff", "git diff --stat", .git),
        library("git blame", "git blame path/to/file", .git),
        library("git restore", "git restore path/to/file", .git),
        library("git stash", "git stash push -u -m \"wip\"", .git),
        library("git clean", "git clean -fd", .git),
        library("git show", "git show --stat --summary HEAD", .git),
        library("git cherry", "git cherry -v", .git),
        library("git reflog", "git reflog --date=relative | head -20", .git),
        library("git remote", "git remote -v", .git),
        library("brew install", "brew install wget", .homebrew),
        library("brew upgrade", "brew upgrade", .homebrew),
        library("brew outdated", "brew outdated", .homebrew),
        library("brew cleanup", "brew cleanup", .homebrew),
        library("brew services", "brew services list", .homebrew),
        library("brew info", "brew info node", .homebrew),
        library("brew search", "brew search python", .homebrew),
        library("brew doctor", "brew doctor", .homebrew),
        library("brew list versions", "brew list --versions", .homebrew),
        library("brew deps", "brew deps --tree node", .homebrew),
        library("brew uses", "brew uses --installed openssl@3", .homebrew),
        library("brew autoremove", "brew autoremove", .homebrew),
        library("brew cask list", "brew list --cask", .homebrew),
        library("mdfind kind pdf", "mdfind 'kMDItemKind == \"PDF document\"'", .search),
        library("sed lines", "sed -n '1,120p' file.txt", .text),
        library("uniq duplicates", "sort file.txt | uniq -d", .text),
        library("comm compare", "comm -3 <(sort file1.txt) <(sort file2.txt)", .text),
        library("xattr list", "xattr -lr file-or-folder", .macos),
        library("spctl assess", "spctl --assess --verbose /Applications/App.app", .macos),
        library("softwareupdate list", "softwareupdate --list", .macos),
    ]

    static var predefinedCommandCount: Int {
        predefinedCommands.count
    }

    static func normalizedCategories(_ categories: [QuickCommandCategory]) -> [QuickCommandCategory] {
        var seenIDs = Set<String>()
        var customCategories: [QuickCommandCategory] = []

        for category in categories.map(\.normalized) where !category.isBuiltIn {
            guard seenIDs.insert(category.id).inserted else { continue }
            customCategories.append(category)
        }

        return QuickCommandCategory.builtInCategories + customCategories
    }

    static func categoryMap(_ categories: [QuickCommandCategory]) -> [String: QuickCommandCategory] {
        Dictionary(uniqueKeysWithValues: normalizedCategories(categories).map { ($0.id, $0) })
    }

    static func resolvedCategory(
        id: String,
        in categories: [QuickCommandCategory]
    ) -> QuickCommandCategory {
        categoryMap(categories)[id] ?? QuickCommandCategory.builtInByID[id] ?? .fallbackCategory
    }

    static func visibleCategories(
        commands: [QuickCommandPreset],
        categories: [QuickCommandCategory]
    ) -> [QuickCommandCategory] {
        let categories = normalizedCategories(categories)
        let usedIDs = Set(commands.map(\.categoryID))
        return categories.filter { usedIDs.contains($0.id) }
    }

    static func normalizedCommands(
        _ commands: [QuickCommandPreset],
        categories: [QuickCommandCategory] = defaultCategories,
        reservedShortcuts: Set<StoredShortcut> = []
    ) -> [QuickCommandPreset] {
        var seenIDs = Set<String>()
        var seenShortcuts = reservedShortcuts
        let validCategoryIDs = Set(normalizedCategories(categories).map(\.id))

        return commands.compactMap { command in
            let normalizedCommand = command.normalizedCommand
            guard !normalizedCommand.isEmpty else { return nil }

            let normalizedID = command.id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? UUID().uuidString
            guard seenIDs.insert(normalizedID).inserted else { return nil }

            let normalizedShortcut: StoredShortcut?
            if let shortcut = command.shortcut, !shortcut.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               seenShortcuts.insert(shortcut).inserted {
                normalizedShortcut = shortcut
            } else {
                normalizedShortcut = nil
            }

            return QuickCommandPreset(
                id: normalizedID,
                title: command.normalizedTitle,
                command: normalizedCommand,
                categoryID: validCategoryIDs.contains(command.categoryID) ? command.categoryID : QuickCommandCategory.fallbackCategory.id,
                shortcut: normalizedShortcut,
                submitsReturn: command.submitsReturn
            )
        }
    }

    static func replacingCommand(
        _ updatedCommand: QuickCommandPreset,
        in commands: [QuickCommandPreset]
    ) -> [QuickCommandPreset] {
        commands.map { command in
            guard command.id != updatedCommand.id else { return updatedCommand }
            guard let updatedShortcut = updatedCommand.shortcut,
                  command.shortcut == updatedShortcut else {
                return command
            }

            var cleared = command
            cleared.shortcut = nil
            return cleared
        }
    }

    static func normalizedRecentCommandIDs(
        _ recentIDs: [String],
        availableCommands: [QuickCommandPreset]
    ) -> [String] {
        let validIDs = Set(availableCommands.map(\.id))
        var deduplicated: [String] = []
        var seenIDs = Set<String>()

        for id in recentIDs {
            guard validIDs.contains(id), seenIDs.insert(id).inserted else { continue }
            deduplicated.append(id)
            if deduplicated.count == maxRecentCount {
                break
            }
        }

        return deduplicated
    }

    static func isRecommendedComplexCommand(_ command: QuickCommandPreset) -> Bool {
        command.categoryID == QuickCommandCategory.complex.id &&
        recommendedComplexCommandIDs.contains(command.id)
    }

    static func sortedRecommendedComplexCommands(_ commands: [QuickCommandPreset]) -> [QuickCommandPreset] {
        let rank = Dictionary(uniqueKeysWithValues: recommendedComplexCommandOrder.enumerated().map { ($1, $0) })
        return commands.sorted { lhs, rhs in
            let lhsRank = rank[lhs.id] ?? Int.max
            let rhsRank = rank[rhs.id] ?? Int.max
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.normalizedTitle.localizedCaseInsensitiveCompare(rhs.normalizedTitle) == .orderedAscending
        }
    }
}

func lineyQuickCommandMatch(for event: NSEvent, in settings: AppSettings) -> QuickCommandPreset? {
    guard let recordedShortcut = StoredShortcut.from(event: event) else { return nil }
    return settings.quickCommandPresets.first(where: { $0.shortcut == recordedShortcut })
}

enum QuickCommandDispatch: Equatable {
    case insert(String)
    case run(String)
}

func lineyQuickCommandDispatch(for preset: QuickCommandPreset) -> QuickCommandDispatch {
    preset.submitsReturn ? .run(preset.command) : .insert(preset.command)
}

private extension QuickCommandCatalog {
    static func library(
        _ title: String,
        _ command: String,
        _ category: QuickCommandCategory
    ) -> QuickCommandPreset {
        QuickCommandPreset(
            id: "library-\(category.id)-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))",
            title: title,
            command: command,
            categoryID: category.id
        )
    }
}
