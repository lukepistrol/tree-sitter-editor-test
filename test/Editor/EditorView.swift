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
import TreeSitterJSON
import TreeSitterHTML
import TreeSitterGo
import TreeSitterRuby

/*
 This is mostly copied from `CodeEdit`s current Editor

 Still WIP but basically removed `Highlightr`.
 */

public struct EditorView: NSViewRepresentable {

    public typealias NSViewType = NSScrollView

    @State
    private var textView: STTextView

    @State
    private var text: String

    public init(text: Binding<String>) {
        self._text = State(wrappedValue: text.wrappedValue)
        self.textView = STTextView()
    }

    public func makeNSView(context: Context) -> NSViewType {
        let paragraph = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraph.lineHeightMultiple = 1.1
        paragraph.defaultTabInterval = 28

        textView.defaultParagraphStyle = paragraph
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        textView.textColor = .textColor
        textView.string = text
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
//        print("Update")
//        guard let textView = scrollView.documentView as? STTextView else { return }
//        textView.string = text
//        context.coordinator.highlight(in: NSRange(location: 0, length: self.text.count))
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, textView: self.textView)
    }
}

extension EditorView {
    public final class Coordinator: NSObject, STTextViewDelegate {

        @Binding
        var text: String
        var textView: STTextView?
        var query: Query?
        var parser: Parser?

        public init(text: Binding<String>, textView: STTextView?) {
            self._text = text
            self.textView = textView
            super.init()
            self.setupTS()
        }

        private func setupTS() {
            let swift = tree_sitter_swift()
            let language = Language(language: swift!)

            //if let highlightURL = self.highlightURL(for: "swift"),
            if let highlightURL = Bundle.main.resourceURL?
                .appendingPathComponent("TreeSitterSwift_TreeSitterSwift.bundle")
//                .appendingPathComponent("TreeSitterHTML_TreeSitterHTML.bundle")
//                .appendingPathComponent("TreeSitterGo_TreeSitterGo.bundle")
//                .appendingPathComponent("TreeSitterRuby_TreeSitterRuby.bundle")
//                .appendingPathComponent("TreeSitterJSON_TreeSitterJSON.bundle")
                .appendingPathComponent("Contents/Resources/queries/highlights.scm"),
               let textView = textView {
                Task(priority: .userInitiated) {
                    let start = CFAbsoluteTimeGetCurrent()
                    /*
                     Takes way too long for Swift (7.06s)
                     */
                    self.query = try! language.query(contentsOf: highlightURL)
                    let end = CFAbsoluteTimeGetCurrent()
                    print("Fetching Time: \(end-start) s")

                    self.parser = Parser()
                    try? self.parser!.setLanguage(language)
                    DispatchQueue.main.async {
                        self.highlight(in: self.range(from: textView.textContentStorage.documentRange, in: textView))
                    }
                }
            }
            
        }

//        private func highlightURL(for language: String) -> URL? {
//            if let urls = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil) {
//                for url in urls {
//                    if url.path.lowercased().contains(language) {
//                        if let resources = Bundle.urls(forResourcesWithExtension: nil, subdirectory: "queries", in: url) {
//                            for resource in resources {
//                                if resource.deletingPathExtension().lastPathComponent == "highlights" {
//                                    return resource
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            return nil
//        }

        public func highlight(in range: NSRange) {
            assert(Thread.isMainThread)
            guard let query = query,
                  let parser = parser,
                  let tree = parser.parse(self.text),
                  let rootNode = tree.rootNode
            else {
                return
            }
            // stops highlighting when an error occurs
            // e.g: When starting a string literal with one `"`
            // the whole document after would be highlighted as
            // a string and would not recover.
            if let expr = tree.rootNode?.sExpressionString,
               expr.contains("ERROR") { return }
            let cursor = query.execute(node: rootNode, in: tree)
            cursor.setRange(range)
            var flag = true
            while flag {
                guard let match = cursor.next()
                else {
                    flag = false
                    break
                }
                highlightCaptures(match.captures)
                highlightCaptures(for: match.predicates, in: match)
            }
        }

        private func highlightCaptures(_ captures: [QueryCapture]) {
            captures.forEach { capture in
                // DEBUG only:
                //            printCaptureInfo(capture)
                textView?.addAttributes([
                    .foregroundColor: colorForCapture(capture.name),
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
                ], range: capture.node.range)
            }
        }

        /// Only for debug use
        private func printCaptureInfo(_ capture: QueryCapture) {
            print(capture.node.range.description)
            print("\t| type:", capture.name ?? "##########")
            print("\t\t| content:", self.text[capture.node.range], "\n")
        }

        private func highlightCaptures(for predicates: [Predicate], in match: QueryMatch) {
            predicates.forEach { predicate in
                predicate.captures(in: match).forEach { capture in
                    //                print(capture.name, string[capture.node.range])
                    textView?.addAttributes(
                        [
                            .foregroundColor: colorForCapture(capture.name?.appending("_alternate")),
                            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
                        ],
                        range: capture.node.range
                    )
                }
            }
        }

        private func colorForCapture(_ capture: String?) -> NSColor {
            switch capture {
            case "include", "constructor", "keyword", "boolean", "variable.builtin", "keyword.return", "keyword.function", "repeat", "conditional": return .magenta
            case "comment": return .systemGreen
            case "variable", "property": return .systemTeal
            case "function", "method": return .systemMint
            case "number", "float": return .systemYellow
            case "string": return .systemRed
            case "type": return .systemPurple
            case "parameter": return .systemTeal
            case "type_alternate": return .systemCyan
            default: return .textColor
            }
        }

        public func textView(_ textView: STTextView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
            print("changed: \(affectedCharRange) - \(replacementString)")
            self.text = textView.string
            highlight(in: range(from: textView.textContentStorage.documentRange, in: textView))
        }

        public func textView(_ textView: STTextView, shouldChangeTextIn affectedCharRange: NSTextRange, replacementString: String?) -> Bool {
            return true
        }

        private func range(from textRange: NSTextRange, in textView: STTextView) -> NSRange {
            let textContentStorage = textView.textContentStorage
            let layoutManager = textView.textLayoutManager

            let offset = textContentStorage.offset(from: layoutManager.documentRange.location, to: textRange.location)
            let length = textContentStorage.offset(from: textRange.location, to: textRange.endLocation)
            return NSRange(location: offset, length: length)
        }
    }
}


