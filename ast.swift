indirect enum ASTNode {
    case number(Double)
    case variable(String)
    case binaryOperation(ASTNode, String, ASTNode)
    case functionCall(String, [ASTNode])
    case dim(String)
    case print(ASTNode)
    case ifThenElse(ASTNode, [ASTNode], [ASTNode]?)
    case forLoop(String, ASTNode, ASTNode, [ASTNode])
}

class Parser {
    private var lexer: Lexer
    private var currentToken: Token

    init(lexer: Lexer) {
        self.lexer = lexer
        self.currentToken = lexer.getNextToken()
    }

    private func eat(_ token: Token) {
        if currentToken == token {
            currentToken = lexer.getNextToken()
        } else {
            fatalError("Unexpected token: \(currentToken)")
        }
    }

    func parse() -> [ASTNode] {
        var nodes = [ASTNode]()
        while currentToken != .eof {
            nodes.append(statement())
        }
        return nodes
    }

    private func statement() -> ASTNode {
        switch currentToken {
        case .keyword("DIM"):
            return parseDim()
        case .keyword("PRINT"):
            return parsePrint()
        case .keyword("IF"):
            return parseIf()
        case .keyword("FOR"):
            return parseFor()
        default:
            return expr()
        }
    }

    private func parseDim() -> ASTNode {
        eat(.keyword("DIM"))
        guard case .identifier(let name) = currentToken else {
            fatalError("Expected variable name after DIM")
        }
        eat(currentToken)
        return .dim(name)
    }

    private func parsePrint() -> ASTNode {
        eat(.keyword("PRINT"))
        let value = expr()
        return .print(value)
    }

    private func parseIf() -> ASTNode {
        eat(.keyword("IF"))
        let condition = expr()
        eat(.keyword("THEN"))
        var thenStatements = [ASTNode]()
        while currentToken != .keyword("ELSE") && currentToken != .eof && currentToken != .keyword("END") {
            thenStatements.append(statement())
        }
        var elseStatements: [ASTNode]? = nil
        if currentToken == .keyword("ELSE") {
            eat(.keyword("ELSE"))
            elseStatements = []
            while currentToken != .keyword("END") && currentToken != .eof {
                elseStatements?.append(statement())
            }
        }
        if currentToken == .keyword("END") {
            eat(.keyword("END"))
        }
        return .ifThenElse(condition, thenStatements, elseStatements)
    }

    private func parseFor() -> ASTNode {
        eat(.keyword("FOR"))
        guard case .identifier(let varName) = currentToken else {
            fatalError("Expected variable name after FOR")
        }
        eat(currentToken)
        eat(.symbol("="))
        let start = expr()
        eat(.keyword("TO"))
        let end = expr()
        var body = [ASTNode]()
        while currentToken != .keyword("NEXT") && currentToken != .eof {
            body.append(statement())
        }
        if currentToken == .keyword("NEXT") {
            eat(.keyword("NEXT"))
        }
        return .forLoop(varName, start, end, body)
    }

    private func factor() -> ASTNode {
        let token = currentToken
        switch token {
        case .number(let value):
            eat(token)
            return .number(value)
        case .identifier(let name):
            eat(token)
            return .variable(name)
        case .symbol("("):
            eat(token)
            let node = expr()
            eat(.symbol(")"))
            return node
        default:
            fatalError("Unexpected token in factor: \(token)")
        }
    }

    private func term() -> ASTNode {
        var node = factor()
        while currentToken == .symbol("*") || currentToken == .symbol("/") {
            let token = currentToken
            eat(token)
            node = .binaryOperation(node, token.description, factor())
        }
        return node
    }

    private func expr() -> ASTNode {
        var node = term()
        while currentToken == .symbol("+") || currentToken == .symbol("-") {
            let token = currentToken
            eat(token)
            node = .binaryOperation(node, token.description, term())
        }
        return node
    }
}