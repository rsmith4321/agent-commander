// Agent Commander: a menu bar launcher for AI coding agents.
//
// Pick a project, then one of its saved routines. Terminal opens in the
// project's folder with your chosen agent (Claude Code, Codex, or anything
// you add) already working on the routine's prompt, so you can watch it and
// answer its questions. Nothing runs on a schedule or in the background.
//
// Settings live in ~/.config/agent-commander/config.json (written with an
// example on first run). Build with ./build.sh.

import AppKit
import ServiceManagement

let appName = "Agent Commander"
let projectURL = "https://github.com/rsmith4321/agent-commander"

// MARK: - Config

struct Routine {
    let title: String
    let folder: String
    let prompt: String?     // nil = ask for text when picked
    let question: String?   // optional wording for that question
    let project: String?    // the project it belongs to, if any
    let agent: String?      // always use this agent instead of the selected one
    let confirm: String?    // ask this before starting
}

indirect enum MenuEntry {
    case routine(Routine)
    case separator
    case header(String)
    case submenu(String, [MenuEntry])
}

struct Agent {
    let name: String
    let command: String
}

struct Project {
    let name: String
    let routines: [MenuEntry]
}

struct Config {
    let agents: [Agent]
    let defaultAgent: String?
    let projects: [Project]
    let routines: [MenuEntry]   // routines outside any project
    let icon: String?
}

struct ConfigError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ConfigFile {
    // AGENT_COMMANDER_CONFIG points at a different config file (handy for testing).
    static let url = ProcessInfo.processInfo.environment["AGENT_COMMANDER_CONFIG"]
        .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/agent-commander/config.json")
    static let folder = url.deletingLastPathComponent()
    static let readmeURL = folder.appendingPathComponent("README.md")

    /// Writes the example config and its README the first time the app runs.
    static func createIfMissing() {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for (target, resource) in [(url, "example-config"), (readmeURL, "config-README")] {
            guard !fm.fileExists(atPath: target.path) else { continue }
            let ext = resource == "example-config" ? "json" : "md"
            if let source = Bundle.main.url(forResource: resource, withExtension: ext) {
                try? fm.copyItem(at: source, to: target)
            }
        }
    }

    static func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    static func load() throws -> Config {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw ConfigError(message: "Can't read \(url.path).")
        }
        let json: Any
        do { json = try JSONSerialization.jsonObject(with: data) } catch {
            let detail = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
            throw ConfigError(message: "config.json isn't valid JSON.\n\n\(detail)\n\nCommon causes: a missing comma, a missing quote, or curly quotes (“ ”) instead of straight ones.")
        }
        guard let root = json as? [String: Any] else {
            throw ConfigError(message: "config.json should be one object: { \"agents\": [...], \"projects\": [...] }.")
        }
        guard let agentList = root["agents"] as? [Any], !agentList.isEmpty else {
            throw ConfigError(message: "config.json needs an \"agents\" list with at least one agent.")
        }
        var agents: [Agent] = []
        for (i, value) in agentList.enumerated() {
            let place = "agent \(i + 1)"
            guard let obj = value as? [String: Any] else {
                throw ConfigError(message: "\(place) should be an object with \"name\" and \"command\".")
            }
            guard let name = nonEmpty(obj["name"]) else {
                throw ConfigError(message: "\(place) needs a \"name\".")
            }
            guard let command = nonEmpty(obj["command"]) else {
                throw ConfigError(message: "Agent \"\(name)\" needs a \"command\", for example \"claude\" or a full path.")
            }
            agents.append(Agent(name: name, command: command))
        }
        let names = Set(agents.map(\.name))
        let defaultAgent = nonEmpty(root["defaultAgent"])
        if let d = defaultAgent, !names.contains(d) {
            throw ConfigError(message: "\"defaultAgent\" is \"\(d)\", but there's no agent with that name.")
        }

