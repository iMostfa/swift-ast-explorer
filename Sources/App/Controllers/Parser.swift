import Foundation
import SwiftSyntax
import SwiftSyntaxParser

struct Parser {
    static func parse(code: String) throws -> SyntaxResponse {
        let sourceFile = try SyntaxParser.parse(source: code, enableBareSlashRegexLiteral: true)

        let visitor = TokenVisitor()
        visitor.visitPre(sourceFile._syntaxNode)
        _ = visitor.visit(sourceFile)

        let html = "\(visitor.list.joined())"

        let tree = visitor.tree
        let encoder = JSONEncoder()
        let json = String(data: try encoder.encode(tree), encoding: .utf8) ?? "{}"
        let sourceCode = visitor.codeList.joined()
        let statistics = visitor.statistics.sorted

        return SyntaxResponse(syntaxHTML: html, syntaxJSON: json, statistics: statistics, swiftVersion: swiftVersion)
    }
}
