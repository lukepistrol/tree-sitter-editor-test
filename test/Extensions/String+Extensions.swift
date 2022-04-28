//
//  String+Extensions.swift
//  test
//
//  Created by Lukas Pistrol on 28.04.22.
//

import AppKit

extension String {
    // make string subscriptable with NSRange
    subscript(value: NSRange) -> Substring {
        let upperBound = String.Index(utf16Offset: Int(value.upperBound), in: self)
        let lowerBound = String.Index(utf16Offset: Int(value.lowerBound), in: self)
        return self[lowerBound..<upperBound]
    }

    // get lines from a multiline string
    func lines() -> [String] {
        self.components(separatedBy: .newlines)
    }
}