        guard let projectList = (root["projects"] ?? []) as? [Any] else {
            throw ConfigError(message: "\"projects\" should be a list in square brackets.")
        }
        var projects: [Project] = []
        for (i, value) in projectList.enumerated() {
            guard let obj = value as? [String: Any], let name = nonEmpty(obj["name"]) else {
                throw ConfigError(message: "project \(i + 1) needs a \"name\".")
            }
            let folder = nonEmpty(obj["folder"]) ?? "~"
            projects.append(Project(name: name, routines: try parseEntries(obj["routines"] ?? [], where: name,
                                                                           folder: folder, project: name, agents: names)))
        }
        let loose = try parseEntries(root["routines"] ?? [], where: "routines", folder: "~", project: nil, agents: names)
        return Config(agents: agents, defaultAgent: defaultAgent, projects: projects, routines: loose,
                      icon: nonEmpty(root["menuBarIcon"]))
    }

    static func parseEntries(_ value: Any, where place: String, folder: String, project: String?,
                             agents: Set<String>) throws -> [MenuEntry] {
        guard let list = value as? [Any] else {
            throw ConfigError(message: "The routines for \"\(place)\" should be a list in square brackets.")
        }
        return try list.enumerated().map { i, item in
            let spot = "item \(i + 1) of \(place)"
            if let s = item as? String, s.allSatisfy({ $0 == "-" }) { return .separator }
            guard let obj = item as? [String: Any] else {
                throw ConfigError(message: "\(spot) should be an object, or \"-\" for a separator line.")
            }
            if obj["separator"] as? Bool == true { return .separator }
            if let header = nonEmpty(obj["header"]) { return .header(header) }
            if let name = nonEmpty(obj["submenu"]) {
                return .submenu(name, try parseEntries(obj["routines"] ?? [], where: name, folder: folder,
                                                       project: project, agents: agents))
            }
            guard let title = nonEmpty(obj["title"]) else {
                throw ConfigError(message: "\(spot) needs a \"title\".")
            }
            let prompt: String?
            switch obj["prompt"] {
            case nil, is NSNull: prompt = nil
            case let s as String: prompt = s.isEmpty ? nil : s
            default: throw ConfigError(message: "The prompt for \"\(title)\" should be text in quotes, or null to ask each time.")
            }
            let agent = nonEmpty(obj["agent"])
            if let agent, !agents.contains(agent) {
                throw ConfigError(message: "\"\(title)\" asks for the agent \"\(agent)\", but there's no agent with that name.")
            }
            return .routine(Routine(title: title,
                                    folder: nonEmpty(obj["folder"]) ?? folder,
                                    prompt: prompt,
                                    question: nonEmpty(obj["question"]),
                                    project: project,
                                    agent: agent,
                                    confirm: nonEmpty(obj["confirm"])))
        }
    }

    static func nonEmpty(_ value: Any?) -> String? {
        guard let s = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }
}

// MARK: - Launching

