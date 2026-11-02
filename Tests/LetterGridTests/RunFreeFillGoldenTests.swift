import Foundation
import Testing
import Yams

@testable import LetterGrid

private struct FillGoldenCase: Decodable {
  let name: String
  let words: [String]
  let directions: [String]
  let symbols: Set<String>
  let boards: [String: String]
  let turns: [Int]
}

struct RunFreeFillGoldenTests {
  private struct Fixture: Decodable {
    let seeds: [UInt64]
    let filler: [String: Double]
    let cases: [FillGoldenCase]
  }

  @Test func incrementalFillingKeepsTheOriginalBoards() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "run-free-fill", withExtension: "yaml", subdirectory: "Fixtures"))
    let fixture = try YAMLDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    for test in fixture.cases {
      let directions = try test.directions.map { try #require(Direction(rawValue: $0)) }
      let rules = test.turns.map { WordRule(startDirections: directions, turns: $0) }
      let fill = RunFreeFill(
        board: FillTestBoard.make(words: test.words),
        weights: try LetterWeights(fixture.filler), rules: rules,
        conditionalCharacters: Set(try test.symbols.map { try #require($0.first) }))
      for seed in fixture.seeds {
        let filled = fill.filled(seed: seed)
        if let filled {
          let runs = LetterRuns(
            placements: filled.placements, columns: filled.columns, rows: filled.rows)
          #expect(
            !runs.containsForbiddenRun(in: filled.letters.map { $0.map(Optional.some) }),
            "\(test.name), seed \(seed)")
          #expect(
            filled.placements.allSatisfy { filled.hasSingleOccurrence(of: $0.word, rules: rules) },
            "\(test.name), seed \(seed)")
        }
        let signature =
          filled.map {
            $0.letters.map { String($0) }.joined(separator: "/")
          } ?? "<unfilled>"
        let expected = try #require(test.boards[String(seed)])
        #expect(signature == expected, "\(test.name), seed \(seed)")
      }
    }
  }
}
