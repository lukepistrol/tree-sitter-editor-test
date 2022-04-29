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

    let swift = LanguageResource.swift
    var lang: Language { Language(language: swift.parser) }

    var parser: Parser?
    var query: Query?

    override init() {
        super.init()

        do {
            parser = Parser()
            try parser!.setLanguage(lang)

            let url = swift.highlightQueryURL
            query = try lang.query(contentsOf: url!)
        } catch {
            print(error)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
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
            guard let match = cursor.nextCapture()
            else {
                flag = false
                break
            }

            let capture = (name: match.name, range: match.node.range)
//            print("\(capture.range.description) \t| \(capture.name ?? "") \t\t | \(string[capture.range])")
            self.setAttributes([
                .foregroundColor: colorForCapture(capture.name),
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            ], range: capture.range)
        }
    }

    private func colorForCapture(_ capture: String?) -> NSColor {
        switch capture {
        case "include", "constructor", "keyword", "boolean", "variable.builtin", "keyword.return", "keyword.function": return .magenta
        case "comment": return .systemGreen
        case "variable": return .systemTeal
        case "function", "function.macro": return .systemMint
        case "number", "float": return .systemYellow
        case "string": return .systemRed
        case "type": return .systemPurple
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
//            highlight(range)
        }
    }

//    func highlight(_ range: NSRange) {
//        let string = self.string as NSString
//        let line = self.stringStorage.attributedSubstring(from: range)

//        self.highlight(in: range)

//        DispatchQueue.global().async {
//            let tmpString = line
//            DispatchQueue.main.async {
//                if (range.location + range.length) > self.stringStorage.length {
//                    return
//                }
//
//                if tmpString.string != self.stringStorage.attributedSubstring(from: range).string {
//                    return
//                }
//
//                self.beginEditing()
//                tmpString.enumerateAttributes(in: NSMakeRange(0, tmpString.length), options: []) { attrs, locRange, stop in
//                    var fixedRange = NSMakeRange(range.location + locRange.location, locRange.length)
//                    fixedRange.length = (fixedRange.location + fixedRange.length < string.length) ? fixedRange.length : string.length-fixedRange.location
//                    fixedRange.length = (fixedRange.length >= 0) ? fixedRange.length : 0
//                    self.stringStorage.setAttributes(attrs, range: fixedRange)
//
//                }
//                self.endEditing()
//                self.edited(.editedAttributes, range: range, changeInLength: 0)
//            }
//        }
//    }

}
