import AppKit

enum PDFExporter {
    private static let bodySize: CGFloat = 12

    @discardableResult
    static func export(_ parsed: ParsedMarkdown, to url: URL) -> Bool {
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 595.28, height: 841.89) // A4
        printInfo.topMargin = 48
        printInfo.bottomMargin = 48
        printInfo.leftMargin = 48
        printInfo.rightMargin = 48
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        let width = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        textView.appearance = NSAppearance(named: .aqua)
        guard let layoutManager = textView.layoutManager,
              let container = textView.textContainer,
              let storage = textView.textStorage else { return false }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        storage.setAttributedString(attributedDocument(parsed))
        layoutManager.ensureLayout(for: container)
        let height = layoutManager.usedRect(for: container).height
        textView.frame = NSRect(x: 0, y: 0, width: width, height: max(height, 1))

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        return operation.run()
    }

    // MARK: - Document assembly

    private static func attributedDocument(_ parsed: ParsedMarkdown) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for block in parsed.blocks {
            switch block {
            case .heading(_, let level, let text):
                let sizes: [CGFloat] = [22, 18, 15.5, 14, 13, 12]
                let font = NSFont.boldSystemFont(ofSize: sizes[min(max(level, 1), 6) - 1])
                let style = NSMutableParagraphStyle()
                style.paragraphSpacingBefore = level <= 2 ? 14 : 8
                style.paragraphSpacing = 6
                result.append(paragraph(convert(text, baseFont: font, colorCode: false), style: style))

            case .paragraph(_, let text):
                let style = NSMutableParagraphStyle()
                style.paragraphSpacing = 7
                style.lineSpacing = 2
                result.append(paragraph(convert(text, baseFont: .systemFont(ofSize: bodySize)), style: style))

            case .codeBlock(_, let code):
                let style = NSMutableParagraphStyle()
                style.paragraphSpacing = 8
                style.firstLineHeadIndent = 8
                style.headIndent = 8
                result.append(NSAttributedString(string: code + "\n", attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
                    .foregroundColor: NSColor.black,
                    .backgroundColor: NSColor(white: 0.94, alpha: 1),
                    .paragraphStyle: style,
                ]))

            case .quote(_, let text):
                let font = NSFontManager.shared.convert(.systemFont(ofSize: bodySize), toHaveTrait: .italicFontMask)
                let style = NSMutableParagraphStyle()
                style.firstLineHeadIndent = 16
                style.headIndent = 16
                style.paragraphSpacing = 7
                result.append(paragraph(convert(text, baseFont: font, baseColor: .darkGray), style: style))

            case .listItem(_, let marker, let indent, let text):
                let item = NSMutableAttributedString(string: "\(marker)  ", attributes: [
                    .font: NSFont.systemFont(ofSize: bodySize),
                    .foregroundColor: NSColor.darkGray,
                ])
                item.append(convert(text, baseFont: .systemFont(ofSize: bodySize)))
                let style = NSMutableParagraphStyle()
                style.firstLineHeadIndent = CGFloat(indent) * 14
                style.headIndent = CGFloat(indent) * 14 + 14
                style.paragraphSpacing = 3
                result.append(paragraph(item, style: style))

            case .table(_, let header, let alignments, let rows):
                appendTable(header: header, alignments: alignments, rows: rows, to: result)

            case .rule:
                let style = NSMutableParagraphStyle()
                style.paragraphSpacingBefore = 4
                style.paragraphSpacing = 8
                result.append(NSAttributedString(string: String(repeating: "─", count: 46) + "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 8),
                    .foregroundColor: NSColor.lightGray,
                    .paragraphStyle: style,
                ]))
            }
        }
        return result
    }

    private static func paragraph(_ text: NSAttributedString, style: NSParagraphStyle) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: bodySize)]))
        mutable.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: mutable.length))
        return mutable
    }

    // MARK: - Tables

    private static func appendTable(
        header: [AttributedString],
        alignments: [TableColumnAlignment],
        rows: [[AttributedString]],
        to result: NSMutableAttributedString
    ) {
        let columnCount = max(header.count, rows.map(\.count).max() ?? 0)
        guard columnCount > 0 else { return }
        let table = NSTextTable()
        table.numberOfColumns = columnCount

        var rowIndex = 0
        if !header.isEmpty {
            appendTableRow(header, table: table, row: rowIndex, alignments: alignments, isHeader: true, to: result)
            rowIndex += 1
        }
        for row in rows {
            appendTableRow(row, table: table, row: rowIndex, alignments: alignments, isHeader: false, to: result)
            rowIndex += 1
        }

        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 8
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 6),
            .paragraphStyle: style,
        ]))
    }

    private static func appendTableRow(
        _ cells: [AttributedString],
        table: NSTextTable,
        row: Int,
        alignments: [TableColumnAlignment],
        isHeader: Bool,
        to result: NSMutableAttributedString
    ) {
        for column in 0..<table.numberOfColumns {
            let block = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: column, columnSpan: 1)
            block.setBorderColor(NSColor(white: 0.7, alpha: 1))
            block.setWidth(0.5, type: .absoluteValueType, for: .border)
            block.setWidth(3, type: .absoluteValueType, for: .padding)
            if isHeader {
                block.backgroundColor = NSColor(white: 0.92, alpha: 1)
            }

            let style = NSMutableParagraphStyle()
            style.textBlocks = [block]
            if alignments.indices.contains(column) {
                style.alignment = switch alignments[column] {
                case .leading: .left
                case .center: .center
                case .trailing: .right
                }
            }

            let baseFont: NSFont = isHeader ? .boldSystemFont(ofSize: 10.5) : .systemFont(ofSize: 10.5)
            let content = column < cells.count
                ? convert(cells[column], baseFont: baseFont)
                : NSAttributedString(string: "", attributes: [.font: baseFont])
            let cell = NSMutableAttributedString(attributedString: content)
            cell.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
            cell.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: cell.length))
            result.append(cell)
        }
    }

    // MARK: - Inline conversion

    private static func convert(
        _ text: AttributedString,
        baseFont: NSFont,
        baseColor: NSColor = .black,
        colorCode: Bool = true
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in text.runs {
            let fragment = String(text[run.range].characters)
            var font = baseFont
            var color = baseColor
            var attributes: [NSAttributedString.Key: Any] = [:]

            if let intent = run.inlinePresentationIntent {
                if intent.contains(.stronglyEmphasized) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                if intent.contains(.emphasized) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                if intent.contains(.code) {
                    font = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
                    if colorCode {
                        color = NSColor.systemPink
                        attributes[.backgroundColor] = NSColor.systemPink.withAlphaComponent(0.08)
                    }
                }
            }
            if let link = run.link {
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                color = NSColor.linkColor
            }

            attributes[.font] = font
            attributes[.foregroundColor] = color
            result.append(NSAttributedString(string: fragment, attributes: attributes))
        }
        return result
    }
}
