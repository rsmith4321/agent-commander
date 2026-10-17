// Keeps track of the agents Agent Commander started, so they can be stopped
// from the menu.
//
// Each launch script writes <id>.json into the running folder when it starts
// (its own PID and process group, plus what was launched) and deletes it when
// it ends. Stopping only ever signals processes in a group that one of those
// scripts leads, after checking the PID still belongs to that script.

import AppKit
import Darwin

struct RunningTask {
    let id: String
    let pid: pid_t        // the launch script's shell
    let pgid: pid_t       // its process group: the agent and anything it started
    let started: Date
    let title: String
    let project: String?
    let agent: String
}

enum Running {
    static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Agent Commander/running", isDirectory: true)

    static func stateURL(_ id: String) -> URL { folder.appendingPathComponent("\(id).json") }
    static func stopURL(_ id: String) -> URL { folder.appendingPathComponent("\(id).stop") }

    /// Shell lines for the top of a launch script: record this run, and forget
    /// it again on exit. `info` is a JSON object describing the launch.
    static func scriptPrologue(id: String, info: String) -> String {
        """
        state=\(shellQuote(stateURL(id).path))
        stopfile=\(shellQuote(stopURL(id).path))
        mkdir -p -- "${state:h}"
        info=\(shellQuote(info))
        print -r -- "{\\"pid\\": $$, \\"pgid\\": $(ps -o pgid= -p $$ | tr -d ' '), \\"started\\": $(date +%s), \\"info\\": $info}" > "$state"
        trap 'rm -f -- "$state" "$stopfile"' EXIT
        trap 'interrupted=1' INT   # Ctrl-C stops the agent, not this script
        """
    }

    /// Shell lines that run after the agent exits.
    static let scriptEpilogue = """
        if [[ -e "$stopfile" ]]; then
          rm -f -- "$state" "$stopfile"
          stty sane 2>/dev/null
          echo
          echo "Stopped."
          read -k 1 "?Press any key to close this window. "
          exit 0
        fi
        """

    /// Running tasks, oldest first. Files left behind by scripts that are gone
    /// (or whose PID now belongs to something else) are cleaned up.
    static func list() -> [RunningTask] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }
        var tasks: [RunningTask] = []
        for url in files where url.pathExtension == "json" {
            let id = url.deletingPathExtension().lastPathComponent
            guard let task = read(url, id: id), isOurs(task) else {
                // A file that can't be read yet may still be being written.
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if read(url, id: id) == nil, let modified, Date().timeIntervalSince(modified) < 10 { continue }
                try? fm.removeItem(at: url)
                try? fm.removeItem(at: stopURL(id))
                continue
            }
            tasks.append(task)
        }
        return tasks.sorted { $0.started < $1.started }
    }

    static func read(_ url: URL, id: String) -> RunningTask? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pid = obj["pid"] as? Int, let pgid = obj["pgid"] as? Int,
              let started = obj["started"] as? Double,
              let info = obj["info"] as? [String: Any] else { return nil }
        return RunningTask(id: id, pid: pid_t(pid), pgid: pid_t(pgid),
                           started: Date(timeIntervalSince1970: started),
                           title: info["title"] as? String ?? "Routine",
                           project: info["project"] as? String,
                           agent: info["agent"] as? String ?? "Agent")
    }

    /// True when the PID is still the launch script that wrote the file: it's
    /// alive, leads the recorded process group, and started when the file says.
    static func isOurs(_ task: RunningTask) -> Bool {
        guard task.pid > 1, task.pgid == task.pid, task.pgid != getpgrp(),
              let info = processInfo(task.pid), info.pgid == task.pgid else { return false }
        return abs(info.started.timeIntervalSince(task.started)) < 60
    }

    static func processInfo(_ pid: pid_t) -> (pgid: pid_t, started: Date)? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let t = info.kp_proc.p_un.__p_starttime
        return (info.kp_eproc.e_pgid, Date(timeIntervalSince1970: Double(t.tv_sec) + Double(t.tv_usec) / 1e6))
    }

    /// PIDs in a process group.
    static func members(of pgid: pid_t) -> [pid_t] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PGRP, pgid]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride + 8)
        size = procs.count * MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }
        return procs.prefix(size / MemoryLayout<kinfo_proc>.stride).map(\.kp_proc.p_pid).filter { $0 > 0 }
    }

    /// The agent and whatever it started: the group minus the script itself.
    static func agentProcesses(_ task: RunningTask) -> [pid_t] {
        guard isOurs(task) else { return [] }
        return members(of: task.pgid).filter { $0 != task.pid }
    }

    /// Stops a task the way Ctrl-C would: SIGINT, another SIGINT after 2 s,
    /// then SIGTERM after 3 s more if the agent is still running. The script
    /// stays alive to print "Stopped." and wait for a key.
    static func stop(_ task: RunningTask) {
        guard isOurs(task) else { return }
        FileManager.default.createFile(atPath: stopURL(task.id).path, contents: nil)
        func signal(_ sig: Int32) {
            for pid in agentProcesses(task) { kill(pid, sig) }
        }
        signal(SIGINT)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            signal(SIGINT)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { signal(SIGTERM) }
        }
    }

    static func elapsed(since date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "just started" }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}
