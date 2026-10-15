# Application Architecture Scanner

A native macOS SwiftUI application that scans installed applications, identifies
the architecture of each main executable, and saves the inventory as a CSV file.
The scan is local and performs no online research or other network requests.

After each scan, the app asks whether the CSV should be emailed to the IT
administrator. The recipient is prefilled from `administratorEmail` in
`ScannerSettings.swift`, and the user can edit it before opening their configured
email application. The CSV is attached to a new draft; the user reviews and sends
the message from their email application.

Change  `administratorEmail` in `ScannerSettings.swif` and rebuild to use the app
for your clients (word chosen on my usage-context).

## Build and test

Open `Application Architecture Scanner.xcodeproj` in Xcode, select the
**Application Architecture Scanner** scheme and **My Mac**, then build or run.
The shell helpers provide the equivalent command-line workflows:

```sh
/bin/bash Scripts/build.sh
/bin/bash Scripts/test.sh
/bin/bash Scripts/lint.sh
/bin/bash Scripts/format.sh
/bin/bash Scripts/package.sh
```

`lint.sh` checks all Swift sources with the `swift-format` tool included in the
active Xcode toolchain. `format.sh` applies the shared `.swift-format` rules in
place. Run the formatter before committing, then run lint and tests.

The app saves CSV files beside the built application. When distributing it on a
USB stick, place the application in a writable folder.

## Source map

| File | Responsibility |
|---|---|
| `Sources/Core/ScannerSettings.swift` | Applications folder and default IT administrator email |
| `Sources/Core/ApplicationScanner.swift` | App enumeration and local metadata extraction |
| `Sources/Core/MachOInspector.swift` | Executable architecture detection |
| `Sources/Core/CSVWriter.swift` | CSV columns, escaping, and writing |
| `Sources/UI/ScannerViewModel.swift` | Scan and email-draft workflow |
| `Sources/UI/ScannerWindow.swift` | SwiftUI interface |

Only each installed app's main executable is inspected; helpers and plug-ins can
have different architectures. The project does not install, modify, or download
applications. It does not automatically send mails.
