import DASCore
import Foundation

package struct Row {
    var marker: String = " "
    var label: String
    var value: String = ""
    var compactValue: String = ""
    var trailing: String = ""
    var id: String = ""

    package init(
        marker: String = " ", label: String, value: String = "", compactValue: String = "",
        trailing: String = "", id: String = ""
    ) {
        self.marker = marker
        self.label = label
        self.value = value
        self.compactValue = compactValue
        self.trailing = trailing
        self.id = id
    }

    var searchText: String { "\(label) \(value) \(id)".lowercased() }
}

package struct Frame {
    var title: String
    var subtitle: String = ""
    var isTopLevel: Bool = false
    var rows: [Row]
    var selected: Int
    var search: String
    var searching: Bool
    var status: String?

    package init(
        title: String, subtitle: String = "", isTopLevel: Bool = false, rows: [Row],
        selected: Int, search: String, searching: Bool, status: String?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isTopLevel = isTopLevel
        self.rows = rows
        self.selected = selected
        self.search = search
        self.searching = searching
        self.status = status
    }
}

package enum Screen {
    private static let gutter = "  "
    private static let contentIndent = "    "
    private static let wordmark = [
        "┌────┐  ┌────┐  ┌────┐",
        "│    │  │    │  │     ",
        "│    │  ├────┤  └────┐",
        "│    │  │    │       │",
        "└────┘  ┴    ┴  └────┘",
    ]

    package static func render(_ frame: Frame, style: Style, height: Int, width: Int) -> String {
        let width = max(8, width - 1)
        let showWordmark = frame.isTopLevel && height >= 22
        var lines = headerLines(frame, style: style, showWordmark: showWordmark, width: width)
            .flatMap { wrappedLines($0, width: width) }
        let contents = layout(frame.rows, width: width)
        let details =
            contents.indices.contains(frame.selected) ? contents[frame.selected].details : []
        let statusLines =
            frame.status.map {
                wrappedLines($0, width: width - contentIndent.count).map { contentIndent + $0 }
            } ?? []
        let hint =
            style.inverse(" / ") + " Search  " + style.inverse(" Esc ") + " Back  "
            + style.inverse(" r ") + " Refresh"
        let keyHints =
            frame.isTopLevel || frame.searching
            ? []
            : [""] + wrappedLines(contentIndent + hint, width: width)

        let attached =
            details.count + (statusLines.isEmpty ? 0 : statusLines.count + 1)
            + keyHints.count
        let capacity = max(3, height - lines.count - attached)
        lines += listLines(
            frame, contents: contents, capacity: capacity, width: width, style: style)

        if !statusLines.isEmpty {
            lines.append("")
            lines += statusLines
        }
        lines += keyHints
        return "\u{1B}[H\u{1B}[2J" + lines.joined(separator: "\n")
    }

    private static func headerLines(
        _ frame: Frame, style: Style, showWordmark: Bool, width: Int
    ) -> [String] {
        var lines = [""]
        if showWordmark {
            for line in wordmark {
                lines.append(contentIndent + style.bold(line))
            }
        } else {
            lines.append(contentIndent + style.bold(frame.title))
        }
        if !frame.subtitle.isEmpty {
            lines.append(contentIndent + style.dim(frame.subtitle))
        }

        let filtering = frame.searching || !frame.search.isEmpty
        if filtering {
            lines.append("")
            lines += searchBox(frame, style: style, width: width)
        }
        lines.append("")
        return lines
    }

    private static func searchBox(_ frame: Frame, style: Style, width: Int) -> [String] {
        let indent = String(repeating: " ", count: min(contentIndent.count, max(0, width - 8)))
        let boxWidth = min(48, width - indent.count)
        let innerWidth = boxWidth - 2
        let fieldWidth = innerWidth - 2
        let caret = frame.searching ? style.bold("▏") : ""
        let available = fieldWidth - (frame.searching ? 1 : 0)
        let content: String
        if frame.search.isEmpty {
            let placeholder = String("Type to filter...".prefix(fieldWidth))
            content =
                frame.searching
                ? style.inverse(String(placeholder.prefix(1)))
                    + style.dim(String(placeholder.dropFirst()))
                : style.dim(placeholder)
        } else {
            let text =
                frame.search.count > available
                ? "…" + frame.search.suffix(available - 1) : frame.search
            content = text + caret
        }
        let border = frame.searching ? style.bold : style.dim
        let label = String("─ Search ".prefix(innerWidth))
        return [
            indent
                + border(
                    "╭" + label + String(repeating: "─", count: innerWidth - label.count) + "╮"),
            indent + border("│") + " " + pad(content, fieldWidth) + " " + border("│"),
            indent + border("╰" + String(repeating: "─", count: innerWidth) + "╯"),
        ]
    }

    private static func listLines(
        _ frame: Frame,
        contents: [RenderedRow],
        capacity: Int,
        width: Int,
        style: Style
    ) -> [String] {
        guard !frame.rows.isEmpty else {
            return [contentIndent + style.dim("No matches")]
        }

        let inner = frame.rows.count > capacity ? max(1, capacity - 2) : capacity
        var first = 0
        if frame.rows.count > inner {
            first = min(max(0, frame.selected - inner / 2), frame.rows.count - inner)
        }
        let last = min(frame.rows.count, first + inner)

        let barWidth = min(
            width, (contents.map { visibleLength($0.text) }.max() ?? 0) + 2)

        var lines: [String] = []
        if first > 0 {
            lines.append(contentIndent + style.dim("↑ \(first) above"))
        }
        for index in first..<last {
            let padding = String(
                repeating: " ", count: max(0, barWidth - visibleLength(contents[index].text)))
            let body = contents[index].text + padding
            if index == frame.selected {
                lines.append(style.inverse(stripANSI(body)))
                lines += contents[index].details.map { contentIndent + style.dim($0) }
            } else {
                lines.append(body)
            }
        }
        if last < frame.rows.count {
            lines.append(contentIndent + style.dim("↓ \(frame.rows.count - last) more below"))
        }
        return lines
    }

    private struct RenderedRow {
        var text: String
        var details: [String] = []
    }

    private static func layout(_ rows: [Row], width: Int) -> [RenderedRow] {
        let labelWidth = min(rows.map(\.label.count).max() ?? 0, max(12, width / 3))
        let valueWidth =
            rows.filter { !$0.trailing.isEmpty }
            .map { visibleLength($0.value) }.max() ?? 0
        return rows.map { row in
            var line = "\(gutter)\(row.marker) \(pad(row.label, labelWidth))  "
            line += row.trailing.isEmpty ? row.value : pad(row.value, valueWidth + 2)
            line += row.trailing
            guard visibleLength(line) > width else { return RenderedRow(text: line) }
            let compact =
                "\(gutter)\(row.marker) \(pad(row.label, labelWidth))  \(row.compactValue)"
            let text =
                visibleLength(compact) <= width
                ? compact : String(stripANSI(compact).prefix(width - 1)) + "…"
            let detail = [
                stripANSI(row.label) + ":", stripANSI(row.value), stripANSI(row.trailing),
            ]
            .filter { !$0.isEmpty }.joined(separator: " ")
            return RenderedRow(
                text: text, details: wrappedLines(detail, width: width - contentIndent.count))
        }
    }

    private static func wrappedLines(_ text: String, width: Int) -> [String] {
        guard visibleLength(text) > width else { return [text] }
        let indentation = String(text.prefix { $0 == " " })
        if !indentation.isEmpty, indentation.count < width {
            return wrappedLines(
                String(text.dropFirst(indentation.count)), width: width - indentation.count
            ).map { indentation + $0 }
        }
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            let next = line.isEmpty ? String(word) : line + " " + word
            if visibleLength(next) <= width {
                line = next
                continue
            }
            if !line.isEmpty { lines.append(line) }
            line = String(word)
            if visibleLength(line) > width {
                line = stripANSI(line)
                while line.count > width {
                    lines.append(String(line.prefix(width)))
                    line.removeFirst(width)
                }
            }
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }
}
