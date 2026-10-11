# Application Architecture Scanner — editable project

This project builds the same portable scanner and online download lookup as
version 2. It preserves JavaScript for Automation (JXA); it is not a Swift or
SwiftUI rewrite. The source is now separated into smaller files, with a shared
build script for Xcode, VS Code, and Terminal. The generated app is version 2.1.

## Which editor should I use?

**VS Code is the most convenient choice for editing the current JavaScript.**
It provides JavaScript highlighting, navigation, formatting, and completion.
The supplied tasks build, run, test, and package the app without extensions.
JXA's macOS Objective-C bridge is different from Node.js: ordinary Node/browser
debug configurations cannot debug it, and Cocoa bridge completion is limited.

**Xcode is also included and can edit, build, and launch the app.** It uses a
macOS app target with a custom build phase that calls `osacompile`. The Run
scheme launches the app without the Swift/C debugger, which cannot provide
JavaScript source breakpoints. This project has no Interface Builder or SwiftUI
screens; the current dialogs and progress window are built in JavaScript.
Xcode becomes the natural primary IDE if you later rewrite the app in Swift.

For a tiny one-file experiment, macOS Script Editor also supports JXA, but it
is less convenient for this multi-file project. Do not open only one source
file there and expect it to contain the whole application.

## Start with Xcode

1. Extract the project ZIP into a writable folder on your Mac.
2. Open `Application Architecture Scanner.xcodeproj`.
3. Select the **Application Architecture Scanner** scheme and **My Mac**.
4. Edit a file under `Sources` and save it.
5. Choose **Product > Build** (Command-B), then **Product > Run** (Command-R).
6. To locate the app, right-click it under **Products** and choose **Show in Finder**.
7. Copy the built app into a writable folder on your USB stick for use on laptops.

When running from Xcode, CSVs and the cache are saved next to its built product,
usually within Xcode's Derived Data folder. Once you copy the app onto USB,
output is saved next to that USB copy. Do not edit generated files inside the
app bundle; change `Sources` and rebuild instead.

The custom phase signs the app locally with an ad-hoc signature. Xcode's normal
code-signing step is disabled, so you do not need a developer team for local
builds. This setup does not provide Developer ID signing or notarization.
Use the packaging script below for USB distribution; the project is not set
up for the App Store or Xcode Organizer's distribution wizard.

### Xcode license / first launch

Open Xcode itself and complete its first-run setup, including reviewing and
accepting its license if prompted. Do this yourself; the project does not
accept license terms or install components for you.

On the machine where this project was prepared, Xcode's build command reported
an unaccepted license, so a full Xcode build/run could not be verified. Project
syntax, the shared standalone build, compiled script, and 30 offline assertions
were checked successfully. If Xcode fails before the custom build phase begins,
finish Xcode setup first. The standalone builder below does not invoke Xcode.

## Start with VS Code

1. Choose **File > Open Folder** and open this project folder.
2. Edit files in `Sources`.
3. Press **Command-Shift-B** to run the default **Build app** task.
4. Use **Terminal > Run Task > Build and run** to launch it.
5. Use **Run offline tests** for the included checks.
6. Use **Create USB ZIP** to create the distributable app ZIP.

No Node.js, Python, npm packages, or editor extensions are needed to build or
run this app. The build uses macOS's built-in tools. The project includes a
`jsconfig.json` for editor navigation without treating Cocoa bridge globals
as regular browser JavaScript.

## Startup and research review

The app opens a scanning window before reading application bundles. Discovery
uses an animated progress bar; extraction shows the current app and a completed
count. After saving the inventory CSV, the app presents a scrollable list of
Intel-only apps. **Start Online Research** opens the research progress window;
**Save CSV Only** finishes without network research. When no Intel-only apps
are found, research is skipped automatically.

## Source map — where to make changes

