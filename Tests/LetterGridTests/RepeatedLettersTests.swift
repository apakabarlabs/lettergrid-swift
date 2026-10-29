import Foundation
import LetterGrid
import Testing
import Yams

struct RepeatedLettersTests {
  @Test(arguments: 3...7)
  func aValidStaggeredLayoutIsNotRefusedByItsFallback(width: Int) throws {
    let words = Array("ABCDEFG".prefix(width)).map { "T\($0)" }
    let placements = words.enumerated().map { index, word in
      Placement(word: word, start: Cell(row: index % 2, column: index), direction: .down)
    }
    var letters = Array(repeating: Array(repeating: Character("X"), count: width), count: 3)
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    let reference = try Board(validating: letters, placements: placements)
    #expect(!hasAddedRun(reference))
    let generator = BoardGenerator(
      columns: width, rows: 3, maxRows: 3, directions: [.down],
      filler: try LetterWeights(["X": 1]), downWords: width...width)
    let board = try generator.request(for: words).board(seed: 42)
    #expect(!hasAddedRun(board))
  }

  @Test func anImpossibleAlphabetIsRefusedDuringPreparation() throws {
    let generator = BoardGenerator(
      columns: 4, rows: 4, maxRows: 4, directions: [.right],
      filler: try LetterWeights(["X": 1]))
    #expect(throws: BoardGenerator.Failure.unsettled(words: ["AB"], columns: 4, rows: 4)) {
      try generator.request(for: ["AB"])
    }
  }

  @Test(arguments: [["TAB", "TBA", "TAA"], ["tab", "tba", "taa"]])
  func forbiddenTargetRunsAreARefillFailureRatherThanMissingGeometry(words: [String]) throws {
    let generator = BoardGenerator(
      columns: 3, rows: 3, maxRows: 3, directions: [.down],
      filler: try LetterWeights(["X": 1, "Y": 1, "Z": 1]))
    #expect(
      throws: BoardGenerator.Failure.unsettled(words: ["TAB", "TBA", "TAA"], columns: 3, rows: 3)
    ) {
      try generator.request(for: words)
    }
  }

  private struct Case: Decodable {
    let name: String
    let words: [String]
    let columns: Int
    let rows: Int
    let weights: [String: Double]
    let turns: Int
    let avoidsPairs: Bool?
  }

  @Test func generatedBoardsNeverExtendAWordRunOrCreateARunAcrossWords() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "repeated-letters", withExtension: "yaml", subdirectory: "Fixtures"))
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    for item in cases {
      let rules = [WordRule(startDirections: Direction.allCases, turns: item.turns)]
      let request = try BoardGenerator(
        columns: item.columns, rows: item.rows, maxRows: item.rows, rules: rules,
        filler: LetterWeights(item.weights)
      ).request(for: item.words)
      var signatures: [String: Int] = [:]
      for seed in UInt64(100)..<164 {
        let board = request.board(seed: seed)
        signatures[board.letters.map { String($0) }.joined(separator: "/"), default: 0] += 1
        #expect(!hasAddedRun(board), "\(item.name), seed \(seed)")
        if item.avoidsPairs == true {
          for row in 0..<board.rows {
            for column in 0..<board.columns {
              let cell = Cell(row: row, column: column)
              for direction in Direction.allCases {
                let next = Cell(
                  row: row + direction.rowStep, column: column + direction.columnStep)
                if board.contains(next) { #expect(board[cell] != board[next], "\(item.name)") }
              }
            }
          }
        }
        for word in item.words {
          #expect(board.occurrences(of: word, rules: rules) == 1)
        }
      }
      let peak = signatures.values.max() ?? 0
      #expect(signatures.count > 1, "\(item.name): \(signatures.count)/64 fields; peak \(peak)/64")
    }
  }

  private func hasAddedRun(_ board: Board) -> Bool {
    for row in 0..<board.rows {
      for column in 0..<board.columns {
        for direction in Direction.allCases {
          let cells = (0..<3).map {
            Cell(
              row: row + direction.rowStep * $0,
              column: column + direction.columnStep * $0)
          }
          guard cells.allSatisfy(board.contains), Set(cells.map { board[$0] }).count == 1 else {
            continue
          }
          let belongsToWord = board.placements.contains { placement in
            guard placement.cells.count >= 3 else { return false }
            return (0...(placement.cells.count - 3)).contains { start in
              let wordCells = Array(placement.cells[start..<(start + 3)])
              return wordCells == cells || Array(wordCells.reversed()) == cells
            }
          }
          if !belongsToWord { return true }
        }
      }
    }
    return false
  }
}
