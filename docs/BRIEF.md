# Portzilla — build spec

A macOS menu bar app for listing and killing processes bound to local ports.

Target audience for this document: an AI coding agent (Claude Code, Cursor, etc.). Every requirement is explicit. Build to spec; do not invent features.

---

## 1. What it is

- Lives in the macOS menu bar (top-right system tray)
- Icon shows live count of TCP ports in `LISTEN` state owned by the current user
- Click icon (or press global hotkey) → dropdown opens
- Dropdown lists every listening port: port number, process name, PID, command
- Each row has a kill button → terminates the process
- Filter box searches by port/PID/name/command
- "Kill all dev ports" button kills every user-owned process in one go

Why it exists: developers hit `EADDRINUSE` constantly. Current workaround is `lsof -i :8081` → copy PID → `kill -9 <pid>`. Portzilla collapses that into one click.

---

## 2. Stack & requirements

| Thing | Choice | Reason |
|---|---|---|
| Language | Swift 5.9+ | macOS native |
| UI | SwiftUI | Declarative, `MenuBarExtra` is SwiftUI-only |
| Min macOS | 13.0 (Ventura) | `MenuBarExtra` API |
| Build system | Swift Package Manager | No Xcode project file in repo; works in VS Code too |
| Bundle ID | `com.palora.portzilla` | |
| App name | Portzilla | |
| Dependencies | `KeyboardShortcuts` (sindresorhus, MIT) | Global hotkey API |

Do not add other dependencies without a reason.

---

## 3. Project structure

```
portzilla/
├── Package.swift
├── Makefile
├── README.md
├── .gitignore
├── Sources/
│   └── Portzilla/
│       ├── PortzillaApp.swift
│       ├── AppState.swift
│       ├── Models/
│       │   └── PortInfo.swift
│       ├── Services/
│       │   ├── PortService.swift
│       │   ├── ProcessRunner.swift
│       │   └── HotkeyManager.swift
│       └── Views/
│           ├── PortListView.swift
│           ├── PortRowView.swift
│           ├── HeaderView.swift
│           ├── SearchBarView.swift
│           ├── FooterView.swift
│           └── EmptyStateView.swift
├── Resources/
│   └── AppIcon.png
└── Tests/
    └── PortzillaTests/
        ├── LsofParserTests.swift
        └── PortServiceTests.swift
```

Use SwiftPM executable target with `MenuBarExtra` style. App must build with `swift build` and run with `swift run`.

---

## 4. Data model

### `PortInfo`

```swift
struct PortInfo: Identifiable, Hashable {
    let id: String              // "{pid}:{port}" — composite key
    let port: Int               // e.g. 8081
    let pid: Int32              // process ID
    let processName: String     // e.g. "node"
    let command: String         // full command line, e.g. "next dev"
    let user: String            // owning user, e.g. "priscilla"
    let isOwnedByCurrentUser: Bool
}
```

Sort order: by `port` ascending.

---

## 5. Services

### 5.1 `ProcessRunner.swift`

Generic shell-out helper. One static function:

```swift
static func run(_ path: String, args: [String], timeout: TimeInterval = 5) throws -> (stdout: String, stderr: String, exitCode: Int32)
```

- Uses `Foundation.Process`
- Captures stdout and stderr separately via `Pipe`
- Times out and terminates the process if it exceeds `timeout`
- Sets `PATH` to include `/usr/sbin:/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin`
- Throws `ProcessRunnerError.timeout` or `.launchFailed(Error)`

### 5.2 `PortService.swift`

Owns all `lsof` and `kill` logic. Two public methods:

```swift
func listListeningPorts() async throws -> [PortInfo]
func kill(pid: Int32, force: Bool) throws
```

#### `listListeningPorts`

1. Run `/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN -F pcnLP`
2. Parse output (see parser spec below)
3. Dedupe by `(pid, port)` — same process can bind multiple times
4. Return sorted by `port` ascending

#### `lsof -F` output format

`lsof -F pcnLP` outputs records line-by-line, one field per line, each prefixed by a single character:
- `p` = PID
- `c` = command name (max 15 chars, truncated)
- `L` = login/user name
- `f` = file descriptor (start of a new file record)
- `P` = protocol (TCP/UDP)
- `n` = name field (e.g. `*:8081`, `127.0.0.1:3000`, `[::1]:5432`)

Records group by process: a `p` line starts a process block, followed by `c` and `L`, then one or more file blocks each starting with `f`. Implementation must track current pid/command/user across `f` blocks.

