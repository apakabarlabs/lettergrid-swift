import Foundation
import Testing
import Yams

@testable import LetterGrid

struct RunFreeNoiseTests {
  @Test func aPairPreferenceCannotRejectAnOtherwisePlayableField() throws {
    let board = try Board(
      validating: [Array("XXXXXXXXXXXX"), Array("ABXXXXXXXXXX")],
      placements: [
        Placement(word: "AB", start: Cell(row: 1, column: 0), direction: .right)
      ])
    let filled = try #require(
      RunFreeFill(
        board: board, weights: LetterWeights(["X": 1, "Y": 1, "Z": 1]),
        rules: [WordRule(startDirections: [.right])], conditionalCharacters: [],
        dictionary: WordIndex([])
      ).filled(seed: 1))
    let runs = LetterRuns(placements: filled.placements, columns: filled.columns, rows: filled.rows)
    #expect(!runs.containsForbiddenRun(in: filled.letters.map { $0.map(Optional.some) }))
    #expect(filled.hasAddedEqualPair)
  }

  private struct Case: Decodable {
    let name: String
    let letters: String
    let word: String
    let weights: [String: Double]
    let dictionary: Set<String>
    let expectedNoise: Int
    let conditional: String?
    let expectedPairs: Int?
  }

  @Test func constrainedFillKeepsTheLeastDictionaryNoise() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "run-free-noise", withExtension: "yaml", subdirectory: "Fixtures"))
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    let rules = [WordRule(startDirections: [.right])]
    for item in cases {
      let original = try Board(
        validating: [Array(item.letters)],
        placements: [
          Placement(word: item.word, start: Cell(row: 0, column: 0), direction: .right)
        ])
      let dictionary = WordIndex(item.dictionary)
      let fill = RunFreeFill(
        board: original, weights: try LetterWeights(item.weights), rules: rules,
        conditionalCharacters: Set(item.conditional ?? ""), dictionary: dictionary)
      for seed in UInt64(100)..<108 {
        let board = try #require(fill.filled(seed: seed))
        #expect(
          board.strayWordCount(in: dictionary, rules: rules) == item.expectedNoise,
          "\(item.name), seed \(seed)")
        if let expected = item.expectedPairs {
          let pairs = board.letters.reduce(0) { total, row in
            total + zip(row, row.dropFirst()).filter { $0 == $1 }.count
          }
          #expect(pairs == expected, "\(item.name), seed \(seed)")
        }
        for letter in item.conditional ?? "" {
          let occupied = Set(board.placements.flatMap(\.cells))
          #expect(
            (0..<board.columns).contains {
              let cell = Cell(row: 0, column: $0)
              return !occupied.contains(cell) && board[cell] == letter
            })
        }
      }
    }
  }
}
