import AppKit
import SwiftUI

@main
struct ScannerApp: App {
    @NSApplicationDelegateAdaptor(ScannerAppDelegate.self) private var appDelegate
    @StateObject private var model = ScannerViewModel()

    var body: some Scene {
        WindowGroup("Application Architecture Scanner") {
            ScannerWindow(model: model)
        }
        // One inventory per app launch avoids two windows competing for one run.
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

final class ScannerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
