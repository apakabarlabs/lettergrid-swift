import Foundation
import Testing
import Yams

@testable import LetterGrid

struct PathPackingTests {
  private struct Rule: Decodable {
    let directions: [Direction]
    let turns: Int

    var wordRule: WordRule { WordRule(startDirections: directions, turns: turns) }
  }

  private struct Case: Decodable {
    let name: String
    let columns: Int
    let rows: Int
    let rules: [Rule]
    let firstRule: Rule?
    let downWords: [Int]
    let words: [String]
    let nodeLimit: Int?
    let outcome: String
  }

  private static func cases() throws -> [Case] {
    let url = try #require(
      Bundle.module.url(
        forResource: "path-packing", withExtension: "yaml", subdirectory: "Fixtures"))
    return try YAMLDecoder().decode([Case].self, from: String(contentsOf: url, encoding: .utf8))
  }

  @Test func eachCaseEndsAsProvedByHand() throws {
    for item in try Self.cases() {
      let rules = item.rules.map(\.wordRule)
      let quota = item.downWords[0]...item.downWords[1]
      var packing = PathPacking(
        columns: item.columns, rows: item.rows, rules: rules, firstRule: item.firstRule?.wordRule,
        downWords: quota)
      if let limit = item.nodeLimit { packing.nodeLimit = limit }
      let outcome = packing.pack(item.words)
      switch outcome {
      case .placed(let placements):
        #expect(item.outcome == "placed", "\(item.name)")
        try expectBoard(placements, for: item, rules: rules, quota: quota)
      case .impossible:
        #expect(item.outcome == "impossible", "\(item.name)")
      case .undetermined:
        #expect(item.outcome == "undetermined", "\(item.name)")
      }
    }
  }

  private func expectBoard(
    _ placements: [Placement], for item: Case, rules: [WordRule], quota: ClosedRange<Int>
  ) throws {
    #expect(placements.map(\.word) == item.words, "\(item.name)")
    var letters = Array(
      repeating: Array(repeating: Character("."), count: item.columns), count: item.rows)
    for placement in placements {
      #expect(rules.contains { $0.matches(placement) }, "\(item.name): \(placement.word)")
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    if let first = item.firstRule, let placement = placements.first {
      #expect(first.wordRule.matches(placement), "\(item.name)")
    }
    #expect(quota.contains(placements.filter(\.direction.isVertical).count), "\(item.name)")
    let board = try Board(validating: letters, placements: placements)
    for placement in placements {
      #expect(board.hasSingleOccurrence(of: placement.word, rules: rules), "\(item.name)")
    }
  }
}
