//
//  EditorView.swift
//  test
//
//  Created by Lukas Pistrol on 27.04.22.
//

import SwiftUI
import SwiftTreeSitter
import tree_sitter_language_resources

/*
 This is mostly copied from `CodeEdit`s current Editor

 Still WIP but basically removed `Highlightr`.
 */

struct EditorView: NSViewRepresentable {

    private var content: Binding<String>
    private var textStorage: TextStorage

    /* Temporary */
    @State
    private var font: NSFont = .monospacedSystemFont(ofSize: 11, weight: .medium)

    private var language: LanguageResource

    init(content: Binding<String>, language: LanguageResource) {
        self.content = content
        self.language = language
        self.textStorage = TextStorage(language: language)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()

        let textView = CodeEditorTextView(textContainer: buildTextStorage(scrollView: scrollView))

        let attrString = NSAttributedString(
            string: content.wrappedValue,
            attributes:
                [
                    .foregroundColor: NSColor.textColor,
                    .font: self.font
                ]
        )
        self.textStorage.append(attrString)

        textView.autoresizingMask = .width
        textView.maxSize = NSSize(width: Double.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.delegate = context.coordinator

        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autoresizingMask = [.width, .height]

        scrollView.contentView = NSClipView()
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeEditorTextView else {
            return
        }
        textView.font = self.font
    }

    func buildTextStorage(scrollView: NSScrollView) -> NSTextContainer {
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)
        return textContainer
    }

    // MARK: Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var content: Binding<String>
        init(content: Binding<String>) {
            self.content = content
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CodeEditorTextView else {
                return
            }
            content.wrappedValue = textView.string
        }
    }

}
