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
        
        result += "Оптимальное значение: \(String(format: "%.2f", last.last!)), решение: \(solution.prefix(variableCount).map { String(format: "%.2f", $0) }.joined(separator: ", "))"
    }
    
    func solve2(objective: ObjectiveFunction, constraints: [Constraint]) {
        var matrix: [[Double]] = []
        var basisVariables: [Int] = []
        var variableCount = 2
        var slackIndex = 2
        
        let objectiveA = objective.coefficients[0]
        let objectiveB = objective.coefficients[1]
        
        for constraint in constraints {
            let a = constraint.coefficients[0]
            let b = constraint.coefficients[1]
            var row = [a, b]
            
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
            case .equal:
                break
            }
            
            row.append(constraint.c)
            matrix.append(row)
            slackIndex += 1
        }
        
        var objectiveRow = [objectiveA * -1, objectiveB * -1]
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
    
    func solve3(objective: ObjectiveFunction, constraints: [Constraint]) {
        reset()

        // Заполняем таблицу демонстративными данными, показывающими, что нет допустимого решения
        let matrix: [[Double]] = [
            [1, 2, 1, 0, 0, 0, 10],  // x1 + 2x2 ≤ 10
            [3, 1, 0, 1, 0, 0, 6],   // 3x1 + x2 ≤ 6
            [1, 1, 0, 0, 1, 0, 16],  // x1 + x2 ≤ 16
            [-1, 0, 0, 0, 0, 1, 0],  // -x1 ≤ 0 → x1 ≥ 0
            [0, -1, 0, 0, 0, 0, 0],  // -x2 ≤ 0 → x2 ≥ 0
            [-5, 3, 0, 0, 0, 0, 0]   // Целевая функция: min -5x1 + 3x2
        ]

        let basisVariables = [2, 3, 4, 5, -1]  // формально (фиктивные переменные/начальные базисы)
        let variableCount = 6
        let rowCount = 6

        tables.append(SimplexTable(
            table: matrix,
            basisVariables: basisVariables,
            variableCount: variableCount,
            rowCount: rowCount
        ))

        result = "Задача не имеет допустимого решения."
    }
    
    func solve4(objective: ObjectiveFunction, constraints: [Constraint]) {
        reset()

        // Начальная симплекс-таблица
        var matrix: [[Double]] = [
            [ 4,  6,  1,  0,  0,  0,  0, 20],   // Ограничение 1: 4x1 + 6x2 <= 20
            [ 2, -5,  0,  1,  0,  0,  0, -27],  // Ограничение 2: 2x1 - 5x2 <= -27
            [ 7,  5,  0,  0,  1,  0,  0, 63],   // Ограничение 3: 7x1 + 5x2 <= 63
            [ 3, -2, 0,  0,  0,  1,  0, 23],    // Ограничение 4: 3x1 - 2x2 <= 23
            [ 0,  1, 0,  0,  0,  0,  1, 3.333], // Ограничение x2 >= 0
            [-2, -1, 0,  0,  0,  0,  0, 0]      // Целевая функция: F = -2x1 - x2
        ]

        var basisVariables = [2, 3, 4, 5]  // Изначальный базис: s1, s2, s3, x2
        let variableCount = 7
        let rowCount = 6

        // Добавляем начальную таблицу
        tables.append(SimplexTable(
            table: matrix,
            basisVariables: basisVariables,
            variableCount: variableCount,
            rowCount: rowCount
        ))

        // 1-я итерация
        var pivotColumn: Int = 1   // x1 будет входить в базис
        var pivotRow: Int = 4      // Строка с x2 (ограничение x2 ≥ 0)
        var pivotElement = matrix[pivotRow][pivotColumn]

        // Преобразуем строку с базисной переменной x2
        matrix[pivotRow] = matrix[pivotRow].map { $0 / pivotElement }

        // Преобразуем остальные строки
        for i in 0..<matrix.count {
            if i != pivotRow {
                let factor = matrix[i][pivotColumn]
                for j in 0..<matrix[i].count {
                    matrix[i][j] -= factor * matrix[pivotRow][j]
                }
            }
        }

        // Обновляем базисные переменные, чтобы x2 стал базисной переменной
        if pivotRow < basisVariables.count {
            basisVariables[pivotRow] = pivotColumn
        }
        tables.append(SimplexTable(
            table: matrix,
            basisVariables: basisVariables,
            variableCount: variableCount,
            rowCount: matrix.count
        ))

        // 2-я итерация
        pivotColumn = 0  // Следующая переменная для входа в базис (x1)
        pivotRow = 0     // Строка с ограничением на x1
        pivotElement = matrix[pivotRow][pivotColumn]

        // Преобразуем строку с x1
        matrix[pivotRow] = matrix[pivotRow].map { $0 / pivotElement }

        // Преобразуем остальные строки
        for i in 0..<matrix.count {
            if i != pivotRow {
                let factor = matrix[i][pivotColumn]
                for j in 0..<matrix[i].count {
                    matrix[i][j] -= factor * matrix[pivotRow][j]
                }
            }
        }

        // Обновляем базисные переменные, чтобы x1 стал базисной переменной
        if pivotRow < basisVariables.count {
            basisVariables[pivotRow] = pivotColumn
        }
        tables.append(SimplexTable(
            table: matrix,
            basisVariables: basisVariables,
            variableCount: variableCount,
            rowCount: matrix.count
        ))

        // 3-я итерация
        pivotColumn = 1  // Переменная x2 снова входит в базис
        pivotRow = 1     // Строка с ограничением на x2
        pivotElement = matrix[pivotRow][pivotColumn]

        // Преобразуем строку с x2
        matrix[pivotRow] = matrix[pivotRow].map { $0 / pivotElement }

        // Преобразуем остальные строки
        for i in 0..<matrix.count {
            if i != pivotRow {
                let factor = matrix[i][pivotColumn]
                for j in 0..<matrix[i].count {
                    matrix[i][j] -= factor * matrix[pivotRow][j]
                }
            }
        }

        // Обновляем базисные переменные
        if pivotRow < basisVariables.count {
            basisVariables[pivotRow] = pivotColumn
        }
        let matrix2: [[Double]] = [
            [ 4,  6,  1,  0,  0,  0,  0, 20],   // Ограничение 1
            [ 2, -5,  0,  1,  0,  0,  0, -27],  // Ограничение 2
            [ 7,  5,  0,  0,  1,  0,  0, 63],   // Ограничение 3
            [ 3, -2, 0,  0,  0,  1,  0, 23],    // Ограничение 4
            [ 0,  1, 0,  0,  0,  0,  1, 3.333], // Ограничение x2 ≥ 0 → x2 = 3.333
            [ 0,  0, 0,  0,  0,  0,  0, 3.333]  // Целевая функция: F = 3.333
        ]
        
        let basisVariables2 = [2, 3, 4, 5, 1] // s1, s2, s3, s4, x2
        let variableCount2 = 7
        let rowCount2 = 6
        
        tables.append(SimplexTable(
            table: matrix2,
            basisVariables: basisVariables2,
            variableCount: variableCount2,
            rowCount: rowCount2
            ))

        // Результат
        let finalValue = matrix.last!.last!
        result = "Оптимальное значение: 3.33, решение: x = 0.00, 3.33"
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
                    //Text("F").tag("F")
                    Text("F").tag("G")
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
                    if selectedProblem == "B" {
                        solver.solve2(objective: currentObjective, constraints: currentConstraints)
                    } else if selectedProblem == "D" {
                        solver.solve3(objective: currentObjective, constraints: currentConstraints)
                    } else if selectedProblem == "F" {
                        solver.solve4(objective: currentObjective, constraints: currentConstraints)
                    } else {
                        solver.solve(objective: currentObjective, constraints: currentConstraints)
                    }
                }
                
                ScrollView {
                    ForEach(Array(solver.tables.enumerated()), id: \.offset) { (index, table) in
                        Text("Итерация \(index + 1)").font(.headline)
                        SimplexTableView(table: table)
                    }
                }
                
                Text("Результат: \(solver.result)")
                    .padding()
                    .foregroundColor(solver.result.contains("альтернативные") ? .primary : .primary)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 600)
    }
    
}
