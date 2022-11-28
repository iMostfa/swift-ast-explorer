import Foundation
import SwiftSyntax

final class TokenVisitor: SyntaxRewriter {
    var list = [String]()
    var codeList = [String]()

    var tree = [Node]()
    var current: Node!


    var isDetectingLocalizaionDecl: Bool = false
    var isLocalInsideFunction: Bool = false
    var isLocalizaionFunctionCall: Bool = false
    var isDetectingLocalizaionString: Bool = false

    var statistics = SyntaxStatistics()

    var row = 0
    var column = 0

    override func visitPre(_ node: Syntax) {
        var syntax = "\(node.syntaxNodeType)"
        if syntax.hasSuffix("Syntax") {
            syntax = String(syntax.dropLast(6))
        }
        if isDetectingLocalizaionDecl {
            print("❤️ -> \(syntax)", current.text)
        }
        list.append("<span class='\(syntax)' data-tooltip-title='Syntax' data-tooltip-content='\(syntax)'>")

        let n = Node(text: syntax)
        n.range.startRow = row
        n.range.startColumn = column
        n.range.endRow = row
        n.range.endColumn = column
        if current == nil {
            tree.append(n)
        } else {
            current.add(node: n)
            statistics.append(node: n)
        }
        current = n
    }

    override func visit(_ token: TokenSyntax) -> Syntax {
//        print("Visit is called for token \(token.text)")
        current.text = token.text
        
//        let result = "\(token.text)"
//            .split(separator: "_")  // split to components
//            .map { String($0) }   // convert subsequences to String
//            .enumerated()  // get indices
//            .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() } // added lowercasing
//            .joined() // join to one string
//
//
//        list.append("<span class='token \(kind)' data-tooltip-title='Token' data-tooltip-content='\(token.tokenKind)'>\(escapeHtmlSpecialCharacters("LocalizationKey.\(result)"))</span>")
//
        
        if token.text.split(separator: "_").count >= 3 {
            print("Unhandled Text")
            isDetectingLocalizaionString = true
        }


        if current.text == "localize" {
            print("Current is detected \(current.text)")
            if let declarationParent = current.parent?.parent?.parent?.parent?.text, declarationParent == "VariableDecl" {
                print("We have a localizeVariable")
                isDetectingLocalizaionDecl = true
            } else if let functionParent = current.parent?.text, functionParent == "FunctionParameter"  {
                isLocalInsideFunction = true
            } else if let functionParent = current.parent?.text,
                      functionParent == "MemberAccessExpr",
                      (current.parent?.parent?.text ?? "") == "FunctionCallExpr" {
                isLocalizaionFunctionCall = true
            } else {
                print("Unhandled Localizaions")
            }
        }
        
        current.token = Node.Token(kind: "\(token.tokenKind)", leadingTrivia: "", trailingTrivia: "")

        current.range.startRow = row
        current.range.startColumn = column

        token.leadingTrivia.forEach { (piece) in
            let trivia = processTriviaPiece(piece)
            list.append(trivia)
            codeList.append(trivia)
            current.token?.leadingTrivia += replaceSymbols(text: trivia)
        }
       
        
//        if "\(token.tokenKind)".contains("stringSegment") || "\(token.tokenKind)".contains("stringQuote") {
//            if "\(token.tokenKind)".contains("stringSegment")  {
//                if  token.text.split(separator: "_").count >= 3 {
//                    processToken(token,isSpecial: true)
//                } else {
//                    processToken(token)
//
//                }
//            } else {
//
//            }
//
//        } else {
//
//        }
        processToken(token)
        
        token.trailingTrivia.forEach { (piece) in
            let trivia = processTriviaPiece(piece)
            list.append(trivia)
            codeList.append(trivia)
            current.token?.trailingTrivia += replaceSymbols(text: trivia)
        }

        current.range.endRow = row
        current.range.endColumn = column

        /*
         if syntax.hasPrefix("StringSegment") {
             let detectedString = node.description
             
             //TODO: Support . ? and maybe better way to know if's a key.
             
             if detectedString.split(separator: "_").count >= 3 {
                 let replacingNodeType = node.parent?.parent?.syntaxNodeType
                 if var replacingNode = node.parent?.parent {
                     replacingNode = .init(FunctionDeclSyntax.init({ builder in
                         
                     }))
                 }
             }
             
         }
         */
        return token._syntaxNode
    }

    override func visitPost(_ node: Syntax) {
        list.append("</span>")
        current.range.endRow = row
        current.range.endColumn = column
        print("Current is \(current.text) and going to be \(current.parent?.text ?? "")")
        current = current.parent
    }

