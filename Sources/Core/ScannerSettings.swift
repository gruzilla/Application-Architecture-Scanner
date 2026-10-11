import Foundation

/// Defaults shared by the UI and scanner. Change the address here to configure
/// the IT administrator suggested after every scan.
struct ScannerSettings {
    var applicationsDirectory = URL(fileURLWithPath: "/Applications", isDirectory: true)
    var administratorEmail = "it-administrator@example.com"
}

/// Shared between the main-thread UI and background scanner.
final class CancellationToken {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func check() throws {
        if isCancelled { throw ScannerError.cancelled }
    }
}

enum ScannerError: LocalizedError {
    case cancelled
    case message(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "The operation was stopped."
        case .message(let message): return message
        }
    }
}
