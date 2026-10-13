import DASCLI
import DASCore

func runOutputTests(_ t: TestRunner) {
    let style = Style(enabled: false)
    let app = StubReader.app("com.test.editor", "TextEdit")
    let browser = CategoryCatalog.browser
    let links = browser.targets[0]
    let html = browser.targets[1]

    t.suite("assignment-output") { t in
        let htmlOnly = AppStatusText.assignmentResult(
            app: app, response: HelperResponse(outcomes: [.init(target: html, ok: true)]),
            skipped: [links], style: style)
        t.expect(htmlOnly.contains("default for HTML files."), "success names the changed target")
        t.expect(
            !htmlOnly.contains("default for Browser"),
            "HTML success does not claim browser ownership")
        t.expect(
            htmlOnly.contains("default for web links was kept"), "unsupported targets stay explicit"
        )

        let partial = AppStatusText.assignmentResult(
            app: app,
            response: HelperResponse(outcomes: [
                .init(target: html, ok: true), .init(target: links, ok: false),
            ]), skipped: [], style: style)
        t.expect(
            partial.contains("default for HTML files."),
            "partial success retains the successful target")
        t.expect(
            partial.contains("Could not set TextEdit as the default for web links."),
            "partial failure names the failed target")
        t.expect(!partial.contains("1/2"), "partial results do not reintroduce ratios")

        for succeeded in [false, true] {
            let outcomes: [HelperResponse.Outcome] =
                (succeeded ? [.init(target: html, ok: true)] : [])
                + [.init(target: links, ok: false, cancelled: true)]
            let cancelled = AppStatusText.assignmentResult(
                app: app, response: HelperResponse(outcomes: outcomes), skipped: [], style: style)
            t.expect(cancelled.hasPrefix("Cancelled."), "cancellation is explicit")
            t.equal(
                cancelled.contains("default for HTML files."), succeeded,
                "cancellation reports only targets that succeeded")
            t.expect(
                cancelled.contains("default for web links was not changed."),
                "cancellation identifies the unchanged target")
        }

        let failed = AppStatusText.assignmentResult(
            app: app, response: HelperResponse(outcomes: [.init(target: html, ok: false)]),
            skipped: [], style: style)
        t.expect(failed.hasPrefix("✗"), "complete failure does not show a success marker")
        t.expect(!failed.contains("is now"), "complete failure does not claim a change")
    }

    t.suite("app-status-output") { t in
        let targets = CategoryCatalog.codeEditor.targets
        let complete = AppStatus(
            app: app, supportedTargets: targets, activeTargets: targets,
            totalTargets: targets.count, primaryTarget: targets[0])
        t.equal(
            AppStatusText.summary(complete, total: targets.count, style: style),
            "Default for all supported file types.", "coverage is limited to supported file types")

        let alternative = AppStatus(
            app: app, supportedTargets: [links, html], activeTargets: [],
            totalTargets: 2, primaryTarget: links)
        t.equal(
            AppStatusText.summary(alternative, total: 2, style: style), "",
            "fully capable alternatives have no redundant description")
        let partial = AppStatus(
            app: app, supportedTargets: [links, html], activeTargets: [html],
            totalTargets: 2, primaryTarget: links)
        t.equal(
            AppStatusText.summary(partial, total: 2, style: style), "Default for HTML files.",
            "default ownership is distinct from supported targets")
    }

    t.suite("screen-no-color-selection") { t in
        let noColor = Style(enabled: false, isTerminal: true)
        func render(_ selected: Int, using style: Style) -> String {
            let frame = Frame(
                title: "das", isTopLevel: true,
                rows: [Row(label: "Browser"), Row(label: "Code Editor")], selected: selected,
                search: "", searching: false, status: nil)
            return Screen.render(frame, style: style, height: 24, width: 120)
        }
        let first = render(0, using: noColor)
        let second = render(1, using: noColor)

        for (output, selectedLabel) in [(first, "Browser"), (second, "Code Editor")] {
            let highlighted = output.components(separatedBy: "\n").filter {
                $0.contains("\u{1B}[7m")
            }
            t.equal(highlighted.count, 1, "exactly one row is highlighted without colors")
            t.expect(
                highlighted.first?.contains(selectedLabel) == true,
                "the highlight follows the selected row without colors")
        }
        t.expect(first != second, "moving the selection changes the visible screen")

        let plain = render(0, using: style)
        t.expect(!plain.contains("\u{1B}[7m"), "non-terminal output has no inverse styling")
    }

    t.suite("screen-details") { t in
        let description =
            "Can open Python scripts, shell scripts, JavaScript files and Markdown files only."
        let rows = (0..<15).map { index in
            Row(label: "Editor \(index)", value: description, compactValue: "Limited support.")
        }
        for width in [40, 80, 120] {
            for selected in [0, 7, 14] {
                let frame = Frame(
                    title: "Code Editor", subtitle: "Source files.", rows: rows, selected: selected,
                    search: "", searching: false, status: nil)
                let output = stripANSI(Screen.render(frame, style: style, height: 24, width: width))
                let lines = output.components(separatedBy: "\n")
                t.expect(
                    lines.last?.contains(" /  Search") == true, "the search hint follows the list")
                t.expect(lines.last?.contains(" Esc  Back") == true, "the back hint follows search")
                t.expect(lines.allSatisfy { $0.count < width }, "rows fit within \(width) columns")
                t.expect(lines.count <= 24, "expanded details fit within the terminal height")
                t.expect(output.contains("Editor \(selected)"), "the selected row stays visible")
                if width < 120 {
                    t.expect(
                        output.contains("Limited support."),
                        "long descriptions have a compact summary")
                    let expanded = lines.filter { $0.contains("Editor \(selected):") }
                    t.equal(expanded.count, 1, "only the selected row expands its description")
                    t.expect(
                        output.contains("Markdown files only."),
                        "wrapped details retain the final target")
                }
            }
        }

        let result = AppStatusText.assignmentResult(
            app: app, response: HelperResponse(outcomes: [.init(target: html, ok: true)]),
            skipped: [links], style: style)
        let frame = Frame(
            title: "das", subtitle: AppMetadata.description, isTopLevel: true,
            rows: [Row(label: "Browser", value: "Safari")], selected: 0,
            search: "", searching: false, status: result)
        let output = stripANSI(Screen.render(frame, style: style, height: 24, width: 40))
        t.expect(
            output.components(separatedBy: "\n").allSatisfy { $0.count < 40 },
            "assignment results wrap within narrow terminals")
        t.expect(
            output.contains("cannot open them."),
            "wrapping preserves the reason for skipped targets")
        t.expect(!output.contains(" /  Search"), "the category list has no search hint")
        t.expect(!output.contains(" Esc  Back"), "the category list has no back hint")
        t.expect(
            output.components(separatedBy: "\n").first { $0.contains("Switch") }?
                .hasPrefix("    ") == true,
            "wrapped subtitles retain their indentation")

        let longName = Frame(
            title: "Code Editor",
            rows: [
                Row(
                    label: "Visual Studio Code", value: "Default for all supported file types.",
                    compactValue: "Default.")
            ], selected: 0, search: "", searching: false, status: nil)
        let narrow = stripANSI(Screen.render(longName, style: style, height: 24, width: 40))
        t.expect(
            narrow.contains("Visual Studio Code  Default."),
            "long app names stay separated from compact status text")

        let searching = Frame(
            title: "Code Editor", rows: [Row(label: "TextEdit")], selected: 0,
            search: "", searching: true, status: nil)
        let searchOutput = stripANSI(Screen.render(searching, style: style, height: 24, width: 40))
        t.expect(searchOutput.contains("Search"), "the search box appears when searching")
        t.expect(!searchOutput.contains(" /  Search"), "the hint hides while searching")
    }
}