    private func processToken(_ token: TokenSyntax, isSpecial: Bool = false) {
        var kind = "\(token.tokenKind)"
        if let index = kind.firstIndex(of: "(") {
            kind = String(kind.prefix(upTo: index))
        }
        if kind.hasSuffix("Keyword") {
            kind = "keyword"
        }

      /*  if token.text.split(separator: "_").count >= 3 {
            let result = "\(token.text)"
                .split(separator: "_")  // split to components
                .map { String($0) }   // convert subsequences to String
                .enumerated()  // get indices
                .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() } // added lowercasing
                .joined() // join to one string

            
            list.append("<span class='token \(kind)' data-tooltip-title='Token' data-tooltip-content='\(token.tokenKind)'>\(escapeHtmlSpecialCharacters("LocalizationKey.\(result)"))</span>")
            
            print("Unhandled Text")
 
        } else { */
        if isDetectingLocalizaionString {
            if kind == "stringQuote" {
                print("Not going to add String Quote")
                isDetectingLocalizaionString = false
            } else {
                let result = "\(token.text)"
                    .split(separator: "_")  // split to components
                    .map { String($0) }   // convert subsequences to String
                    .enumerated()  // get indices
                    .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() } // added lowercasing
                    .joined() // join to one string

                list.remove(at: list.count - 5)
                list.remove(at: list.count - 4)
                
                list.append("<span class='token \(kind)' data-tooltip-title='Token' data-tooltip-content='\(token.tokenKind)'>\(escapeHtmlSpecialCharacters(".\(result)"))</span>")
            }
        } else if isDetectingLocalizaionDecl, token.text == "String" {
                list.append("<span class='token \(kind)' data-tooltip-title='Token' data-tooltip-content='\(token.tokenKind)'>\(escapeHtmlSpecialCharacters("LocalizationKey"))</span>")
                
                isDetectingLocalizaionDecl = false
            } else if isLocalInsideFunction, token.text == "String" {
                list.append("<span class='token \(kind)' data-tooltip-title='Token' data-tooltip-content='\(token.tokenKind)'>\(escapeHtmlSpecialCharacters("LocalizationKey"))</span>")
                isLocalInsideFunction = false
            } else if isLocalizaionFunctionCall, token.text == "localize" {
                list.append("<span class='token \(kind)' data-tooltip-title='Token' data-tooltip-content='\(token.tokenKind)'>\(escapeHtmlSpecialCharacters("localizeKey"))</span>")

                isLocalizaionFunctionCall = false
            } else {
                list.append("<span class='token \(kind)' data-tooltip-title='Token' data-tooltip-content='\(token.tokenKind)'>\(escapeHtmlSpecialCharacters(token.text))</span>")
            }
        
        codeList.append(token.text)
        column += token.text.count
    }

    private func processTriviaPiece(_ piece: TriviaPiece) -> String {
        func wrapWithSpanTag(class c: String, text: String) -> String {
            return "<span class='\(c)' data-tooltip-title='Trivia' data-tooltip-content='\(c)'>\(escapeHtmlSpecialCharacters(text))</span>"
        }

        var trivia = ""
        switch piece {
        case .spaces(let count):
            trivia += String(repeating: "&nbsp;", count: count)
            column += count
        case .tabs(let count):
            trivia += String(repeating: "&nbsp;", count: count * 2)
            column += count * 2
        case .newlines(let count), .carriageReturns(let count), .carriageReturnLineFeeds(let count):
            trivia += String(repeating: "<br>", count: count)
            row += count
            column = 0
        case .lineComment(let text):
            trivia += wrapWithSpanTag(class: "lineComment", text: text)
            processComment(text: text)
        case .blockComment(let text):
            trivia += wrapWithSpanTag(class: "blockComment", text: text)
            processComment(text: text)
        case .docLineComment(let text):
            trivia += wrapWithSpanTag(class: "docLineComment", text: text)
            processComment(text: text)
        case .docBlockComment(let text):
            trivia += wrapWithSpanTag(class: "docBlockComment", text: text)
            processComment(text: text)
        case .verticalTabs, .formfeeds, .garbageText:
            break
        }
        return trivia
    }

    private func replaceSymbols(text: String) -> String {
        return text.replacingOccurrences(of: "&nbsp;", with: "␣").replacingOccurrences(of: "<br>", with: "↲")
    }

    private func processComment(text: String) {
        let comments = text.split(separator: "\n", omittingEmptySubsequences: false)
        row += comments.count - 1
        column += comments.last!.count
    }

    private func escapeHtmlSpecialCharacters(_ string: String) -> String {
        var newString = string
        let specialCharacters = [
            ("&", "&amp;"),
            ("<", "&lt;"),
            (">", "&gt;"),
            ("\"", "&quot;"),
            ("'", "&apos;"),
        ];
        for (unescaped, escaped) in specialCharacters {
            newString = newString.replacingOccurrences(of: unescaped, with: escaped, options: .literal, range: nil)
        }
        return newString
    }
}