/// Single-quotes text for a POSIX shell: 'it'\''s' and so on.
func shellQuote(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func expandFolder(_ path: String) -> String {
    var p = path
    if p.hasPrefix("$HOME") { p = "~" + p.dropFirst(5) }
    return (p as NSString).expandingTildeInPath
}

/// Asks a login shell whether the agent's command exists, the same way
/// Terminal will see it. Returns nil when the check itself can't run.
func commandExists(_ command: String) -> Bool? {
    let shell = ProcessInfo.processInfo.environment["SHELL"].flatMap { $0.hasSuffix("zsh") || $0.hasSuffix("bash") ? $0 : nil } ?? "/bin/zsh"
    let p = Process()
    p.executableURL = URL(fileURLWithPath: shell)
    // eval expands $HOME and ~, then we check only the first word.
    p.arguments = ["-lic", "eval \"set -- $1\" 2>/dev/null && command -v -- \"$1\" >/dev/null", appName, command]
    p.standardInput = FileHandle.nullDevice
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    let deadline = Date().addingTimeInterval(15)
    while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
    if p.isRunning { p.terminate(); return nil }
    return p.terminationStatus == 0
}

/// Writes a one-shot .command script and opens it in Terminal. Opening a
/// .command file needs no Automation permission. The script deletes itself.
func openInTerminal(agent: Agent, routine: Routine, prompt: String) throws {
    let folder = expandFolder(routine.folder)
    let quoted = shellQuote(prompt)
    let command = agent.command.contains("{prompt}")
        ? agent.command.replacingOccurrences(of: "{prompt}", with: quoted)
        : agent.command + " " + quoted
    let id = String(UUID().uuidString.prefix(8))
    var info: [String: String] = ["title": routine.title, "agent": agent.name]
    info["project"] = routine.project
    let infoJSON = String(data: try JSONSerialization.data(withJSONObject: info), encoding: .utf8)!
    let script = """
    #!/bin/zsh -l
    rm -f -- "$0"
    \(Running.scriptPrologue(id: id, info: infoJSON))
    cd -- \(shellQuote(folder)) || { echo; echo \(shellQuote("\(appName) can't open the folder \(folder). Is the drive connected?")); read -k 1; exit 1; }
    clear
    printf '%s\\n%s\\n\\n' \(shellQuote("\(appName): " + [agent.name, routine.project, routine.title].compactMap { $0 }.joined(separator: " · "))) \(shellQuote("Folder: \(folder)"))
    \(command)
    code=$?
    \(Running.scriptEpilogue)
    if (( code == 127 )); then
      echo
      echo \(shellQuote("\(appName) couldn't find the \(agent.name) command. Open the menu, choose Edit routines…, and put the full path in \"command\"."))
    fi
    exit $code
    """
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-commander-\(id).command")
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
    NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
}

// MARK: - App

final class RoutineBox: NSObject {
    let routine: Routine
    init(_ routine: Routine) { self.routine = routine }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var config: Config?
    var loadError: String?
    var loadedDate: Date?
    var found: [String: Bool] = [:]   // agent command -> exists on PATH
    var running: [RunningTask] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigFile.createIfMissing()
        applyLoginArgument()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        reload()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refreshRunning() }
        RunLoop.main.add(timer, forMode: .common)
        #if SCREENSHOT
        screenshotHarness(self)
        #endif
    }

    // Picks up edits to config.json each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        running = Running.list()
        if ConfigFile.modificationDate() != loadedDate { reload() } else { rebuildMenu() }
        updateIcon()
    }

    /// Polls the running folder so the menu bar icon shows when agents are working.
    func refreshRunning() {
        let now = Running.list()
        guard now.map(\.id) != running.map(\.id) else { return }
        running = now
        updateIcon()
        rebuildMenu()
    }

    func updateIcon() {
        let busy = !running.isEmpty
        let symbol = config?.icon.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: appName) }
        statusItem.button?.image = symbol ?? Glyph.menuBarImage(running: busy)
        statusItem.button?.imagePosition = .imageLeading
        // The "A" turns its spark into a dot while busy; a custom symbol can't, so it shows the count.
        statusItem.button?.title = running.count > 1 || (busy && symbol != nil) ? "\(running.count)" : ""
        statusItem.button?.toolTip = busy ? "\(appName): \(running.count) running" : appName
    }

    @objc func reloadClicked(_ sender: Any?) { reload() }

    func reload() {
        loadedDate = ConfigFile.modificationDate()
        do {
            config = try ConfigFile.load()
            loadError = nil
        } catch {
            config = nil
            loadError = error.localizedDescription
        }
        running = Running.list()
        updateIcon()
        rebuildMenu()
        checkAgents()
    }

    func checkAgents() {
        guard let agents = config?.agents else { return }
        let commands = Set(agents.map(\.command)).filter { found[$0] == nil }
        guard !commands.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async {
            var results: [String: Bool] = [:]
            for c in commands { if let ok = commandExists(c) { results[c] = ok } }
            DispatchQueue.main.async {
                self.found.merge(results) { $1 }
                self.rebuildMenu()
            }
        }
    }

    func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        if !running.isEmpty {
            addHeader("Running", to: menu)
            for task in running {
                let item = NSMenuItem(title: "\(task.title) (\(task.agent), \(Running.elapsed(since: task.started)))",
                                      action: nil, keyEquivalent: "")
                let sub = NSMenu()
                if let project = task.project { addHeader(project, to: sub) }
                let stop = actionItem("Stop", #selector(stopTask(_:)))
                stop.representedObject = task.id
                sub.addItem(stop)
                item.submenu = sub
                menu.addItem(item)
            }
            if running.count > 1 { menu.addItem(actionItem("Stop all", #selector(stopAll))) }
            menu.addItem(.separator())
        }
        if loadError != nil {
            let item = NSMenuItem(title: "⚠︎ Problem in config.json. Click for details", action: #selector(showLoadError), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        } else if let config {
            if config.projects.count == 1 && config.routines.isEmpty, let project = config.projects.first {
                addHeader(project.name, to: menu)
                add(project.routines, to: menu)
            } else {
                for project in config.projects {
                    let item = NSMenuItem(title: project.name, action: nil, keyEquivalent: "")
                    let sub = NSMenu()
                    add(project.routines, to: sub)
                    if project.routines.isEmpty { addHeader("No routines yet", to: sub) }
                    item.submenu = sub
                    menu.addItem(item)
                }
                add(config.routines, to: menu)
            }
            if config.projects.isEmpty && config.routines.isEmpty { addHeader("No routines yet", to: menu) }
            if config.agents.count > 1 {
                menu.addItem(.separator())
                addHeader("Agent", to: menu)
                let selected = selectedAgent(in: config)
                for agent in config.agents {
                    let item = actionItem(agentTitle(agent), #selector(selectAgent(_:)))
                    item.representedObject = agent.name
                    item.state = agent.name == selected.name ? .on : .off
                    menu.addItem(item)
                }
            }
        }
        menu.addItem(.separator())
        menu.addItem(actionItem("Edit routines…", #selector(editConfig), key: ","))
        menu.addItem(actionItem("Reload", #selector(reloadClicked), key: "r"))
        let login = actionItem("Open at login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(actionItem("About \(appName)", #selector(openProjectPage)))
        menu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    func agentTitle(_ agent: Agent) -> String {
        found[agent.command] == false ? "\(agent.name) (not found)" : agent.name
    }

    /// The agent picked in the menu, else "defaultAgent", else the first one.
    func selectedAgent(in config: Config) -> Agent {
        let saved = UserDefaults.standard.string(forKey: "selectedAgent")
        return config.agents.first { $0.name == saved }
            ?? config.agents.first { $0.name == config.defaultAgent }
            ?? config.agents[0]
    }

    @objc func selectAgent(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.representedObject as? String, forKey: "selectedAgent")
        rebuildMenu()
    }

    func add(_ entries: [MenuEntry], to menu: NSMenu) {
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())
            case .header(let text):
                addHeader(text, to: menu)
            case .submenu(let name, let children):
                let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                let sub = NSMenu()
                add(children, to: sub)
                item.submenu = sub
                menu.addItem(item)
            case .routine(let routine):
                let title = routine.agent.map { "\(routine.title) (\($0))" } ?? routine.title
                let item = actionItem(title, #selector(run(_:)))
                item.representedObject = RoutineBox(routine)
                item.toolTip = routine.prompt.map { "\(expandFolder(routine.folder))\n\n\($0)" } ?? expandFolder(routine.folder)
                menu.addItem(item)
            }
        }
    }

    func addHeader(_ text: String, to menu: NSMenu) {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: Actions

    @objc func run(_ sender: NSMenuItem) {
        guard let routine = (sender.representedObject as? RoutineBox)?.routine, let config else { return }
        let agent = config.agents.first { $0.name == routine.agent } ?? selectedAgent(in: config)
        var isDir: ObjCBool = false
        let folder = expandFolder(routine.folder)
        guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDir), isDir.boolValue else {
            alert("Can't find the folder for “\(routine.title)”",
                  "\(folder)\n\nIf it's on an external drive, connect the drive and try again. Otherwise fix \"folder\" with Edit routines….",
                  offerEdit: true)
            return
        }
        if found[agent.command] == false {
            let choice = alert("\(agent.name) wasn't found",
                               "Agent Commander couldn't find the command “\(agent.command)” in your shell. Install it, or put its full path in \"command\" with Edit routines….",
                               buttons: ["Try Anyway", "Edit routines…", "Cancel"])
            if choice == .alertSecondButtonReturn { editConfig() }
            if choice != .alertFirstButtonReturn { return }
            found[agent.command] = nil   // check again next time
        }
        if let question = routine.confirm {
            let choice = alert(question, "\(routine.title) · \(agent.name)", buttons: ["Start", "Cancel"])
            guard choice == .alertFirstButtonReturn else { return }
        }
        guard let prompt = routine.prompt ?? ask(agent: agent, routine: routine) else { return }
        do {
            try openInTerminal(agent: agent, routine: routine, prompt: prompt)
        } catch {
            alert("Couldn't open Terminal", error.localizedDescription)
        }
    }

    @objc func stopTask(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let task = Running.list().first(where: { $0.id == id }) else { return }
        Running.stop(task)
    }

    @objc func stopAll() {
        Running.list().forEach(Running.stop)
    }

    func ask(agent: Agent, routine: Routine) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        let question = routine.question ?? (routine.project == nil ? "What should {agent} do?" : "What should {agent} do in {project}?")
        a.messageText = question.replacingOccurrences(of: "{agent}", with: agent.name)
            .replacingOccurrences(of: "{project}", with: routine.project ?? "")
        a.informativeText = "Folder: \(expandFolder(routine.folder))"
        a.addButton(withTitle: "Start")
        a.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 66))
        field.placeholderString = "Type what you want done"
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        a.accessoryView = field
        a.window.initialFirstResponder = field
        guard a.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    @objc func showLoadError() {
        alert("There's a problem in config.json", loadError ?? "", offerEdit: true)
    }

    @objc func editConfig() {
        ConfigFile.createIfMissing()
        let url = ConfigFile.url
        if NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else {
            let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
            NSWorkspace.shared.open([url], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    @objc func openProjectPage() {
        if let url = URL(string: projectURL) { NSWorkspace.shared.open(url) }
    }

    // For setup scripts: open -a "Agent Commander" --args --open-at-login on (or off)
    func applyLoginArgument() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--open-at-login") else { return }
        let on = i + 1 >= args.count || args[i + 1] != "off"
        if on && SMAppService.mainApp.status != .enabled { try? SMAppService.mainApp.register() }
        if !on && SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
        let status: [SMAppService.Status: String] = [.enabled: "on", .notRegistered: "off",
                                                     .requiresApproval: "waiting for approval in System Settings › General › Login Items"]
        print("Open at login: \(status[SMAppService.mainApp.status] ?? "unknown")")
        fflush(stdout)
    }

    @objc func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            alert("Couldn't change Open at login", error.localizedDescription)
        }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @discardableResult
    func alert(_ title: String, _ text: String, offerEdit: Bool = false, buttons: [String]? = nil) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        let labels = buttons ?? (offerEdit ? ["OK", "Edit routines…"] : ["OK"])
        labels.forEach { a.addButton(withTitle: $0) }
        let result = a.runModal()
        if buttons == nil && offerEdit && result == .alertSecondButtonReturn { editConfig() }
        return result
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
