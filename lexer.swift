import Foundation

enum Token: Equatable {
    case number(Double)
    case identifier(String)
    case keyword(String)
    case symbol(String)
    case eof
}

class Lexer {
    private let input: String
    private var index: String.Index

    init(input: String) {
        self.input = input
        self.index = input.startIndex
    }

    private var currentChar: Character? {
        return index < input.endIndex ? input[index] : nil
    }

    private func advance() {
        index = input.index(after: index)
    }

    private func isAlpha(_ char: Character) -> Bool {
        return char.isLetter
    }

    private func isAlphaNumeric(_ char: Character) -> Bool {
        return char.isLetter || char.isNumber
    }

    func getNextToken() -> Token {
        while let char = currentChar {
            if char.isWhitespace {
                advance()
                continue
            }

            if char.isNumber {
                return number()
            }

            if isAlpha(char) {
                return identifierOrKeyword()
            }

            if "+-*/()=<>:".contains(char) {
                advance()
                return .symbol(String(char))
            }

            fatalError("Unknown character: \(char)")
        }
        return .eof
    }

    private func number() -> Token {
        var value = ""
        while let char = currentChar, char.isNumber || char == "." {
            value.append(char)
            advance()
        }
        return .number(Double(value)!)
    }

    private func identifierOrKeyword() -> Token {
        var value = ""
        while let char = currentChar, isAlphaNumeric(char) {
            value.append(char)
            advance()
        }
        let keywords = ["DIM", "PRINT", "IF", "THEN", "ELSE", "FOR", "NEXT", "TO"]
        if keywords.contains(value) {
            return .keyword(value)
        }
        return .identifier(value)
    }
}