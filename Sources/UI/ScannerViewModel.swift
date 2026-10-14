import AppKit
import Combine
import Foundation

enum WorkflowPhase {
    case ready, scanning, mail, finished, failed
}

protocol MailComposing {
    func compose(recipient: String, subject: String, attachment: URL) throws
}

struct SystemMailComposer: MailComposing {
    func compose(recipient: String, subject: String, attachment: URL) throws {
        guard let service = NSSharingService(named: .composeEmail) else {
            throw ScannerError.message("No email application is configured on this Mac.")
        }
        service.recipients = [recipient]
        service.subject = subject
        service.perform(withItems: [attachment])
    }
}

/// Owns the workflow, not the scanning algorithms. All published state belongs to
/// the main queue; disk operations run on one serial worker queue.
final class ScannerViewModel: ObservableObject {
    @Published private(set) var phase: WorkflowPhase = .ready
    @Published private(set) var progress = WorkProgress(
        message: "Preparing to find application bundles…", fraction: nil)
    @Published private(set) var report: ScanReport?
    @Published private(set) var errorMessage = ""
    @Published var administratorEmail: String

    let settings: ScannerSettings
    private let destination: URL
    private let scanner: ApplicationScanning
    private let mailComposer: MailComposing
    private let worker = DispatchQueue(label: "local.application-scanner.worker", qos: .userInitiated)
    private var cancellation = CancellationToken()

    init(
        settings: ScannerSettings = ScannerSettings(), destination: URL? = nil,
        scanner: ApplicationScanning = ApplicationScanner(),
        mailComposer: MailComposing = SystemMailComposer()
    ) {
        self.settings = settings
        self.administratorEmail = settings.administratorEmail
        self.destination = destination ?? Bundle.main.bundleURL.deletingLastPathComponent()
        self.scanner = scanner
        self.mailComposer = mailComposer
    }

    /// Called by the first visible view's onAppear. The phase guard prevents
    /// repeated SwiftUI appearances from launching duplicate scans.
    func startScan() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard phase == .ready else { return }
        phase = .scanning
        let root = settings.applicationsDirectory
        let destination = self.destination
        let scanner = self.scanner
        let token = cancellation
        let progressHandler = makeProgressHandler()
        worker.async { [weak self] in
            do {
                let report = try scanner.scan(
                    root: root, destination: destination, cancellation: token, progress: progressHandler)
                DispatchQueue.main.async {
                    self?.report = report
                    self?.phase = .mail
                }
            } catch { self?.publishError(error) }
        }
    }

    func composeEmail() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard phase == .mail, let report else { return }
        let recipient = administratorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard recipient.contains("@") else {
            errorMessage = "Enter a valid email address for the IT administrator."
            return
        }
        do {
            try mailComposer.compose(
                recipient: recipient,
                subject: "Application architecture report — \(report.computerName)",
                attachment: report.outputURL
            )
            phase = .finished
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishWithoutEmail() {
        guard phase == .mail else { return }
        phase = .finished
    }

    func revealCSV() {
        guard let report = report else { return }
        NSWorkspace.shared.activateFileViewerSelecting([report.outputURL])
    }

    private func makeProgressHandler() -> (WorkProgress) -> Void {
        { [weak self] progress in DispatchQueue.main.async { self?.progress = progress } }
    }

    private func publishError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.localizedDescription
            self?.phase = .failed
        }
    }
}
