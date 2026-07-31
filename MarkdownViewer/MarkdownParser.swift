import SwiftUI

struct DocumentSection: Identifiable, Hashable {
    let id: Int
    let level: Int
    let title: String
}

enum TableColumnAlignment {
    case leading, center, trailing

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

enum MarkdownBlock: Identifiable {
    case heading(id: Int, level: Int, text: AttributedString)
    case paragraph(id: Int, text: AttributedString)
    case codeBlock(id: Int, code: String)
    case quote(id: Int, text: AttributedString)
    case listItem(id: Int, marker: String, indent: Int, text: AttributedString)
    case table(id: Int, header: [AttributedString], alignments: [TableColumnAlignment], rows: [[AttributedString]])
    case rule(id: Int)

    var id: Int {
        switch self {
        case .heading(let id, _, _),
             .paragraph(let id, _),
             .codeBlock(let id, _),
             .quote(let id, _),
             .listItem(let id, _, _, _),
             .table(let id, _, _, _),
             .rule(let id):
            return id
        }
    }
}

struct ParsedMarkdown {
    let blocks: [MarkdownBlock]
    let sections: [DocumentSection]

    static func parse(_ text: String) -> ParsedMarkdown {
        var blocks: [MarkdownBlock] = []
        var sections: [DocumentSection] = []
        var nextID = 0

        func id() -> Int {
            defer { nextID += 1 }
            return nextID
        }

        let lines = text.components(separatedBy: .newlines)
        var index = 0

        var paragraphBuffer: [String] = []
        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let joined = paragraphBuffer.joined(separator: " ")
            blocks.append(.paragraph(id: id(), text: inline(joined)))
            paragraphBuffer.removeAll()
        }

        let headingRegex = /^(#{1,6})\s+(.*)$/
        let listRegex = /^(\s*)([-*+]|\d{1,3}[.)])\s+(.*)$/

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                let fence = trimmed.hasPrefix("```") ? "```" : "~~~"
                var codeLines: [String] = []
                index += 1
                while index < lines.count,
                      !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    codeLines.append(lines[index])
                    index += 1
                }
                index += 1 // skip closing fence
                blocks.append(.codeBlock(id: id(), code: codeLines.joined(separator: "\n")))
                continue
            }

            // Blank line
            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            // Heading
            if let match = trimmed.wholeMatch(of: headingRegex) {
                flushParagraph()
                let level = match.1.count
                var title = String(match.2)
                while title.hasSuffix("#") { title.removeLast() }
                title = title.trimmingCharacters(in: .whitespaces)
                let blockID = id()
                blocks.append(.heading(id: blockID, level: level, text: inline(title, colorCode: false)))
                sections.append(DocumentSection(id: blockID, level: level, title: plain(title)))
                index += 1
                continue
            }

            // Horizontal rule
            if trimmed.count >= 3, trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }),
               Set(trimmed).count == 1 {
                flushParagraph()
                blocks.append(.rule(id: id()))
                index += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                flushParagraph()
                var quoteLines: [String] = []
                while index < lines.count {
                    let quoteTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                    guard quoteTrimmed.hasPrefix(">") else { break }
                    quoteLines.append(String(quoteTrimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(.quote(id: id(), text: inline(quoteLines.joined(separator: " "))))
                continue
            }

            // Table
            if trimmed.hasPrefix("|") {
                flushParagraph()
                var rawRows: [[String]] = []
                while index < lines.count {
                    let rowLine = lines[index].trimmingCharacters(in: .whitespaces)
                    guard rowLine.hasPrefix("|") else { break }
                    rawRows.append(splitTableRow(rowLine))
                    index += 1
                }

                var headerCells: [String] = []
                var alignments: [TableColumnAlignment] = []
                if rawRows.count >= 2, !rawRows[1].isEmpty, rawRows[1].allSatisfy(isSeparatorCell) {
                    headerCells = rawRows[0]
                    alignments = rawRows[1].map(columnAlignment)
                    rawRows.removeFirst(2)
                }

                let columnCount = max(headerCells.count, rawRows.map(\.count).max() ?? 0)
                guard columnCount > 0 else { continue }
                func padded(_ cells: [String]) -> [String] {
                    cells + Array(repeating: "", count: columnCount - cells.count)
                }
                while alignments.count < columnCount { alignments.append(.leading) }

                blocks.append(.table(
                    id: id(),
                    header: headerCells.isEmpty ? [] : padded(headerCells).map { inline($0) },
                    alignments: alignments,
                    rows: rawRows.map { padded($0).map { inline($0) } }
                ))
                continue
            }

            // List item
            if let match = line.wholeMatch(of: listRegex) {
                flushParagraph()
                let indent = match.1.count / 2
                let rawMarker = String(match.2)
                let marker = "-*+".contains(rawMarker) ? "•" : rawMarker
                blocks.append(.listItem(id: id(), marker: marker, indent: indent, text: inline(String(match.3))))
                index += 1
                continue
            }

            // Plain paragraph line
            paragraphBuffer.append(trimmed)
            index += 1
        }
        flushParagraph()

        return ParsedMarkdown(blocks: blocks, sections: sections)
    }

    private static func inline(_ text: String, colorCode: Bool = true) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        var attributed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        guard colorCode else { return attributed }

        let codeRanges = attributed.runs.compactMap { run -> Range<AttributedString.Index>? in
            guard let intent = run.inlinePresentationIntent, intent.contains(.code) else { return nil }
            return run.range
        }
        for range in codeRanges {
            attributed[range].foregroundColor = Color(nsColor: .systemPink)
            attributed[range].backgroundColor = Color(nsColor: .systemPink).opacity(0.08)
        }
        return attributed
    }

    private static func plain(_ text: String) -> String {
        String(inline(text).characters)
    }

    /// Splits a `| a | b |` row into cells, ignoring pipes escaped with `\` or inside backticks.
    private static func splitTableRow(_ line: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var inCode = false
        var previousWasEscape = false
        for character in line {
            if previousWasEscape {
                current.append(character)
                previousWasEscape = false
                continue
            }
            switch character {
            case "\\":
                previousWasEscape = true
                current.append(character)
            case "`":
                inCode.toggle()
                current.append(character)
            case "|" where !inCode:
                cells.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        cells.append(current)
        if let first = cells.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            cells.removeFirst()
        }
        if let last = cells.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            cells.removeLast()
        }
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isSeparatorCell(_ cell: String) -> Bool {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("-") && trimmed.wholeMatch(of: /:?-+:?/) != nil
    }

    private static func columnAlignment(_ cell: String) -> TableColumnAlignment {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        let colonLeading = trimmed.hasPrefix(":")
        let colonTrailing = trimmed.hasSuffix(":")
        if colonLeading && colonTrailing { return .center }
        if colonTrailing { return .trailing }
        return .leading
    }
}