Example output:
```
p47291
cnode
Lpriscilla
f24
PTCP
n*:3000
f25
PTCP
n127.0.0.1:8081
```
→ yields two `PortInfo` rows (port 3000, port 8081), both pid 47291, command "node".

Parse `n` field for port:
- `*:3000` → port 3000
- `127.0.0.1:8081` → port 8081
- `[::1]:5432` → port 5432
- IPv6 with zone (`[fe80::1%lo0]:80`) → strip zone, port 80
- If no colon or non-numeric port, skip the row

#### Getting the full command line

`lsof`'s `c` field truncates to 15 chars. For the full command, look up the process via `/bin/ps`:

```
/bin/ps -p <pid> -o command=
```

Run this per unique PID (not per row). Cache results within a single `listListeningPorts` call. If `ps` fails or times out for a PID, fall back to the `lsof` `c` value.

#### Owned-by-current-user check

Compare `PortInfo.user` against the current user. Get current user via `NSUserName()` or `ProcessInfo.processInfo.userName`.

#### `kill(pid: Int32, force: Bool)`

- If `force == false`: send SIGTERM via `Foundation.kill(pid, SIGTERM)` (use the C API via `Darwin`)
- If `force == true`: send SIGKILL
- Public caller flow: send SIGTERM, wait 1.0s, check if process still exists (via `kill(pid, 0)`), if yes send SIGKILL
- If `kill` returns -1 with `errno == EPERM`, throw `PortServiceError.permissionDenied` — caller should not retry, should surface a UI affordance for root-owned ports (see 6.4 below)
- If `errno == ESRCH`, treat as success (process already gone)

### 5.3 `HotkeyManager.swift`

Wraps `KeyboardShortcuts` package.

```swift
extension KeyboardShortcuts.Name {
    static let togglePortzilla = Self("togglePortzilla", default: .init(.p, modifiers: [.control, .option]))
}
```

Default hotkey: `⌃⌥P`. User-configurable later (out of scope v1).

Wire in `PortzillaApp.init()`:
```swift
KeyboardShortcuts.onKeyUp(for: .togglePortzilla) {
    AppState.shared.togglePopover()
}
```

---

## 6. UI spec

### 6.1 Reference

The mockup shown in chat is the source of truth for layout and behavior. SwiftUI must render the equivalent visually. Key dimensions below.

### 6.2 Menu bar icon

- Use SF Symbol `powerplug` or `network` (pick `powerplug` — better visual match for "port")
- Append the listening-port count as a label: `Image(systemName: "powerplug") + Text("\(count)")`
- Count refreshes every 5 seconds while popover is closed (timer), and on demand when popover opens
- If count == 0, show icon only (no number)

### 6.3 Popover (`MenuBarExtra` window)

Fixed width: **420pt**. Height: auto, max 520pt with internal scroll on the list.

Layout, top to bottom:

1. **Header** (`HeaderView`) — 44pt tall, bottom 0.5pt divider
   - Left: SF Symbol `powerplug` (13pt) + "Portzilla" (13pt, `.medium`)
   - Right: ⌃⌥P pill (11pt, monospaced, secondary bg), refresh button (`arrow.clockwise`), settings button (`gearshape`)
2. **Search bar** (`SearchBarView`) — 46pt tall, bottom 0.5pt divider
   - Single `TextField` with placeholder "Filter by port, PID, or process…"
   - Magnifying-glass icon on the left
   - Filters the list in real time (case-insensitive substring match against `String(port)`, `String(pid)`, `processName`, `command`)
3. **List** (`PortListView`) — scrollable, each row 52pt tall
   - Empty state: when no ports match filter, show centered `EmptyStateView` with `face.smiling` icon and text "No ports match." (filtered) or "No listening ports." (unfiltered)
4. **Footer** (`FooterView`) — 40pt tall, top 0.5pt divider, secondary bg
   - Left: "{count} listening port(s)" (12pt, secondary)
   - Right: "Kill all dev ports" button (red on hover) — calls `killAllDevPorts()` (see 6.5)
   - Below footer, a thin "Quit Portzilla" row at the bottom (10pt padding, 12pt secondary text, click → `NSApp.terminate(nil)`)

### 6.4 `PortRowView`

Grid: `[port: 64pt] [process+command: flex] [pid: 78pt] [kill button: 70pt]`

