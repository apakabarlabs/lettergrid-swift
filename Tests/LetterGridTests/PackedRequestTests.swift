import Foundation
import LetterGrid
import Testing
import Yams

struct PackedRequestTests {
  private struct Rule: Decodable {
    let directions: [Direction]
    let turns: Int

    var wordRule: WordRule { WordRule(startDirections: directions, turns: turns) }
  }

  private struct Case: Decodable {
    let name: String
    let rules: [Rule]
    let firstRule: Rule?
    let words: [String]
    let accepted: Bool?
    let fits: Bool
  }

  private static func cases() throws -> [Case] {
    let url = try #require(
      Bundle.module.url(
        forResource: "packed-requests", withExtension: "yaml", subdirectory: "Fixtures"))
    return try YAMLDecoder().decode([Case].self, from: String(contentsOf: url, encoding: .utf8))
  }

  @Test func withoutAHeightLimitGeneration18KeepsTheBoardsOf17() throws {
    let rule = WordRule(startDirections: [.right, .down], turns: 1)
    func board(_ version: BoardGenerationVersion, seed: UInt64) throws -> Board {
      try BoardGenerator(
        columns: 7, rows: 7, rules: [rule], filler: try LetterWeights(["q": 1, "w": 1]),
        generationVersion: version
      ).request(for: ["PLANET", "ORBIT", "COMET"]).board(seed: seed)
    }
    for seed in UInt64(1)...4 {
      #expect(try board(.v0p18, seed: seed) == board(.v0p17, seed: seed))
    }
  }

  @Test func theSolverDecidesWhetherWordsShareTheField() throws {
    for item in try Self.cases() {
      let rules = item.rules.map(\.wordRule)
      let generator = BoardGenerator(
        columns: 7, rows: 7, maxRows: 7, rules: rules,
        filler: try LetterWeights(["q": 1, "w": 1]),
        downWords: item.words.count == 1 ? 0...1 : 1...2, generationVersion: .v0p18)
      #expect(
        generator.accepts(item.words, firstRule: item.firstRule?.wordRule)
          == (item.accepted ?? true), "\(item.name)")
      guard item.fits else {
        #expect(throws: BoardGenerator.Failure.self, "\(item.name)") {
          try generator.request(for: item.words, firstRule: item.firstRule?.wordRule)
        }
        continue
      }
      let request = try generator.request(for: item.words, firstRule: item.firstRule?.wordRule)
      var layouts: Set<[Placement]> = []
      for seed in UInt64(1)...4 {
        let board = request.board(seed: seed)
        layouts.insert(board.placements)
        #expect(board.placements.map(\.word) == item.words, "\(item.name)")
        #expect(
          generator.downWords.contains(board.placements.filter(\.direction.isVertical).count),
          "\(item.name)")
        for placement in board.placements {
          #expect(rules.contains { $0.matches(placement) }, "\(item.name): \(placement.word)")
          #expect(
            board.occurrences(of: placement.word, rules: rules) == 1,
            "\(item.name): \(placement.word)")
        }
        if let first = item.firstRule, let placement = board.placements.first {
          #expect(first.wordRule.matches(placement), "\(item.name)")
        }
      }
      #expect(layouts.count > 1, "\(item.name): every seed gave the same layout")
    }
  }
}
