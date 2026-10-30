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
    let leadingRules: [Rule]?
    let grows: Bool?
    let failure: String?
    let downWords: [Int]?
    let words: [String]
    let accepted: Bool?
    let fits: Bool

    var leading: [WordRule] {
      leadingRules?.map(\.wordRule) ?? firstRule.map { [$0.wordRule] } ?? []
    }

    func request(from generator: BoardGenerator) throws -> BoardRequest {
      if leadingRules != nil { return try generator.request(for: words, leadingRules: leading) }
      return try generator.request(for: words, firstRule: firstRule?.wordRule)
    }
  }

  private static func cases() throws -> [Case] {
    let url = try #require(
      Bundle.module.url(
        forResource: "packed-requests", withExtension: "yaml", subdirectory: "Fixtures"))
    return try YAMLDecoder().decode([Case].self, from: String(contentsOf: url, encoding: .utf8))
  }

  @Test func theSolverDecidesWhetherWordsShareTheField() throws {
    for item in try Self.cases() {
      let rules = item.rules.map(\.wordRule)
      let generator = BoardGenerator(
        columns: 7, rows: 7, maxRows: item.grows == true ? nil : 7, rules: rules,
        filler: try LetterWeights(["q": 1, "w": 1]),
        downWords: item.downWords.map { $0[0]...$0[1] }
          ?? (item.words.count == 1 ? 0...1 : 1...2))
      #expect(
        generator.accepts(item.words, leadingRules: item.leading)
          == (item.accepted ?? true), "\(item.name)")
      guard item.fits else {
        let failure: BoardGenerator.Failure =
          item.failure == "invalidConfiguration"
          ? .invalidConfiguration : .noRoom(words: item.words, columns: 7, rows: 7)
        #expect(throws: failure, "\(item.name)") {
          try item.request(from: generator)
        }
        continue
      }
      let request = try item.request(from: generator)
      #expect(request.leadingRules == item.leading)
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
        for (rule, placement) in zip(item.leading, board.placements) {
          #expect(rule.matches(placement), "\(item.name): \(placement.word)")
        }
      }
      #expect(layouts.count > 1, "\(item.name): every seed gave the same layout")
    }
  }
}
