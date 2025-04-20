import SwiftUI

struct Constraint {
    let coefficients: [Double]
    let c: Double
    let sign: InequalitySign
}

enum InequalitySign {
    case lessThanOrEqual, greaterThanOrEqual, equal
}

struct ObjectiveFunction {
    let coefficients: [Double]
    let mode: OptimizationMode
}

enum OptimizationMode {
    case max, min
}

struct SimplexTable {
    var table: [[Double]]
    var basisVariables: [Int]
    var variableCount: Int
    var rowCount: Int
}

class SimplexSolver: ObservableObject {
    @Published var tables: [SimplexTable] = []
    @Published var result: String = ""

    func reset() {
        tables.removeAll()
        result = ""
    }

    func solve(objective: ObjectiveFunction, constraints: [Constraint]) {
        guard !constraints.isEmpty else { return }

        var matrix: [[Double]] = []
        var basisVariables: [Int] = []
        
        let variableCount = objective.coefficients.count
        let constraintCount = constraints.count
        let totalVariables = variableCount + constraintCount

        for (i, constraint) in constraints.enumerated() {
            var row = constraint.coefficients

            // Добавим slack/artificial переменные
            for j in 0..<constraintCount {
                row.append(i == j ? (constraint.sign == .lessThanOrEqual ? 1.0 : -1.0) : 0.0)
            }

            row.append(constraint.c)
            matrix.append(row)
            basisVariables.append(variableCount + i)
        }

        var objectiveRow = objective.coefficients.map { objective.mode == .max ? -$0 : $0 }
        for _ in 0..<constraintCount {
            objectiveRow.append(0.0)
        }
        objectiveRow.append(0.0)
        matrix.append(objectiveRow)

        var currentMatrix = matrix
        var currentBasis = basisVariables

        while true {
            let lastRow = currentMatrix.last!
            guard let pivotCol = lastRow.dropLast().enumerated().filter({ $0.element < 0 }).min(by: { $0.element < $1.element })?.offset else {
                break
            }

            var pivotRow: Int? = nil
            var minRatio = Double.infinity

            for i in 0..<(currentMatrix.count - 1) {
                let row = currentMatrix[i]
                let element = row[pivotCol]
                let rhs = row.last!
                if element > 0 {
                    let ratio = rhs / element
                    if ratio < minRatio {
                        minRatio = ratio
                        pivotRow = i
                    }
                }
            }

            guard let pivotRowUnwrapped = pivotRow else {
                result = "Целевая функция не ограничена. Оптимальное решение отсутствует."
                return
            }

            let pivotElement = currentMatrix[pivotRowUnwrapped][pivotCol]
            currentMatrix[pivotRowUnwrapped] = currentMatrix[pivotRowUnwrapped].map { $0 / pivotElement }

            for i in 0..<currentMatrix.count {
                if i != pivotRowUnwrapped {
                    let factor = currentMatrix[i][pivotCol]
                    for j in 0..<currentMatrix[i].count {
                        currentMatrix[i][j] -= factor * currentMatrix[pivotRowUnwrapped][j]
                    }
                }
            }

            currentBasis[pivotRowUnwrapped] = pivotCol
            let table = SimplexTable(table: currentMatrix, basisVariables: currentBasis, variableCount: totalVariables, rowCount: currentMatrix.count)
            tables.append(table)
        }

        var solution = Array(repeating: 0.0, count: totalVariables)
        for (i, index) in currentBasis.enumerated() {
            if index < totalVariables {
                solution[index] = currentMatrix[i].last!
            }
        }

        let nonBasis = Set(0..<totalVariables).subtracting(currentBasis)
        let last = currentMatrix.last!
        let hasAlternativeOptima = nonBasis.contains { last[$0] == 0 }

        if hasAlternativeOptima {
            result += "\n⚠️ Существуют альтернативные оптимальные решения."
        }

        result += "Оптимальное значение: \(last.last!), решение: \(solution.prefix(variableCount).map { String(format: "%.2f", $0) }.joined(separator: ", "))"
    }

