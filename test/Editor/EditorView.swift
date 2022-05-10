//
//  EditorView.swift
//  test
//
//  Created by Lukas Pistrol on 27.04.22.
//

import SwiftUI
import SwiftTreeSitter
import STTextView
import TreeSitterSwift

/*
 This is mostly copied from `CodeEdit`s current Editor

 Still WIP but basically removed `Highlightr`.
 */

public struct EditorView: NSViewRepresentable {

    public typealias NSViewType = NSScrollView

    private var text: Binding<String>

    public init(text: Binding<String>) {
        self.text = text
    }

    public func makeNSView(context: Context) -> NSViewType {
        let textView = STTextView()

        let paragraph = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraph.lineHeightMultiple = 1.1
        paragraph.defaultTabInterval = 28

        textView.defaultParagraphStyle = paragraph
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        textView.textColor = .textColor
        textView.string = text.wrappedValue
        textView.widthTracksTextView = true
        textView.highlightSelectedLine = true
        textView.delegate = context.coordinator

        let scrollView = NSViewType()
        scrollView.documentView = textView

        scrollView.verticalRulerView = STLineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.rulersVisible = true

        return scrollView
    }

    public func updateNSView(_ scrollView: NSViewType, context: Context) {
        guard let textView = scrollView.documentView as? STTextView else { return }
        textView.string = text.wrappedValue
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: text)
    }
}

extension EditorView {
    public final class Coordinator: NSObject, STTextViewDelegate {

        var text: Binding<String>

        public init(text: Binding<String>) {
            self.text = text
            super.init()
            DispatchQueue.main.async {
                self.setupTS()
            }
        }

        private func setupTS() {
            let swift = tree_sitter_swift()
            let language = Language(language: swift!)

            let parser = Parser()
            try! parser.setLanguage(language)

            guard let tree = parser.parse(text.wrappedValue) else { return }

            DispatchQueue.global().async {
                if let highlightURL = self.highlightURL(for: "swift") {
                    let query = try! language.query(contentsOf: highlightURL)
                    let cursor = query.execute(node: tree.rootNode!, in: tree)
                    print(cursor.nextCapture()?.name)
                }
            }
        }

        private func highlightURL(for language: String) -> URL? {
            if let urls = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil) {
                for url in urls {
                    if url.path.lowercased().contains(language) {
                        if let resources = Bundle.urls(forResourcesWithExtension: nil, subdirectory: "queries", in: url) {
                            for resource in resources {
                                if resource.deletingPathExtension().lastPathComponent == "highlights" {
                                    return resource
                                }
                            }
                        }
                    }
                }
            }
            return nil
        }

        public func textView(_ textView: STTextView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
            print("changed: \(affectedCharRange) - \(replacementString)")
        }
    }
}


