//
//  ContentView.swift
//  test
//
//  Created by Lukas Pistrol on 20.04.22.
//

import SwiftUI
import Neon
import tree_sitter
import tree_sitter_language_resources
import SwiftTreeSitter
import SwiftOverlayShims

struct ContentView: View {

    // some static test data
    @State
    var testString: String = """
import GitClient
import SwiftUI

/// The style for issues display
///  - **inline**: Issues show inline
///  - **minimized** Issues show minimized
enum Issues: String, Codable {
    case inline
    case minimized
}

/// The style for file extensions display
///  - **hideAll**: File extensions are hidden
///  - **showAll** File extensions are visible
///  - **showOnly** Display specified file extensions
enum FileExtensions: String, Codable {
    case hideAll
    case showAll
    case showOnly
}

public enum StatusBarTab: String, CaseIterable, Identifiable {
    case terminal
    case debugger
    case output

    public var id: String { return self.rawValue }
    public static var allOptions: [String] {
        return StatusBarTab.allCases.map { $0.rawValue.capitalized }
    }
}

/// # StatusBarModel
///
/// A model class to host and manage data for the ``StatusBarView``
///
public class StatusBarModel: ObservableObject {
    /// The selected tab in the main section.
    /// - **0**: Terminal
    /// - **1**: Debugger
    /// - **2**: Output
    @Published
    public var selectedTab: Int = 0

    // TODO: Implement logic for updating values
    /// Returns number of errors during comilation
    @Published
    public var errorCount: Int = 0 // Implementation missing

    /// Returns number of warnings during comilation
    @Published
    public var warningCount: Int = 0 // Implementation missing

    /// The selected branch from the GitClient
    @Published
    public var selectedBranch: String?

    /// State of pulling from git
    @Published
    public var isReloading: Bool = false // Implementation missing

    /// Returns the current line of the cursor in an editing view
    @Published
    public var currentLine: Int = 1 // Implementation missing

    /// Returns the current column of the cursor in an editing view
    @Published
    public var currentCol: Int = 1 // Implementation missing

    /// Returns true when the drawer is visible
    @Published
    public var isExpanded: Bool = false

    /// Returns true when the drawer is visible
    @Published
    public var isMaximized: Bool = false

    /// The current height of the drawer. Zero if hidden
    @Published
    public var currentHeight: Double = 0

    /// Indicates whether the drawer is beeing resized or not
    @Published
    public var isDragging: Bool = false

    /// Indicates whether the breakpoint is enabled or not
    @Published
    public var isBreakpointEnabled: Bool = true

    /// Search value to filter in drawer
    @Published
    public var searchText: String = ""

    /// Returns the font for status bar items to use
    private(set) var toolbarFont: Font = .system(size: 11)

    /// A GitClient instance
    private(set) var gitClient: GitClient

    /// The base URL of the workspace
    private(set) var workspaceURL: URL

    /// The maximum height of the drawer
    /// when isMaximized is true the height gets set to maxHeight
    private(set) var maxHeight: Double = 5000

    /// The default height of the drawer
    private(set) var standardHeight: Double = 300

    /// The minimum height of the drawe
    private(set) var minHeight: Double = 100

    // TODO: Add @Published vars for indentation, encoding, linebreak

    /// Initialize with a GitClient
    /// - Parameter workspaceURL: the current workspace URL
    ///
    public init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
        gitClient = GitClient.default(
            directoryURL: workspaceURL,
            shellClient: .live
        )
        do {
            let selectedBranch = try gitClient.getCurrentBranchName()
            self.selectedBranch = selectedBranch
        } catch {
            selectedBranch = nil
        }
    }

    // TODO: Implement reflecting Show Live Issues preference and remove disabled modifier
     var showLiveIssuesSection: some View {
         PreferencesSection("", hideLabels: false, align: .center) {
             Toggle(isOn: $prefs.preferences.general.showLiveIssues) {
                 Text("Show Live Issues")
             }
             .toggleStyle(.checkbox)
         }
         .disabled(true)
     }
}
"""

