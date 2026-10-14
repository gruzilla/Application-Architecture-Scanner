import Foundation

/// Describes the installed app's main executable, not its helpers or plug-ins.
enum ApplicationKind: String, Codable {
    case appleSilicon = "Apple Silicon"
    case intel = "Intel"
    case universal = "Universal (Apple Silicon + Intel)"
    case legacy = "Other (legacy)"
    case unknown = "Unknown"
}

struct ApplicationRecord: Identifiable, Codable {
    var id: String { path.path }
    var name: String
    var version = ""
    var bundleIdentifier = ""
    var path: URL
    var executablePath: URL?
    var architectures: [String] = []
    var kind: ApplicationKind = .unknown
    var developerName = ""
    var developerTeamIdentifier = ""
    var notes = ""
}

struct ScanReport {
    var computerName: String
    var scannedAt: Date
    var operatingSystem: String
    var outputURL: URL
    var applications: [ApplicationRecord]
    var warnings: [String] = []

    var intelApplications: [ApplicationRecord] {
        applications.filter { $0.kind == .intel }
    }

}

struct WorkProgress {
    var message: String
    /// nil means the total is not known yet (for example, directory discovery).
    var fraction: Double?
}
