# Third-Party Licenses

AiyuTerm incorporates source code from the following open-source projects.
All notices below are preserved per their respective license terms.

---

## CodeIsland

- **Source**: https://github.com/wxtsky/CodeIsland
- **Version used as baseline**: main branch, snapshot taken 2026-04-10
- **License**: MIT
- **Copyright**: Copyright (c) 2026 wxtsky
- **Upstream attribution**: CodeIsland is itself inspired by
  [claude-island](https://github.com/farouqaldori/claude-island) by
  farouqaldori. That attribution chain is preserved here.

### Files derived from CodeIsland

The following AiyuTerm source files are direct adaptations of
CodeIsland sources. Each file carries an individual MIT attribution
header in addition to this aggregate notice.

| AiyuTerm file | CodeIsland source |
|---------------|-------------------|
| `AiyuTerm/Services/Agent/HookProtocol/AgentHookSocketPath.swift` | `Sources/CodeIslandCore/SocketPath.swift` |
| `AiyuTerm/Services/Agent/HookProtocol/AgentHookModels.swift` | `Sources/CodeIslandCore/Models.swift` |
| `AiyuTerm/Services/Agent/HookProtocol/AgentHookEventNormalizer.swift` | `Sources/CodeIslandCore/EventNormalizer.swift` |
| `AiyuTerm/Services/Agent/HookProtocol/AgentSessionSnapshot.swift` | `Sources/CodeIslandCore/SessionSnapshot.swift` |

Further files are expected to be added in later phases of the integration:

| Future AiyuTerm file (phase) | CodeIsland source |
|------------------------------|-------------------|
| `AiyuTerm/Services/Agent/Transport/AgentHookServer.swift` (Phase 2) | `Sources/CodeIsland/HookServer.swift` |
| `AiyuTermHookBridge/main.swift` (Phase 2) | `Sources/CodeIslandBridge/main.swift` |
| `AiyuTerm/Services/Agent/Installer/AgentCLIConfigInstaller.swift` (Phase 5) | `Sources/CodeIsland/ConfigInstaller.swift` |
| `AiyuTerm/UI/NotchPanel/*.swift` (Phase 8) | `Sources/CodeIsland/NotchPanelView.swift`, `PanelWindowController.swift`, `ScreenDetector.swift`, `IslandCollapsedView.swift`, `IslandExpandedView.swift`, `IslandPixelAnimation.swift` |

Each phase will add an entry to this table as the corresponding files
land on the `feat/codeisland-integration` branch.

### MIT License text

```
MIT License

Copyright (c) 2026 wxtsky

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