    @State
    var attributedTest: NSMutableAttributedString = .init("")

    var body: some View {
        EditorView(content: $testString, language: lang)
//        ScrollView {
//            Text(AttributedString(attributedTest))
//                .textSelection(.enabled)
//                .padding()
//                .frame(maxWidth: .infinity, alignment: .leading)
//        }
        .frame(minWidth: 1000)
        .task {
            // For debugging or when just using a simple `Text()` as seen above
//            try? setup()
        }
    }

    let swift = LanguageResource.swift
    var lang: Language { Language(language: swift.parser) }


    /* -----------------------------------------------------------
     Just for displaying the basic flow of using swift-tree-sitter
     -----------------------------------------------------------*/
    func setup() throws {
        // construct a NSAttributedString with default attributes
        attributedTest = .init(string: testString, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.textColor
        ])

        // create a parser and set the language
        let parser = Parser()
        try parser.setLanguage(lang)

        // get the highlight query url from `LanguageResource`
        let url = swift.highlightQueryURL
        // create a query object of the data contained in the `*.scm` file
        let query = try lang.query(contentsOf: url!)

        let start = CFAbsoluteTimeGetCurrent()
        guard let tree = parser.parse(testString),
              let rootNode = tree.rootNode else { return}

        // DEBUG only
        printTree(node: rootNode, query: query)

        let range = NSRange(location: 0, length: testString.count)

        // create a query for the whole dowcument and pass in the tree object
        let cursor = query.execute(node: rootNode, in: tree)

        // set the range in the document to apply the query to
        cursor.setRange(range)
        var flag = true
        while flag {
            // get the next capture, if this is nil -> break
            guard let match = cursor.nextCapture()
            else { flag = false; break }

            let capture = (name: match.name, range: match.node.range)
            print("\(capture.range.description) \t| \(capture.name ?? "") \t\t | \(testString[capture.range])")

            // set the according attributes for the range of the current node
            attributedTest.setAttributes([
                .foregroundColor: colorForCapture(capture.name),
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            ], range: capture.range)
        }
        let end = CFAbsoluteTimeGetCurrent()

        print("parsed tree in: \(end-start) seconds")

        // print available strings
        print("STRING:")
        for i in 0..<query.stringCount {
            print(query.stringName(for: i) ?? "")
        }
        // print available captures
        print("CAPTURE:")
        for i in 0..<query.captureCount {
            print(query.captureName(for: i) ?? "")
        }
    }

    // recoursively get and print the tree structure to the console
    func printTree(node: Node, level: Int = 0, query: Query) {
        print(tabs(level) + "- - - - - - - - - - - - - - - - - - - ")
        print(tabs(level) + "| type:\t\t\(node.nodeType ?? "--")")
        print(tabs(level) + "| range:\t\(node.range))")
        print(tabs(level) + "| content:\t\(testString[node.range].replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: ""))")
        print(tabs(level) + "| \(node.description)")
        node.enumerateChildren { child in
            printTree(node: child, level: level + 1, query: query)
        }
    }

    // replace with theme values
    func colorForCapture(_ capture: String?) -> NSColor {
        switch capture {
        case "include", "constructor", "keyword", "boolean", "variable.builtin", "keyword.return", "keyword.function": return .magenta
        case "comment": return .systemGreen
        case "variable": return .systemTeal
        case "function": return .systemMint
        case "number": return .systemYellow
        case "string": return .systemRed
        case "type": return .systemPurple
        case "": return .orange
        default: return .textColor
        }
    }

    // just for printing out the tree structure
    func tabs(_ count: Int) -> String {
        var string = ""
        for _ in 0..<count {
            string.append("\t")
        }
        return string
    }

    /*----------------
     End of debug code
     ----------------*/
}

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
