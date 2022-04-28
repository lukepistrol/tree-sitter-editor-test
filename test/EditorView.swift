//
//  EditorView.swift
//  test
//
//  Created by Lukas Pistrol on 27.04.22.
//

import SwiftUI
import SwiftTreeSitter

/*
 This is mostly copied from `CodeEdit`s current Editor

 Still WIP but basically removed `Highlightr`.
 */

struct EditorView: NSViewRepresentable {

    private var content: Binding<String>
    private var language: Language

    private var textStorage: TextStorage

    init(content: Binding<String>, language: Language) {
        self.content = content
        self.language = language
        self.textStorage = TextStorage()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()

        let textView = CodeEditorTextView(textContainer: buildTextStorage(language: language, scrollView: scrollView))

        let attrString = NSAttributedString(
            string: content.wrappedValue,
            attributes:
                [
                    .foregroundColor: NSColor.textColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                    .backgroundColor: NSColor.textBackgroundColor
                ]
        )
        if let textStorage = textView.textStorage as? TextStorage {
            textStorage.append(attrString)
            print("OK")
        }

        textView.autoresizingMask = .width
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .medium)

        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autoresizingMask = [.width, .height]

        scrollView.documentView = textView

        return scrollView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var content: Binding<String>
        init(content: Binding<String>) {
            self.content = content
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            content.wrappedValue = textView.string
        }
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
    }

    func buildTextStorage(language: Language, scrollView: NSScrollView) -> NSTextContainer {
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)
        return textContainer
    }

}
