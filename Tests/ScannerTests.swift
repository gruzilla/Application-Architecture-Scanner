import Combine
import XCTest

/// These tests use temporary bundles and never scan installed applications or
/// open the system email composer.
final class ScannerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testThinMachOArchitectures() {
        XCTAssertEqual(MachOInspector.architectures(in: thin(cpu: 0x01000007)), ["x86_64"])
        XCTAssertEqual(MachOInspector.architectures(in: thin(cpu: 0x0100000C)), ["arm64"])
        XCTAssertEqual(MachOInspector.architectures(in: thin(cpu: 0x0100000C, subtype: 2)), ["arm64e"])
        XCTAssertEqual(MachOInspector.kind(for: ["x86_64"]), .intel)
        XCTAssertEqual(MachOInspector.kind(for: ["arm64e"]), .appleSilicon)
    }

    func testUniversalAndMalformedHeaders() {
        var fat = Data([0xCA, 0xFE, 0xBA, 0xBE, 0, 0, 0, 2])
        for cpu: UInt32 in [0x01000007, 0x0100000C] {
            fat.append(contentsOf: [
                UInt8(cpu >> 24), UInt8((cpu >> 16) & 255), UInt8((cpu >> 8) & 255), UInt8(cpu & 255),
            ])
            fat.append(Data(repeating: 0, count: 16))
        }
        XCTAssertEqual(MachOInspector.kind(for: MachOInspector.architectures(in: fat)), .universal)
        XCTAssertEqual(MachOInspector.architectures(in: Data(fat.prefix(10))), [])
        XCTAssertEqual(MachOInspector.architectures(in: Data("#!/bin/sh".utf8)), [])
    }

    func testCSVFormattingAndResearchColumnsRemoved() throws {
        XCTAssertEqual(CSVWriter.cell("A, \"B\"\nC"), "\"A, \"\"B\"\"\nC\"")
        XCTAssertEqual(CSVWriter.cell("=1+1"), "\"'=1+1\"")
        let report = makeReport()
        try CSVWriter.write(report)
        let data = try Data(contentsOf: report.outputURL)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertTrue(text.contains("\r\n"))
        XCTAssertFalse(text.contains("Lookup Status"))
        XCTAssertFalse(text.contains("Download URL"))
        XCTAssertTrue(text.contains("Developer / Signing Identity"))
        XCTAssertTrue(text.contains("Developer Team ID"))
        XCTAssertEqual(CSVWriter.columns.count, 14)
    }

    func testScannerSkipsNestedHelpersAndRetainsUnknownApps() throws {
        let root = temporaryDirectory.appendingPathComponent("Applications")
        try makeApp(at: root.appendingPathComponent("Example.app"))
        try makeApp(at: root.appendingPathComponent("Example.app/Contents/Helper.app"))
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Missing.app"), withIntermediateDirectories: true)
        var progress: [WorkProgress] = []
        let report = try ApplicationScanner().scan(
            root: root, destination: temporaryDirectory, cancellation: CancellationToken()
        ) { progress.append($0) }
        XCTAssertEqual(report.applications.count, 2)
        XCTAssertEqual(report.intelApplications.count, 1)
        XCTAssertEqual(report.applications.filter { $0.kind == .unknown }.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.outputURL.path))
        XCTAssertTrue(progress.contains { $0.fraction == nil })
        XCTAssertEqual(progress.last?.fraction, 1)
        let second = try ApplicationScanner().scan(
            root: root, destination: temporaryDirectory, cancellation: CancellationToken(), progress: { _ in }
        )
        XCTAssertNotEqual(report.outputURL, second.outputURL)
    }

    func testMissingAndUnwritableScanDestinations() throws {
        XCTAssertThrowsError(
            try ApplicationScanner().scan(
                root: temporaryDirectory.appendingPathComponent("missing"), destination: temporaryDirectory,
                cancellation: CancellationToken(), progress: { _ in }))
        let root = temporaryDirectory.appendingPathComponent("Applications")
        try makeApp(at: root.appendingPathComponent("Example.app"))
        XCTAssertThrowsError(
            try ApplicationScanner().scan(
                root: root, destination: temporaryDirectory.appendingPathComponent("missing"),
                cancellation: CancellationToken(), progress: { _ in }))
    }

    func testUnsignedApplicationHasNoSigningIdentity() throws {
        let applicationURL = temporaryDirectory.appendingPathComponent("Unsigned.app")
        try makeApp(at: applicationURL)

        XCTAssertNil(CodeSigningInspector.identity(at: applicationURL))
    }

    func testScanAlwaysAsksAboutEmail() {
        var report = makeReport()
        report.applications[0].kind = .appleSilicon
        let model = ScannerViewModel(
            destination: temporaryDirectory, scanner: FakeScanner(report: report),
            mailComposer: FakeMailComposer())
        let mail = expectation(description: "mail prompt")
        let subscription = model.$phase.sink { if $0 == .mail { mail.fulfill() } }
        model.startScan()
        wait(for: [mail], timeout: 3)
        XCTAssertEqual(model.administratorEmail, ScannerSettings().administratorEmail)
        withExtendedLifetime(subscription) {}
    }

    func testEmailUsesEditedRecipientAndCSVAttachment() {
        let composer = FakeMailComposer()
        let report = makeReport()
        let model = ScannerViewModel(
            destination: temporaryDirectory, scanner: FakeScanner(report: report), mailComposer: composer)
        let mail = expectation(description: "mail prompt")
        let subscription = model.$phase.sink { if $0 == .mail { mail.fulfill() } }
        model.startScan()
        wait(for: [mail], timeout: 3)
        model.administratorEmail = "support@example.org"
        model.composeEmail()
        XCTAssertEqual(composer.recipient, "support@example.org")
        XCTAssertEqual(composer.attachment, report.outputURL)
        XCTAssertEqual(model.phase, .finished)
        withExtendedLifetime(subscription) {}
    }

    func testInvalidEmailDoesNotOpenComposer() {
        let composer = FakeMailComposer()
        let model = ScannerViewModel(
            destination: temporaryDirectory, scanner: FakeScanner(report: makeReport()),
            mailComposer: composer)
        let mail = expectation(description: "mail prompt")
        let subscription = model.$phase.sink { if $0 == .mail { mail.fulfill() } }
        model.startScan()
        wait(for: [mail], timeout: 3)
        model.administratorEmail = "invalid"
        model.composeEmail()
        XCTAssertNil(composer.recipient)
        XCTAssertEqual(model.phase, .mail)
        XCTAssertFalse(model.errorMessage.isEmpty)
        withExtendedLifetime(subscription) {}
    }

    private func thin(cpu: UInt32, subtype: UInt32 = 0) -> Data {
        var data = Data([0xCF, 0xFA, 0xED, 0xFE])
        for word in [cpu, subtype] {
            data.append(contentsOf: [
                UInt8(word & 255), UInt8((word >> 8) & 255), UInt8((word >> 16) & 255), UInt8(word >> 24),
            ])
        }
        return data
    }

    private func makeApp(at url: URL) throws {
        let executable = url.appendingPathComponent("Contents/MacOS/main")
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try thin(cpu: 0x01000007).write(to: executable)
        let info = [
            "CFBundleName": "Example", "CFBundleExecutable": "main", "CFBundleIdentifier": "com.example.App",
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(
            to: url.appendingPathComponent("Contents/Info.plist"))
    }

    private func makeAppRecord() -> ApplicationRecord {
        ApplicationRecord(
            name: "Example", bundleIdentifier: "com.example.App",
            path: URL(fileURLWithPath: "/Applications/Example.app"), architectures: ["x86_64"], kind: .intel)
    }

    private func makeReport() -> ScanReport {
        ScanReport(
            computerName: "Test Mac", scannedAt: Date(), operatingSystem: "Test macOS",
            outputURL: temporaryDirectory.appendingPathComponent("report.csv"),
            applications: [makeAppRecord()])
    }
}

private struct FakeScanner: ApplicationScanning {
    var report: ScanReport

    func scan(
        root: URL, destination: URL, cancellation: CancellationToken,
        progress: @escaping (WorkProgress) -> Void
    ) throws -> ScanReport {
        report
    }
}

private final class FakeMailComposer: MailComposing {
    private(set) var recipient: String?
    private(set) var attachment: URL?

    func compose(recipient: String, subject: String, attachment: URL) throws {
        self.recipient = recipient
        self.attachment = attachment
    }
}