- **Port**: `:{port}` in monospaced 13pt, accent color (blue)
- **Process**: `{processName}` in 13pt medium, with `{command}` below in monospaced 11pt tertiary (single line, truncate with ellipsis, `.help()` tooltip shows full command)
- **PID**: `PID {pid}` in monospaced 12pt secondary
- **Kill button**: capsule, 26pt tall, x-mark icon + "Kill" text
  - Hover state: red background, red text, red border
  - If `isOwnedByCurrentUser == false`: button shows lock icon instead of x-mark, label "Kill"; tapping it shows a confirmation that running as another user requires sudo — v1 surfaces an alert "Cannot kill {user}'s process. Run with elevated permissions to terminate root-owned ports." Do not attempt privileged escalation in v1.

Click row background: highlight in `secondaryBackground` color.

### 6.5 Kill flows

- **Single kill**: call `PortService.kill(pid:force:false)`. On success, optimistically remove row, show a transient toast "Killed {name} on :{port}". Refresh list after 300ms to reconcile. If kill fails, show alert with `error.localizedDescription`.
- **Kill all dev ports**: filter list to `isOwnedByCurrentUser == true && pid != getpid()` (don't kill self), iterate, kill each. Show summary toast "Killed N processes".

### 6.6 Refresh

- Refresh button (header) → re-runs `listListeningPorts()`, replaces state
- Show a small spinning indicator overlaying the refresh button while in flight
- Debounce: ignore taps within 200ms of previous

### 6.7 Toast

Bottom-overlay pill, dark background, white text, 12pt, auto-dismiss after 1.6s. Implement as a `@State` message on the popover with `.transition(.opacity)`.

### 6.8 Colors & spacing

Use SwiftUI semantic colors (`.primary`, `.secondary`, `.tertiary`, `Color(NSColor.controlBackgroundColor)`, `Color(NSColor.windowBackgroundColor)`). Do not hardcode hex. Must respect light/dark mode.

Border thickness: 0.5pt everywhere. Corner radius: 6pt for buttons/inputs, 8pt for the popover itself.

---

## 7. App state

Single `@Observable` (or `@MainActor class … : ObservableObject`) shared instance:

```swift
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var ports: [PortInfo] = []
    @Published var filter: String = ""
    @Published var isLoading: Bool = false
    @Published var toast: String? = nil
    @Published var isPopoverOpen: Bool = false

    var filteredPorts: [PortInfo] { ... }
    var listeningCount: Int { ports.count }

    func refresh() async { ... }
    func kill(_ port: PortInfo) async { ... }
    func killAllDevPorts() async { ... }
    func togglePopover() { ... }
    func showToast(_ message: String) { ... }
}
```

`AppState` owns a `PortService` instance and a `Timer` for the 5-second background refresh.

---

## 8. App entry point

```swift
@main
struct PortzillaApp: App {
    @StateObject private var state = AppState.shared

    init() {
        HotkeyManager.register()
    }

    var body: some Scene {
        MenuBarExtra {
            PortListView()
                .environmentObject(state)
                .frame(width: 420)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "powerplug")
                if state.listeningCount > 0 {
                    Text("\(state.listeningCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
```

`.window` style (not `.menu`) — gives us a custom popover, not a native NSMenu.

---

## 9. Edge cases & error handling

| Case | Behavior |
|---|---|
| `lsof` not found | Show alert "lsof not available — Portzilla requires macOS system tools." |
| `lsof` timeout (>5s) | Cancel, show toast "Refresh timed out." |
| Kill returns EPERM | Show alert per 6.4 — do not crash |
| Kill returns ESRCH | Treat as success, refresh list |
| Process bound to multiple ports | Show as separate rows |
| IPv6-only listener | Parse `[::1]:port` correctly; show same as IPv4 |
| Wildcard listener (`*:port`) | Show with port only |
| Same port across IPv4 and IPv6 by same PID | Dedupe to single row |
| Search query is purely whitespace | Treat as empty, show all |
| User hits ⌃⌥P while popover is open | Close popover |
| Popover open and user clicks outside | Close popover (default `MenuBarExtra` behavior) |
| `ps` lookup fails for a PID | Fall back to `lsof` truncated `c` value |
| Self-kill attempt (`pid == getpid()`) | Silently skip in "kill all"; disable button for own row |

---

## 10. Tests

Unit tests required (no UI tests in v1):

### `LsofParserTests.swift`
- Empty input → empty array
- Single process, single port → one row
- Single process, multiple ports → multiple rows with same pid
- IPv6 `[::1]:port` → parsed correctly
- IPv6 with zone `[fe80::1%lo0]:80` → port 80
- Wildcard `*:port` → parsed correctly
- Malformed line (missing colon) → skipped, doesn't crash
- Multi-process output → all parsed
- Truncated command name → preserved as-is

### `PortServiceTests.swift`
- Mock `ProcessRunner` to return canned `lsof` output, assert `listListeningPorts()` returns expected `[PortInfo]`
- Sort order: ascending by port
- Dedupe: same (pid, port) deduplicated
- `isOwnedByCurrentUser` set correctly

Use `XCTest`. Run with `swift test`.

---

## 11. Build, run, distribute

### Makefile targets

```make
run:        # swift run Portzilla
build:      # swift build -c release
test:       # swift test
clean:      # rm -rf .build
bundle:     # Create .app bundle from .build/release/Portzilla — see below
```

### `.app` bundle

SwiftPM produces a bare executable, not a `.app`. The `bundle` target must:

1. Build release binary: `swift build -c release`
2. Create `Portzilla.app/Contents/MacOS/Portzilla` (copy binary)
3. Generate `Portzilla.app/Contents/Info.plist` with:
   - `CFBundleIdentifier` = `com.palora.portzilla`
   - `CFBundleName` = `Portzilla`
   - `CFBundleShortVersionString` = `0.1.0`
   - `LSUIElement` = `<true/>` (no dock icon — menu bar only)
   - `LSMinimumSystemVersion` = `13.0`
4. Copy `Resources/AppIcon.png` (or `.icns`) to `Portzilla.app/Contents/Resources/`

### Signing (v1: ad-hoc only)

```sh
codesign --force --deep --sign - Portzilla.app
```

User will need to right-click → Open the first time to bypass Gatekeeper. Notarization is out of scope for v1.

### Login item

v1: user manually adds to Login Items via System Settings.
v2 (not now): use `SMAppService.mainApp.register()`.

---

## 12. README requirements

Generate a README.md with:
- One-paragraph description
- Screenshot placeholder (`![Portzilla](docs/screenshot.png)`)
- Requirements (macOS 13+, Swift 5.9+)
- Quick start: `git clone && swift run`
- How to build `.app`: `make bundle`
- How to set login item
- Hotkey: ⌃⌥P
- License: MIT

---

## 13. Acceptance criteria

The build is done when all of these pass:

- [ ] `swift build` succeeds with no warnings on macOS 13+
- [ ] `swift test` passes all unit tests
- [ ] `swift run Portzilla` launches the app; icon appears in menu bar with port count
- [ ] Clicking the icon opens a 420pt-wide popover matching the mockup layout
- [ ] Pressing ⌃⌥P from any app toggles the popover
- [ ] List populates with all current listening TCP ports
- [ ] Search filters live across port, PID, name, command
- [ ] Kill button on a user-owned port terminates it within 2s; row disappears
- [ ] Root-owned ports show locked state and surface a clear alert on click
- [ ] Refresh button re-fetches list
- [ ] "Kill all dev ports" terminates every user-owned process and shows a count toast
- [ ] "Quit Portzilla" exits cleanly
- [ ] Light mode and dark mode both render correctly
- [ ] `make bundle` produces a runnable `.app`

---

## 14. Out of scope (v1)

Do not build these even if they seem useful:

- UDP ports
- Remote port scanning
- Process tree visualization
- Privileged helper for root-owned kills (just surface the alert)
- Settings window (hotkey is hardcoded in code for v1; comment says "user-configurable in v2")
- Auto-launch at login UI (rely on user manually setting it)
- Notifications outside the popover
- Telemetry / analytics
- App Store distribution

---

## 15. Implementation order

Build in this order. Each step compiles before moving on.

1. `Package.swift` + empty `PortzillaApp.swift` that opens an empty `MenuBarExtra` — verify menu bar icon appears
2. `Models/PortInfo.swift`
3. `Services/ProcessRunner.swift` + tests
4. `Services/PortService.swift` lsof parsing + tests (mocked runner)
5. `AppState.swift` wired to `PortService` — print results to console first
6. `Views/PortRowView.swift` + `Views/PortListView.swift` — basic rendering
7. `HeaderView.swift`, `SearchBarView.swift`, `FooterView.swift`, `EmptyStateView.swift`
8. Wire filter, refresh, kill flows
9. `HotkeyManager.swift` + `KeyboardShortcuts` dependency
10. Background 5s refresh timer
11. Toast overlay
12. Makefile + `.app` bundle target
13. README

---

## 16. Style guide

- Swift naming: standard Apple conventions (`camelCase`, types in `PascalCase`)
- One type per file
- No force-unwraps (`!`) outside tests
- `async`/`await` over completion handlers
- `@MainActor` on all view-touching code
- Comments only where the *why* isn't obvious from the code; do not narrate the *what*
- No third-party UI libraries — SwiftUI primitives only