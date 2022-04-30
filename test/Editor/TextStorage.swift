//
//  TextStorage.swift
//  test
//
//  Created by Lukas Pistrol on 28.04.22.
//

import AppKit
import Neon
import SwiftTreeSitter
import tree_sitter
import tree_sitter_language_resources

/*
 A NSTextStorage for the `EditorView`. It contains
 the highlighting logic for `tree-sitter`.
 This is heavily inspired by `Highlightr`
 */

class TextStorage: NSTextStorage {
    let stringStorage = NSTextStorage()

    private var languageResource: LanguageResource?
    private var language: Language? {
        guard let languageResource = languageResource else {
            return nil
        }
        return Language(language: languageResource.parser)
    }

    private var parser: Parser?
    private var query: Query?

    private var _font: NSFont {
        self.font ?? .monospacedSystemFont(ofSize: 11, weight: .medium)
    }

    init(language languageResource: LanguageResource) {
        self.languageResource = languageResource
        super.init()
        guard let language = language else {
            return
        }
        do {
            parser = Parser()
            try parser!.setLanguage(language)

            let url = languageResource.highlightQueryURL
            query = try language.query(contentsOf: url!)
        } catch {
            print(error)
        }
    }

    required init?(coder: NSCoder) {
        self.languageResource = nil
        super.init(coder: coder)
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        self.languageResource = nil
        super.init(pasteboardPropertyList: propertyList, ofType: type)
    }

    private func highlight(in range: NSRange) {
        guard let query = query,
              let parser = parser,
              let tree = parser.parse(self.string),
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
            guard let match = cursor.nextMatch()
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
            self.setAttributes([
                .foregroundColor: colorForCapture(capture.name),
                .font: _font
            ], range: capture.node.range)
        }
    }

    /// Only for debug use
    private func printCaptureInfo(_ capture: QueryCapture) {
        print(capture.node.range.description)
        print("\t| type:", capture.name ?? "##########")
        print("\t\t| content:", string[capture.node.range], "\n")
    }

    private func highlightCaptures(for predicates: [Predicate], in match: QueryMatch) {
        predicates.forEach { predicate in
            predicate.captures(in: match).forEach { capture in
//                print(capture.name, string[capture.node.range])
                self.setAttributes(
                    [
                        .foregroundColor: colorForCapture(capture.name?.appending("_alternate")),
                        .font: _font
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
        case "": return .orange
        default: return .textColor
        }
    }

    override var string: String {
        return stringStorage.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        stringStorage.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        stringStorage.replaceCharacters(in: range, with: str)
        self.edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        stringStorage.setAttributes(attrs, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
    }

    override func processEditing() {
        super.processEditing()
        if self.editedMask.contains(.editedCharacters) {
            let string = (self.string as NSString)
            let range = string.paragraphRange(for: editedRange)
            highlight(in: range)
        }
    }

}
