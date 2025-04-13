import SwiftUI

struct Constraint {
    let a: Double
    let b: Double
    let c: Double
    let sign: InequalitySign
}

enum InequalitySign {
    case lessThanOrEqual, greaterThanOrEqual
}

struct ObjectiveFunction {
    let a: Double
    let b: Double
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
        var matrix: [[Double]] = []
        var basisVariables: [Int] = []
        var variableCount = 2
        var slackIndex = 2

        for constraint in constraints {
            var row = [constraint.a, constraint.b]

            for _ in 0..<constraints.count {
                row.append(0)
            }

            switch constraint.sign {
            case .lessThanOrEqual:
                row[slackIndex] = 1
                basisVariables.append(slackIndex)
            case .greaterThanOrEqual:
                row[slackIndex] = -1
                basisVariables.append(slackIndex)
            }

            row.append(constraint.c)
            matrix.append(row)
            slackIndex += 1
        }

        var objectiveRow = [objective.a * -1, objective.b * -1]
        for _ in 0..<constraints.count {
            objectiveRow.append(0)
        }
        objectiveRow.append(0)
        matrix.append(objectiveRow)

        variableCount = objectiveRow.count - 1

        while true {
            let lastRow = matrix.last!
            guard let pivotCol = lastRow.dropLast().enumerated().filter({ $0.element < 0 }).min(by: { $0.element < $1.element })?.offset else {
                break
            }

            var pivotRow: Int? = nil
            var minRatio = Double.infinity

            for i in 0..<(matrix.count - 1) {
                let row = matrix[i]
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

            let pivotElement = matrix[pivotRowUnwrapped][pivotCol]
            matrix[pivotRowUnwrapped] = matrix[pivotRowUnwrapped].map { $0 / pivotElement }

            for i in 0..<matrix.count {
                if i != pivotRowUnwrapped {
                    let factor = matrix[i][pivotCol]
                    for j in 0..<matrix[i].count {
                        matrix[i][j] -= factor * matrix[pivotRowUnwrapped][j]
                    }
                }
            }

            basisVariables[pivotRowUnwrapped] = pivotCol
            let table = SimplexTable(table: matrix, basisVariables: basisVariables, variableCount: variableCount, rowCount: matrix.count)
            tables.append(table)
        }
        
        let solution = Array(repeating: 0.0, count: variableCount)
        var finalSolution = solution
        for (i, basis) in basisVariables.enumerated() {
            if basis < variableCount {
                finalSolution[basis] = matrix[i].last!
            }
        }
        
        // Проверка на альтернативные оптимумы
        let lastRow = matrix.last!
        let nonBasisVariables = Set(0..<variableCount).subtracting(basisVariables)

        let hasAlternativeOptima = nonBasisVariables.contains { lastRow[$0] == 0 }

        if hasAlternativeOptima {
            result += "\n⚠️ Существуют альтернативные оптимальные решения."
        }

        let optimalValue = matrix.last!.last!
        result += "Оптимальное значение: \(optimalValue), решение: x = \(finalSolution)"
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

/// Задача А
let exampleAConstraints = [
    Constraint(a: 1, b: 2, c: 8, sign: .lessThanOrEqual),
    Constraint(a: 1, b: 1, c: 6, sign: .lessThanOrEqual),
    Constraint(a: 1, b: 3, c: 3, sign: .greaterThanOrEqual),
    Constraint(a: 1, b: 0, c: 0, sign: .greaterThanOrEqual),
    Constraint(a: 0, b: 1, c: 0, sign: .greaterThanOrEqual)
]
let exampleAObjective = ObjectiveFunction(a: 2, b: 5, mode: .max)

/// Задача B
let exampleBConstraints = [
    Constraint(a: 1, b: 1, c: 8, sign: .lessThanOrEqual),
    Constraint(a: 1, b: 3, c: 6, sign: .lessThanOrEqual),
    Constraint(a: 1, b: 3, c: 3, sign: .greaterThanOrEqual),
    Constraint(a: 1, b: 0, c: 0, sign: .greaterThanOrEqual),
    Constraint(a: 0, b: 1, c: 0, sign: .greaterThanOrEqual)
]
let exampleBObjective = ObjectiveFunction(a: 1, b: 3, mode: .min)

/// Задача C
let exampleCConstraints = [
    Constraint(a: 1, b: 2, c: 9, sign: .greaterThanOrEqual),
    Constraint(a: 1, b: 4, c: 8, sign: .greaterThanOrEqual),
    Constraint(a: 2, b: 1, c: 3, sign: .greaterThanOrEqual),
    Constraint(a: 1, b: 0, c: 0, sign: .greaterThanOrEqual),
    Constraint(a: 0, b: 1, c: 0, sign: .greaterThanOrEqual),
]
let exampleCObjective = ObjectiveFunction(a: 1, b: 3, mode: .max)

/// Задача D
let exampleDConstraints = [
    Constraint(a: 1, b: 2, c: 10, sign: .lessThanOrEqual),
    Constraint(a: 3, b: 1, c: 6, sign: .lessThanOrEqual),
    Constraint(a: 1, b: 1, c: 16, sign: .lessThanOrEqual),
    Constraint(a: 1, b: 0, c: 0, sign: .greaterThanOrEqual),
    Constraint(a: 0, b: 1, c: 0, sign: .greaterThanOrEqual)
]
let exampleDObjective = ObjectiveFunction(a: -5, b: 3, mode: .min)


struct ContentView: View {
    @State private var selectedProblem = "A"
    @State private var scale: CGFloat = 20.0
    @State private var cValue: Double = 0.0
    
    @StateObject var solver = SimplexSolver()
    
    var infoText: String {
        let modeText = currentObjective.mode == .max ? "максимум" : "минимум"
        let a = currentObjective.a
        let b = currentObjective.b
        let aStr = String(format: "%.1f", a)
        let bStr = String(format: "%.1f", b)
        
        let signB = b >= 0 ? "+" : "-"
        let bAbs = String(format: "%.1f", abs(b))
        
        return "Необходимо найти \(modeText)\nФункция: z = \(aStr)x \(signB) \(bAbs)y"
    }

    var currentConstraints: [Constraint] {
        switch selectedProblem {
        case "B": return exampleBConstraints
        case "C": return exampleCConstraints
        case "D": return exampleDConstraints
        default: return exampleAConstraints
        }
    }

    var currentObjective: ObjectiveFunction {
        switch selectedProblem {
        case "B": return exampleBObjective
        case "C": return exampleCObjective
        case "D": return exampleDObjective
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
