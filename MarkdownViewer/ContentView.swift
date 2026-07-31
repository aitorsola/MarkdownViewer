import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    private let parsed: ParsedMarkdown
    private let fileURL: URL?
    @State private var selection: DocumentSection.ID?

    init(document: MarkdownDocument, fileURL: URL? = nil) {
        parsed = ParsedMarkdown.parse(document.text)
        self.fileURL = fileURL
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 400)
        } detail: {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(parsed.blocks) { block in
                            MarkdownBlockView(block: block)
                                .id(block.id)
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(28)
                    .frame(maxWidth: .infinity)
                }
                .textSelection(.enabled)
                .onChange(of: selection) { _, newValue in
                    guard let newValue else { return }
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .top)
                    }
                }
            }
            .toolbar {
                ToolbarItem {
                    Button(action: exportToPDF) {
                        Label("PDF", systemImage: "arrow.down.doc")
                            .labelStyle(.titleAndIcon)
                    }
                    .help("Exportar a PDF (⌘E)")
                    .keyboardShortcut("e", modifiers: .command)
                }
            }
        }
    }

    private func exportToPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent ?? "Documento") + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if PDFExporter.export(parsed, to: url) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if parsed.sections.isEmpty {
            ContentUnavailableView(
                "Sin secciones",
                systemImage: "list.bullet.indent",
                description: Text("El documento no contiene encabezados")
            )
        } else {
            List(parsed.sections, selection: $selection) { section in
                Text(section.title)
                    .lineLimit(2)
                    .font(section.level == 1 ? .body.weight(.semibold) : .body)
                    .foregroundStyle(section.level <= 2 ? .primary : .secondary)
                    .padding(.leading, CGFloat(section.level - 1) * 14)
            }
            .listStyle(.sidebar)
        }
    }
}

struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .heading(_, let level, let text):
            Text(text)
                .font(headingFont(for: level))
                .padding(.top, level <= 2 ? 12 : 6)

        case .paragraph(_, let text):
            Text(text)
                .lineSpacing(3)

        case .codeBlock(_, let code):
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
            }
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .quote(_, let text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 3)
                Text(text)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .listItem(_, let marker, let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker)
                    .foregroundStyle(.secondary)
                Text(text)
                    .lineSpacing(3)
            }
            .padding(.leading, CGFloat(indent) * 18)

        case .table(_, let header, let alignments, let rows):
            MarkdownTableView(header: header, alignments: alignments, rows: rows)

        case .rule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: .largeTitle.weight(.bold)
        case 2: .title.weight(.semibold)
        case 3: .title2.weight(.semibold)
        case 4: .title3.weight(.semibold)
        case 5: .headline
        default: .subheadline.weight(.semibold)
        }
    }
}

struct MarkdownTableView: View {
    let header: [AttributedString]
    let alignments: [TableColumnAlignment]
    let rows: [[AttributedString]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                if !header.isEmpty {
                    GridRow {
                        ForEach(Array(header.enumerated()), id: \.offset) { column, text in
                            cell(text, column: column)
                                .font(.callout.weight(.semibold))
                                .frame(maxHeight: .infinity)
                                .background(.quaternary.opacity(0.5))
                        }
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    if rowIndex > 0 || !header.isEmpty {
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                    }
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { column, text in
                            cell(text, column: column)
                                .font(.callout)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
        }
    }

    private func cell(_ text: AttributedString, column: Int) -> some View {
        Text(text)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .gridColumnAlignment(
                alignments.indices.contains(column) ? alignments[column].horizontal : .leading
            )
    }
}