    func variableName(for index: Int) -> String {
        return "x\(index + 1)"
    }
}

struct SimplexView: View {
    @StateObject var solver = SimplexSolver()

    var body: some View {
        VStack {
            Button("Решить задачу") {
                solver.solve(objective: exampleAObjective, constraints: exampleAConstraints)
            }

            ScrollView {
                ForEach(Array(solver.tables.enumerated()), id: \.offset) { (index, table) in
                    Text("Итерация \(index + 1)").font(.headline)
                    SimplexTableView(table: table)
                }
            }

            Text("Результат: \(solver.result)")
                .padding()
        }
        .padding()
    }
}

struct SimplexTableView: View {
    let table: SimplexTable

    var header: [String] {
        (0..<table.variableCount).map { "x\($0 + 1)" } + ["b"]
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("базис")
                    .bold()
                    .frame(width: 50)

                ForEach(header, id: \ .self) { label in
                    Text(label)
                        .bold()
                        .frame(width: 50)
                }
            }

            ForEach(0..<table.rowCount, id: \ .self) { i in
                HStack {
                    let basisIndex = table.basisVariables.indices.contains(i) ? table.basisVariables[i] : -1
                    Text(basisIndex >= 0 && basisIndex < table.variableCount ? "x\(basisIndex + 1)" : "Δ")
                        .bold()
                        .frame(width: 50)

                    ForEach(table.table[i], id: \ .self) { value in
                        Text(String(format: "%.2f", value))
                            .frame(width: 50)
                    }
                }
            }
        }
        .padding()
    }
}



// MARK: - Пример задач

/// Задача A
let exampleAConstraints = [
    Constraint(coefficients: [1, 2], c: 8, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 1], c: 6, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 3], c: 3, sign: .greaterThanOrEqual),
    Constraint(coefficients: [1, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 1], c: 0, sign: .greaterThanOrEqual)
]
let exampleAObjective = ObjectiveFunction(coefficients: [2, 5], mode: .max)

/// Задача B
let exampleBConstraints = [
    Constraint(coefficients: [1, 1], c: 8, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 3], c: 6, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 3], c: 3, sign: .greaterThanOrEqual),
    Constraint(coefficients: [1, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 1], c: 0, sign: .greaterThanOrEqual)
]
let exampleBObjective = ObjectiveFunction(coefficients: [1, 3], mode: .min)

/// Задача C
let exampleCConstraints = [
    Constraint(coefficients: [1, 2], c: 9, sign: .greaterThanOrEqual),
    Constraint(coefficients: [1, 4], c: 8, sign: .greaterThanOrEqual),
    Constraint(coefficients: [2, 1], c: 3, sign: .greaterThanOrEqual),
    Constraint(coefficients: [1, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 1], c: 0, sign: .greaterThanOrEqual)
]
let exampleCObjective = ObjectiveFunction(coefficients: [1, 3], mode: .max)

/// Задача D
let exampleDConstraints = [
    Constraint(coefficients: [1, 2], c: 10, sign: .lessThanOrEqual),
    Constraint(coefficients: [3, 1], c: 6, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 1], c: 16, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 1], c: 0, sign: .greaterThanOrEqual)
]
let exampleDObjective = ObjectiveFunction(coefficients: [-5, 3], mode: .min)

/// Задача E
let exampleEConstraints = [
    Constraint(coefficients: [4, 6], c: 20, sign: .greaterThanOrEqual),
    Constraint(coefficients: [2, -5], c: -27, sign: .greaterThanOrEqual),
    Constraint(coefficients: [7, 5], c: 63, sign: .lessThanOrEqual),
    Constraint(coefficients: [3, -2], c: 23, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 1], c: 0, sign: .greaterThanOrEqual)
]
let exampleEObjective = ObjectiveFunction(coefficients: [2, 1], mode: .max)

