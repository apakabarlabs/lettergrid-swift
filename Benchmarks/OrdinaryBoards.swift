import LetterGrid

@MainActor
enum OrdinaryBoards {
  private static let screens = [
    ["HOUSE", "HOME", "DOOR", "WINDOW"],
    ["ROOF", "FLOOR", "WALL"],
    ["KEY", "YARD", "GATE"],
  ]
  private static let directions: [Direction] = [.right, .down]

  static func run() throws {
    let words = screens.flatMap { $0 }
    let weights = Dictionary(words.joined().map { (String($0), 1.0) }, uniquingKeysWith: +)
    let filler = try LetterWeights(weights)
    let dictionary = Set(words)
    let inputs = (UInt64(1)...30).flatMap { seed in screens.map { (words: $0, seed: seed) } }
    func generate(_ input: (words: [String], seed: UInt64)) throws -> Board {
      let generator = BoardGenerator(
        columns: 7, rows: 7, directions: directions, filler: filler,
        dictionary: dictionary, downWords: input.words.count / 2...(input.words.count + 1) / 2)
      return try generator.board(for: input.words, seed: input.seed)
    }
    let boards = try inputs.map(generate)
    for (input, board) in zip(inputs, boards) {
      precondition(board.columns == 7 && board.rows == 7)
      precondition(board.placements.map(\.word) == input.words)
      precondition(input.words.allSatisfy { board.occurrences(of: $0, along: directions) == 1 })
      precondition(board.strayWords(of: dictionary, along: directions).isEmpty)
    }
    var index = 0
    try LetterGridBenchmarks.measure("ordinary generation 7x7", iterations: inputs.count) {
      let board = try generate(inputs[index % inputs.count])
      index += 1
      return board.letters.joined().reduce(0) { $0 + Int($1.asciiValue ?? 0) }
    }
    measureHints(on: boards)
    measureSelection(on: boards)
  }

  private static func measureHints(on boards: [Board]) {
    let rounds = boards.map { board in
      let round = Round(board: board, directions: directions, hintOrder: .anyButFirst)
      for _ in 0..<(board.placements.count * 2) {
        precondition(round.reveal() != nil)
      }
      return round
    }
    for round in rounds {
      precondition(round.hintedCells.count == round.board.placements.count * 2)
      precondition(round.hintedCells.allSatisfy(round.board.contains))
    }
    var index = 0
    LetterGridBenchmarks.measure("ordinary hintedCells 7x7", iterations: 9_000) {
      let cells = rounds[index % rounds.count].hintedCells
      index += 1
      return cells.reduce(0) { $0 + $1.row * 7 + $1.column }
    }
  }

  private static func measureSelection(on boards: [Board]) {
    var index = 0
    LetterGridBenchmarks.measure("ordinary round+select-all 7x7", iterations: 9_000) {
      let board = boards[index % boards.count]
      index += 1
      let round = Round(board: board, directions: directions, hintOrder: .anyButFirst)
      for placement in board.placements {
        guard let end = placement.cells.last else { preconditionFailure("Empty placement") }
        round.touch(placement.start)
        round.drag(to: end)
        precondition(round.release() == placement)
      }
      precondition(round.phase == .won)
      return round.found.count
    }
  }
}
