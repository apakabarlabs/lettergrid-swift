import Foundation
import Testing
import Yams

@testable import LetterGrid

@MainActor
struct SeparatorBoardTests {
  private struct Example: Decodable {
    let name: String
    let words: [String]
    let turns: Int
    let bounded: Bool
    let columns: Int?
    let rows: Int?
    let rejects: Bool?
    let conditional: [String]?
    let weights: [String: Double]?
  }

  @Test func separatorsHaveDecoysAndRemainCellsOfTheFoundPath() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "separator-boards", withExtension: "yaml", subdirectory: "Fixtures"))
    let examples = try YAMLDecoder().decode(
      [Example].self, from: String(contentsOf: url, encoding: .utf8))
    for example in examples { try check(example) }
  }

  private func check(_ example: Example) throws {
    let rule = WordRule(startDirections: [.right, .down], turns: example.turns)
    let conditional = Set((example.conditional ?? []).map { Character($0).cellUppercased })
    let generator = BoardGenerator(
      columns: example.columns ?? 7, rows: example.rows ?? 7,
      maxRows: example.bounded ? example.rows ?? 7 : nil,
      rules: [rule], filler: try LetterWeights(example.weights ?? ["x": 1, "q": 1]),
      conditionalCharacters: conditional)
    if example.rejects == true {
      #expect(throws: BoardGenerator.Failure.self) { try generator.request(for: example.words) }
      return
    }
    let request = try generator.request(for: example.words)
    let symbols: Set<Character> = conditional.union([" ", "-", "'"])
    let targets = Set(example.words.joined().map(\.cellUppercased)).intersection(symbols)
    for seed in UInt64(1)...3 {
      let board = request.board(seed: seed)
      checkCopies(on: board, symbols: symbols, targets: targets, example: example)
      checkPaths(on: board, rule: rule, name: example.name)
    }
  }

  private func checkPaths(on board: Board, rule: WordRule, name: String) {
    let round = Round(board: board, rules: [rule])
    for placement in board.placements {
      #expect(board.text(along: placement.cells) == placement.word)
      #expect(placement.cells.count == placement.word.count)
      #expect(board.occurrences(of: placement.word, rules: [rule]) == 1)
      round.touch(placement.cells[0])
      for cell in placement.cells.dropFirst() { round.drag(to: cell) }
      #expect(round.release() == placement, "\(name): \(placement.word)")
    }
  }

  private func checkCopies(
    on board: Board, symbols: Set<Character>, targets: Set<Character>, example: Example
  ) {
    let occupied = Set(board.placements.flatMap(\.cells))
    let free = (0..<board.rows).flatMap { row in
      (0..<board.columns).map { Cell(row: row, column: $0) }
    }.filter { !occupied.contains($0) }
    for symbol in symbols {
      let actual = board.letters.joined().filter { $0 == symbol }.count
      if targets.contains(symbol) {
        let decoys = free.filter { board[$0] == symbol }.count
        #expect(decoys >= 1, "\(example.name): \(symbol.debugDescription), decoys \(decoys)")
        #expect(actual >= 2)
      } else {
        #expect(actual == 0, "\(example.name): unexpected \(symbol.debugDescription)")
      }
    }
  }
}