| File | What to change here |
|---|---|
| `Sources/Settings.js` | Applications folder, network time limits, page limit, cache lifetime, catalog URL |
| `Sources/Scanner.js` | App enumeration, architecture detection, original CSV columns, shared dialogs |
| `Sources/DownloadLookup.js` | Catalog matching, web search, publisher checks, link extraction, lookup columns, progress window, cache |
| `Sources/Main.js` | Launch behavior and final success/error dialog wording |
| `Scripts/build.sh` | App name, version, bundle ID, minimum macOS, build and signing steps |
| `Tests/LookupTests.js` | Offline regression checks for matching, evidence, caching, cancellation, and CSV behavior |

Files are concatenated in this order: Settings, Scanner, DownloadLookup, Main.
They share a JXA global scope. Use the existing function style and do not add
Node.js `require`, npm imports, DOM APIs, or browser `fetch` calls. Network work
currently goes through `requestURL`, which launches the built-in `curl` tool.
Use `console.log` for temporary diagnostics; command-line runs expose that output.

The bundle display name and executable product name also appear in the Xcode
project and VS Code tasks. If renaming the app, update those together with the
build script. Editing app behavior generally only requires changes in `Sources`.

## Common edits

**Change the folder to scan:** edit `applicationsDirectory` in Settings.js.
It currently accepts one absolute folder path. To scan multiple roots, update
`scan` and the launch code as well.

**Wait longer on slow websites:** increase `lookupTimeoutMilliseconds` and/or
`pageTimeoutSeconds`. A longer page timeout also increases the maximum delay
before the Stop button can respond. `catalogTimeoutSeconds` controls the
initial catalog request separately.

**Refresh results more often:** reduce `cacheHours`. Set it to 0 to avoid reusing
cached successful results. Alternatively, delete `Application-Download-Cache.json`
next to the running app. Keep timeouts positive; `maxPublisherPages` should be
a positive integer.

**Change download detection:** edit `lookupOne`, `armEvidence`, `nativeStatement`,
and `pageLinks` in DownloadLookup.js. Keep publisher ownership, architecture
claims, and link reachability as separate checks. Run the offline checks after
changes; they catch several misleading matches and failed-download cases.

**Add or rearrange CSV columns:** update the headers and row construction together.
The existing implementation uses positional indexes (for example, index 9 is
Application Kind). Update those indexes consistently when changing the original
columns; do not only rename or reorder the header.

## Terminal commands (from the project folder)

```sh
/bin/bash Scripts/build.sh
/bin/bash Scripts/test.sh
/bin/bash Scripts/package.sh
```

- Build output: `build/Application Architecture Scanner.app`
- USB ZIP: `build/Application-Architecture-Scanner.zip`
- Offline tests use temporary fixtures and remove them afterward.
- Test output includes a compiled-script smoke test and 30 assertions.
- Packaging rebuilds from the current source before creating the ZIP.

The packaged ZIP contains the app. Extract it before running, and place it
in a writable USB folder. A first-launch Gatekeeper prompt may still appear
because this app is not notarized. The app requires macOS 11 or newer and the
launcher contains Intel and Apple Silicon slices when built with the macOS
tools used to validate this project.

## Research limitations carried over from version 2

Online lookup is best-effort. It uses the public Homebrew cask catalog to
identify publisher sites and attempts DuckDuckGo search for unmatched apps.
Search challenges, JavaScript-only download pages, login requirements, and
unclear identity or architecture information can require manual review.
Source pages and evidence are retained. A catalog suggestion in **Unverified
Candidate URL** is not a confirmed official native download.

The scanner does not download or inspect installer binaries, install apps,
or change installed applications. A publisher-provided URL can redirect to
its chosen CDN or mirror. Current-release compatibility and licensing may
differ from the installed version. Only each installed app's main executable
is inspected; helpers and plugins can have different architectures.

## Editor and build references

- [VS Code JavaScript support](https://code.visualstudio.com/docs/languages/javascript)
- [Apple: customizing target build phases](https://developer.apple.com/documentation/xcode/customizing-the-build-phases-of-a-target)