/// Задача F
let exampleFConstraints = [
    Constraint(coefficients: [4, 6], c: 20, sign: .greaterThanOrEqual),
    Constraint(coefficients: [2, -5], c: -27, sign: .greaterThanOrEqual),
    Constraint(coefficients: [7, 5], c: 63, sign: .lessThanOrEqual),
    Constraint(coefficients: [3, -2], c: 23, sign: .lessThanOrEqual),
    Constraint(coefficients: [0, 1], c: 0, sign: .greaterThanOrEqual)
]
let exampleFObjective = ObjectiveFunction(coefficients: [2, 1], mode: .min)


/// Задача G
let exampleGConstraints = [
    Constraint(coefficients: [1, 3, 5, 3], c: 40, sign: .lessThanOrEqual),
    Constraint(coefficients: [2, 6, 1, 0], c: 50, sign: .lessThanOrEqual),
    Constraint(coefficients: [2, 3, 2, 5], c: 30, sign: .lessThanOrEqual),
    Constraint(coefficients: [1, 0, 0, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 1, 0, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 0, 1, 0], c: 0, sign: .greaterThanOrEqual),
    Constraint(coefficients: [0, 0, 0, 1], c: 0, sign: .greaterThanOrEqual)
]
let exampleGObjective = ObjectiveFunction(coefficients: [7, 8, 6, 5], mode: .max)


struct ContentView: View {
    @State private var selectedProblem = "A"
    @State private var scale: CGFloat = 20.0
    @State private var cValue: Double = 0.0
    
    @StateObject var solver = SimplexSolver()
    
    var infoText: String {
        let modeText = currentObjective.mode == .max ? "максимум" : "минимум"
        let terms = currentObjective.coefficients.enumerated().map { index, coef in
            let sign = coef >= 0 ? "+" : "-"
            let value = String(format: "%.1f", abs(coef))
            return "\(sign) \(value)x\(index + 1)"
        }

        var functionString = terms.joined(separator: " ")
        if functionString.hasPrefix("+") {
            functionString.removeFirst(2)
        }

        return "Необходимо найти \(modeText)\nФункция: z = \(functionString)"
    }

    var currentConstraints: [Constraint] {
        switch selectedProblem {
        case "B": return exampleBConstraints
        case "C": return exampleCConstraints
        case "D": return exampleDConstraints
        case "E": return exampleEConstraints
        case "F": return exampleFConstraints
        case "G": return exampleGConstraints
        default: return exampleAConstraints
        }
    }

    var currentObjective: ObjectiveFunction {
        switch selectedProblem {
        case "B": return exampleBObjective
        case "C": return exampleCObjective
        case "D": return exampleDObjective
        case "E": return exampleEObjective
        case "F": return exampleFObjective
        case "G": return exampleGObjective
        default: return exampleAObjective
        }
    }

    var body: some View {
        VStack {
            HStack {
                Picker("Выберите задачу", selection: $selectedProblem) {
                    Text("A").tag("A")
                    Text("B").tag("B")
                    Text("C").tag("C")
                    Text("D").tag("D")
                    Text("E").tag("E")
                    Text("F").tag("F")
                    Text("G").tag("G")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Text(infoText)
                    .font(.headline)
                    .padding()
            }
            
            VStack {
                Button("Решить задачу") {
                    solver.reset()
                    solver.solve(objective: currentObjective, constraints: currentConstraints)
                }
                
                ScrollView {
                    ForEach(Array(solver.tables.enumerated()), id: \.offset) { (index, table) in
                        Text("Итерация \(index + 1)").font(.headline)
                        SimplexTableView(table: table)
                    }
                }
                
                Text("Результат: \(solver.result)")
                    .padding()
                    .foregroundColor(solver.result.contains("альтернативные") ? .orange : .primary)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 600)
    }
    
}
