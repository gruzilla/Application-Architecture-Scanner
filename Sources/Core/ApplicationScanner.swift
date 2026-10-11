import Foundation

protocol ApplicationScanning {
    func scan(root: URL, destination: URL, cancellation: CancellationToken,
              progress: @escaping (WorkProgress) -> Void) throws -> ScanReport
}

/// Performs disk work on the worker queue. The UI decides when scanning starts;
/// this service never opens a window or performs network access.
struct ApplicationScanner: ApplicationScanning {
    func scan(root: URL, destination: URL, cancellation: CancellationToken,
              progress: @escaping (WorkProgress) -> Void) throws -> ScanReport {
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ScannerError.message("Applications folder not found: \(root.path)")
        }
        if destination.path.contains("/AppTranslocation/") {
            throw ScannerError.message("macOS opened a protected temporary copy. Move the extracted app to the USB stick using Finder, then open it there again.")
        }
        let probe = destination.appendingPathComponent(".scanner-write-test-\(UUID().uuidString)")
        do {
            try Data().write(to: probe, options: .atomic)
            try files.removeItem(at: probe)
        } catch {
            throw ScannerError.message("Cannot save beside the app at \(destination.path). Check that the USB stick is connected, writable, and has free space.")
        }

        var warnings: [String] = []
        guard let enumerator = files.enumerator(at: root, includingPropertiesForKeys: nil, options: [], errorHandler: { url, error in
            warnings.append("Could not read \(url.path): \(error.localizedDescription)")
            return true // Preserve an inventory of the remaining accessible apps.
        }) else { throw ScannerError.message("Cannot read \(root.path)") }

        var paths: [URL] = []
        progress(WorkProgress(message: "Finding application bundles…", fraction: nil))
        for case let url as URL in enumerator {
            try cancellation.check()
            if url.pathExtension.lowercased() == "app" {
                paths.append(url)
                enumerator.skipDescendants() // Nested helpers are part of their parent app.
                progress(WorkProgress(message: "Finding applications… \(paths.count) found", fraction: nil))
            }
        }
        guard !paths.isEmpty else { throw ScannerError.message("No accessible app bundles were found in \(root.path).") }
        paths.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        var applications: [ApplicationRecord] = []
        for (index, path) in paths.enumerated() {
            try cancellation.check()
            progress(WorkProgress(message: "Extracting \(index + 1) of \(paths.count): \(path.lastPathComponent)", fraction: Double(index) / Double(paths.count)))
            applications.append(inspect(path))
        }
        let now = Date()
        let computer = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        let safeName = String(computer.map { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) ? $0 : "_" }.prefix(80))
        let timestamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        let filename = "Applications_\(safeName)_\(timestamp)_\(UUID().uuidString.prefix(8)).csv"
        let report = ScanReport(computerName: computer, scannedAt: now,
                                operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                                outputURL: destination.appendingPathComponent(filename),
                                applications: applications, warnings: warnings)
        progress(WorkProgress(message: "Saving the application inventory…", fraction: 1))
        try CSVWriter.write(report)
        return report
    }

    private func inspect(_ path: URL) -> ApplicationRecord {
        var app = ApplicationRecord(name: path.deletingPathExtension().lastPathComponent, path: path)
        do {
            let data = try Data(contentsOf: path.appendingPathComponent("Contents/Info.plist"))
            guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                throw ScannerError.message("Info.plist is not a dictionary.")
            }
            app.name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? app.name
            app.version = info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String ?? ""
            app.bundleIdentifier = info["CFBundleIdentifier"] as? String ?? ""
            guard let executable = info["CFBundleExecutable"] as? String, !executable.isEmpty else {
                throw ScannerError.message("No main executable is declared in Info.plist.")
            }
            let url = path.appendingPathComponent("Contents/MacOS").appendingPathComponent(executable)
            app.executablePath = url
            app.architectures = try MachOInspector.architectures(at: url)
            app.kind = MachOInspector.kind(for: app.architectures)
            if app.kind == .unknown { app.notes = "Main executable is not a recognized Mach-O binary; it may be a script or launcher." }
        } catch {
            app.notes = error.localizedDescription
        }
        return app
    }
}
