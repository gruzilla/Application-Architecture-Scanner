import SwiftUI

/// A single window keeps the workflow visible from first appearance to completion.
/// Controls below only send intentions to the model; they do not perform file I/O.
struct ScannerWindow: View {
    @ObservedObject var model: ScannerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Application Architecture Scanner")
                .font(.title2).bold()
            Divider()
            ScannerContent(model: model)
            Spacer(minLength: 0)
            if let report = model.report {
                Divider()
                Text("CSV: \(report.outputURL.path)")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if !report.warnings.isEmpty {
                    Text(report.warnings.joined(separator: "\n"))
                        .font(.caption).foregroundColor(.orange)
                        .lineLimit(4).help(report.warnings.joined(separator: "\n"))
                }
            }
        }
        .padding(24)
        .frame(minWidth: 680, idealWidth: 740, minHeight: 480, idealHeight: 560)
        .onAppear {
            // Defer to the next main-loop turn so the initial window is laid out
            // before the background scan is scheduled.
            DispatchQueue.main.async { model.startScan() }
        }
    }

}

private struct ScannerContent: View {
    @ObservedObject var model: ScannerViewModel

    @ViewBuilder var body: some View {
        switch model.phase {
        case .ready, .scanning:
            Text("Finding and extracting applications in \(model.settings.applicationsDirectory.path)")
                .font(.headline)
            ScanProgress(progress: model.progress)
            Text("Checking each app’s main executable locally.")
                .foregroundColor(.secondary)
        case .mail:
            MailPrompt(model: model)
        case .finished:
            CompletionView(model: model)
        case .failed:
            Text("The operation could not finish").font(.headline)
            Text(model.errorMessage).fixedSize(horizontal: false, vertical: true)
            if model.report != nil {
                Text("The saved CSV is still available.")
                    .foregroundColor(.secondary)
                Button("Show CSV") { model.revealCSV() }
            }
        }
    }
}

private struct ScanProgress: View {
    let progress: WorkProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fraction = progress.fraction {
                ProgressView(value: fraction, total: 1).progressViewStyle(LinearProgressViewStyle())
            } else {
                ProgressView().progressViewStyle(LinearProgressViewStyle())
            }
            Text(progress.message).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MailPrompt: View {
    @ObservedObject var model: ScannerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Application scan complete").font(.headline)
            Text("Applications scanned: \(model.report?.applications.count ?? 0)")
            Text("Intel-only apps: \(model.report?.intelApplications.count ?? 0)")
            Text("Would you like to email the CSV report to your IT administrator?")
                .foregroundColor(.secondary)
            TextField("IT administrator email", text: $model.administratorEmail)
                .textFieldStyle(.roundedBorder)
            if !model.errorMessage.isEmpty {
                Text(model.errorMessage).foregroundColor(.red)
            }
            HStack {
                Button("Not Now") { model.finishWithoutEmail() }
                Spacer()
                Button("Open Email") { model.composeEmail() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct CompletionView: View {
    @ObservedObject var model: ScannerViewModel

    var body: some View {
        let report = model.report
        VStack(alignment: .leading, spacing: 14) {
            Text("Application scan complete").font(.headline)
            Text("Applications scanned: \(report?.applications.count ?? 0)")
            Text("Intel-only apps: \(report?.intelApplications.count ?? 0)")
            Button("Show CSV") { model.revealCSV() }
        }
    }
}
