import LLVM

class CodeGenerator {
    let module: Module
    let builder: IRBuilder
    var namedValues: [String: IRValue] = [:]

    init(moduleName: String) {
        module = Module(name: moduleName)
        builder = IRBuilder(module: module)
    }

    func generateCode(for node: ASTNode) -> IRValue {
        switch node {
        case .number(let value):
            return FloatType.double.constant(value)
        case .variable(let name):
            guard let value = namedValues[name] else {
                fatalError("Undefined variable: \(name)")
            }
            return builder.buildLoad(value, name: name)
        case .binaryOperation(let left, let op, let right):
            let leftValue = generateCode(for: left)
            let rightValue = generateCode(for: right)
            switch op {
            case "+":
                return builder.buildAdd(leftValue, rightValue)
            case "-":
                return builder.buildSub(leftValue, rightValue)
            case "*":
                return builder.buildMul(leftValue, rightValue)
            case "/":
                return builder.buildDiv(leftValue, rightValue)
            default:
                fatalError("Unexpected binary operation")
            }
        case .functionCall(let name, let args):
            guard let function = module.function(named: name) else {
                fatalError("Undefined function: \(name)")
            }
            let argValues = args.map { generateCode(for: $0) }
            return builder.buildCall(function, args: argValues)
        case .dim(let name):
            let alloca = builder.buildAlloca(type: FloatType.double, name: name)
            namedValues[name] = alloca
            return alloca
        case .print(let value):
            let printFunc = createPrintFunction()
            let valueToPrint = generateCode(for: value)
            return builder.buildCall(printFunc, args: [valueToPrint])
        case .ifThenElse(let condition, let thenStatements, let elseStatements):
            return generateIfThenElse(condition: condition, thenStatements: thenStatements, elseStatements: elseStatements)
        case .forLoop(let varName, let start, let end, let body):
            return generateForLoop(varName: varName, start: start, end: end, body: body)
        }
    }

    private func createPrintFunction() -> Function {
        if let printFunction = module.function(named: "print") {
            return printFunction
        }

        let printType = FunctionType([FloatType.double], VoidType())
        let printFunction = builder.addFunction("print", type: printType)
        let entryBB = printFunction.appendBasicBlock(named: "entry")

        builder.positionAtEnd(of: entryBB)
        let fmt = builder.buildGlobalStringPtr("%f\n", name: "fmt")
        let printf = module.addFunction("printf", type: FunctionType([PointerType(pointee: IntType.int8)], IntType.int32, variadic: true))
        builder.buildCall(printf, args: [fmt, printFunction.parameters[0]])
        builder.buildRetVoid()

        return printFunction
    }

    private func generateIfThenElse(condition: ASTNode, thenStatements: [ASTNode], elseStatements: [ASTNode]?) -> IRValue {
        let conditionValue = generateCode(for: condition)
        let zero = FloatType.double.constant(0)
        let conditionBool = builder.buildFCmp(conditionValue, zero, .orderedNotEqual)
        let function = builder.insertBlock!.parent!

        let thenBB = function.appendBasicBlock(named: "then")
        let elseBB = function.appendBasicBlock(named: "else")
        let mergeBB = function.appendBasicBlock(named: "ifcont")

        builder.buildCondBr(condition: conditionBool, then: thenBB, else: elseBB)

        builder.positionAtEnd(of: thenBB)
        thenStatements.forEach { generateCode(for: $0) }
        builder.buildBr(mergeBB)

        builder.positionAtEnd(of: elseBB)
        elseStatements?.forEach { generateCode(for: $0) }
        builder.buildBr(mergeBB)

        builder.positionAtEnd(of: mergeBB)

        return zero // Placeholder return value
    }

    private func generateForLoop(varName: String, start: ASTNode, end: ASTNode, body: [ASTNode]) -> IRValue {
        let function = builder.insertBlock!.parent!

        let startValue = generateCode(for: start)
        let endValue = generateCode(for: end)

        let alloca = builder.buildAlloca(type: FloatType.double, name: varName)
        builder.buildStore(startValue, to: alloca)
        namedValues[varName] = alloca

        let loopBB = function.appendBasicBlock(named: "loop")
        let afterBB = function.appendBasicBlock(named: "afterloop")

        builder.buildBr(loopBB)
        builder.positionAtEnd(of: loopBB)

        body.forEach { generateCode(for: $0) }

        let step = FloatType.double.constant(1.0)
        let currentVar = builder.buildLoad(alloca, name: varName)
        let nextVar = builder.buildAdd(currentVar, step)
        builder.buildStore(nextVar, to: alloca)

        let endCondition = builder.buildFCmp(nextVar, endValue, .orderedLessThanEqual)
        builder.buildCondBr(condition: endCondition, then: loopBB, else: afterBB)

        builder.positionAtEnd(of: afterBB)

        return FloatType.double.constant(0) // Placeholder return value
    }

    func createMainFunction(for nodes: [ASTNode]) {
        let mainType = FunctionType([], IntType.int32)
        let mainFunc = builder.addFunction("main", type: mainType)
        let entryBB = mainFunc.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entryBB)
        
        nodes.forEach { generateCode(for: $0) }

        builder.buildRet(IntType.int32.constant(0))
    }
}