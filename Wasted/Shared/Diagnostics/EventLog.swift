import Foundation
import os

// A week-long flight recorder.
//
// This replaces `debug_la`, which kept the last TWELVE entries in a UserDefaults
// string. Thresholds now fire every minute, so that buffer was overwritten
// within minutes and could never answer "what broke overnight?" — the only
// question worth asking.
//
// Three separate processes write here (the app, the DeviceActivityMonitor
// extension, and the widget), so this is an append-only file in the shared App
// Group container. Writes go through a single open(O_APPEND) + write(), which
// POSIX makes atomic for writes under PIPE_BUF — that's what keeps two processes
// from interleaving half-lines. A DispatchQueue would NOT have helped here: it
// only serialises within one process, and the interesting races are between them.
//
// Also mirrored to os.Logger, so `xcrun devicectl device process view` / Console
// shows it live while you're watching.
enum EventLog {

    enum Category: String {
        case app          // lifecycle, foreground/background
        case monitor      // DeviceActivity thresholds — the usage truth
        case island       // ActivityKit: create / rotate / update / refusals
        case widget       // WidgetKit timeline requests + reloads
        case nudge        // notification decisions, including SUPPRESSED ones
        case receipt      // the 9pm receipt
        case background   // BGAppRefresh + the nightly BGProcessingTask
        case trial        // trial state + purchase
        case onboarding   // the 4-step flow
        case error        // anything that failed
    }

    // A week of minute-granularity thresholds is roughly 10–50k lines. 4 MB with
    // one backup holds that comfortably; past it the oldest week rolls off rather
    // than the log quietly eating the user's disk.
    private static let maxBytes = 4 * 1024 * 1024

    static func log(_ category: Category, _ message: String) {
        let line = "\(Self.timestamp())\t\(Self.process)\t\(category.rawValue)\t\(message)\n"
        Logger(subsystem: AppGroupKeys.appGroupID, category: category.rawValue)
            .log("\(message, privacy: .public)")
        append(line)
    }

    // Convenience for the case that matters most — something failed and we want
    // to know a week later.
    static func error(_ category: Category, _ message: String) {
        log(.error, "[\(category.rawValue)] \(message)")
    }

    // Library/Logs, not the container root. `devicectl device copy from` refuses
    // a source at the root of an App Group container ("File paths cannot contain
    // '..'") but copies happily out of Library/… — and a log you cannot get off
    // the device is not a log.
    static var fileURL: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupKeys.appGroupID)
        else { return nil }

        let directory = container.appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("wasted.log")
    }

    /// Whole log, newest last. For a share sheet or a device pull.
    static func contents() -> String {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Private

    private static func append(_ line: String) {
        guard let fileURL else { return }
        rotateIfNeeded(fileURL)

        // O_APPEND makes each write atomic across processes for short lines —
        // the reason this isn't a FileHandle seek-then-write, which races.
        let fd = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { return }
        defer { close(fd) }
        _ = line.withCString { write(fd, $0, strlen($0)) }
    }

    private static func rotateIfNeeded(_ url: URL) {
        guard
            let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
            size > maxBytes
        else { return }
        let previous = url.deletingLastPathComponent().appendingPathComponent("wasted.log.1")
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: url, to: previous)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()

    private static func timestamp() -> String {
        formatter.string(from: Date())
    }

    // Which process wrote the line. Without this, an entry from the monitor
    // extension is indistinguishable from one written by the app — and the whole
    // Live Activity saga was a question about WHICH PROCESS could do what.
    private static let process: String = {
        let id = Bundle.main.bundleIdentifier ?? "?"
        if id.hasSuffix("DeviceActivityMonitorExt") { return "mon" }
        if id.hasSuffix("WastedWidgets") { return "wgt" }
        if id.hasSuffix("LiveActivityExt") { return "isl" }
        return "app"
    }()
}
