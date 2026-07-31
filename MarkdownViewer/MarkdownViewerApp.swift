import SwiftUI

@main
struct MarkdownViewerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .frame(minWidth: 700, minHeight: 450)
        }
        .defaultSize(width: 900, height: 900)
    }
}
