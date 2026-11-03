import Foundation
import Testing
import Yams

@testable import LetterGrid

private struct SeededBoardCase: Decodable {
  let name: String
  let columns: Int
  let rows: Int
  let maxRows: Int?
  let directions: [String]
  let turns: [Int]?
  let firstRuleTurns: Int?
  let downWords: [Int]
  let symbols: [String]
  let words: [String]
  let letters: String
  let placements: [String: String]

  enum CodingKeys: String, CodingKey {
    case name, columns, rows, directions, turns, symbols, words, letters, placements
    case maxRows = "max_rows"
    case firstRuleTurns = "first_rule_turns"
    case downWords = "down_words"
  }
}

struct SeededBoardTests {
  private struct Fixture: Decodable {
    let seed: UInt64
    let filler: [String: Double]
    let cases: [SeededBoardCase]
  }

  @Test func aSeedKeepsItsRecordedBoard() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "seeded-boards", withExtension: "yaml", subdirectory: "Fixtures"))
    let fixture = try YAMLDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    let filler = try LetterWeights(fixture.filler)
    for test in fixture.cases {
      let board = try request(test, filler: filler).board(seed: fixture.seed)
      #expect(
        board.letters.map { String($0) }.joined(separator: "/") == test.letters, "\(test.name)")
      #expect(placements(board) == test.placements, "\(test.name)")
    }
  }

  private func request(_ test: SeededBoardCase, filler: LetterWeights) throws -> BoardRequest {
    let directions = try test.directions.map { try #require(Direction(rawValue: $0)) }
    let downWords = try #require(test.downWords.first)...(try #require(test.downWords.last))
    let symbols = Set(try test.symbols.map { try #require($0.first) })
    guard let turns = test.turns else {
      return try BoardGenerator(
        columns: test.columns, rows: test.rows, maxRows: test.maxRows, directions: directions,
        filler: filler, downWords: downWords, conditionalCharacters: symbols
      ).request(for: test.words)
    }
    let rules = turns.map { WordRule(startDirections: directions, turns: $0) }
    let first = try #require(rules.first { $0.turns == test.firstRuleTurns })
    return try BoardGenerator(
      columns: test.columns, rows: test.rows, maxRows: test.maxRows, rules: rules,
      filler: filler, downWords: downWords, conditionalCharacters: symbols
    ).request(for: test.words, firstRule: first)
  }

  private func placements(_ board: Board) -> [String: String] {
    Dictionary(
      uniqueKeysWithValues: board.placements.map { placement in
        (
          placement.word,
          placement.cells.map { "\($0.row),\($0.column)" }.joined(separator: ";")
        )
      })
  }
}
