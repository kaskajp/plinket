import Foundation

/// Release entries from the app's bundled Keep a Changelog document.
public struct Changelog: Sendable {
    public struct Release: Equatable, Sendable {
        public let version: String
        public let date: String
        public let blocks: [Block]

        public var isUnreleased: Bool { version == "Unreleased" }
    }

    public enum Block: Equatable, Sendable {
        case heading(String)
        case paragraph(String)
        case bullet(String)
    }

    public let releases: [Release]

    public init(markdown: String) {
        releases = markdown.components(separatedBy: "\n## [").dropFirst().compactMap { entry in
            let lines = entry.components(separatedBy: .newlines)
            guard let header = lines.first, let end = header.firstIndex(of: "]") else { return nil }
            let version = String(header[..<end])
            let date = String(header[header.index(after: end)...]).trimmingCharacters(in: .whitespaces)
            let blocks = Self.blocks(from: lines.dropFirst())
            guard !blocks.isEmpty else { return nil }
            return Release(version: version, date: date.hasPrefix("- ") ? String(date.dropFirst(2)) : date, blocks: blocks)
        }
    }

    private static func blocks(from lines: ArraySlice<String>) -> [Block] {
        var blocks: [Block] = []
        var startsParagraph = true
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else {
                startsParagraph = true
                continue
            }
            guard !(line.hasPrefix("[") && line.contains("]: ")) else { continue }
            if line.hasPrefix("### ") {
                blocks.append(.heading(String(line.dropFirst(4))))
                startsParagraph = true
                continue
            }
            if line.hasPrefix("- ") {
                blocks.append(.bullet(String(line.dropFirst(2))))
                startsParagraph = false
                continue
            }
            if !startsParagraph, let last = blocks.last {
                switch last {
                case .paragraph(let text):
                    blocks[blocks.count - 1] = .paragraph(text + " " + line)
                case .bullet(let text):
                    blocks[blocks.count - 1] = .bullet(text + " " + line)
                case .heading:
                    blocks.append(.paragraph(line))
                }
                continue
            }
            blocks.append(.paragraph(line))
            startsParagraph = false
        }
        return blocks
    }
}
