import Foundation

/// All exports use the same column definitions and row mapping. The UTF-8 BOM
/// helps Excel recognize the encoding; quoted cells preserve commas and newlines.
enum CSVWriter {
    static let columns = [
        "Computer Name", "Scan Time (UTC)", "macOS Version", "Application Name",
        "Version", "Bundle Identifier", "Application Path", "Main Executable",
        "Architectures", "Application Kind", "Notes", "Scan Warnings"
    ]

    static func write(_ report: ScanReport) throws {
        let date = ISO8601DateFormatter()
        var rows = [columns]
        for app in report.applications {
            rows.append([
                report.computerName, date.string(from: report.scannedAt), report.operatingSystem,
                app.name, app.version, app.bundleIdentifier, app.path.path,
                app.executablePath?.path ?? "", app.architectures.joined(separator: "; "),
                app.kind.rawValue, app.notes, report.warnings.joined(separator: "; ")
            ])
        }
        let text = "\u{FEFF}" + rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        // Atomic replacement retains the last complete CSV if a later save fails.
        try text.write(to: report.outputURL, atomically: true, encoding: .utf8)
    }

    static func cell(_ value: String) -> String {
        var safeValue = value
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        if first.map({ "=+-@".contains($0) }) == true || value.hasPrefix("\t") || value.hasPrefix("\r") || value.hasPrefix("\n") {
            safeValue = "'" + value // Prevent spreadsheet formula evaluation of app metadata.
        }
        return "\"" + safeValue.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
