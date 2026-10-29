import Foundation
import Testing
import Yams

@testable import LetterGrid

private struct PackingRule: Decodable {
  let directions: [Direction]
  let turns: Int

  var wordRule: WordRule { WordRule(startDirections: directions, turns: turns) }
}

private struct PackingCase: Decodable {
  let name: String
  let columns: Int
  let rows: Int
  let rules: [PackingRule]
  let firstRule: PackingRule?
  let downWords: [Int]
  let words: [String]
  let nodeLimit: Int?
  let outcome: String
  let goldens: [String: String]?
  let avoidsTargetRuns: Bool?
  let checksShifts: Bool?
  let mixedShapes: Bool?
  let conditionalCharacters: [String]?

  var requiredSymbols: Set<Character> {
    let used = Set(words.joined())
    return used.intersection(Set((conditionalCharacters ?? []).flatMap(Array.init)))
      .union(used.filter { !$0.isLetter })
  }

  var packing: PathPacking {
    var packing = PathPacking(
      columns: columns, rows: rows, rules: rules.map(\.wordRule),
      firstRule: firstRule?.wordRule, downWords: downWords[0]...downWords[1])
    if let nodeLimit { packing.nodeLimit = nodeLimit }
    let required = requiredSymbols
    let avoidsRuns = avoidsTargetRuns == true
    if avoidsRuns || !required.isEmpty {
      let (rows, columns) = (rows, columns)
      let rules = rules.map(\.wordRule)
      packing.completes = { placements, budget in
        let layout = Layout(rows: rows, placements: placements)
        guard !avoidsRuns || !layout.hasForbiddenTargetRun(columns: columns) else {
          return .doesNotFit
        }
        return ConditionalFill.roomForDecoys(
          required, beside: layout, columns: columns, rules: rules, budget: &budget)
      }
    }
    return packing
  }
}

private struct PackingFixture: Decodable {
  let baselineRevision: String
  let cases: [PackingCase]

  enum CodingKeys: String, CodingKey {
    case baselineRevision = "baseline_revision"
    case cases
  }
}

struct PathPackingTests {
  private static func cases() throws -> [PackingCase] {
    let url = try #require(
      Bundle.module.url(
        forResource: "path-packing", withExtension: "yaml", subdirectory: "Fixtures"))
    return try YAMLDecoder().decode(
      PackingFixture.self, from: String(contentsOf: url, encoding: .utf8)
    ).cases
  }

  @Test func eachCaseEndsAsProvedByHand() throws {
    for item in try Self.cases() {
      let packing = item.packing
      let outcome = packing.pack(item.words)
      switch outcome {
      case .placed(let placements):
        #expect(item.outcome == "placed", "\(item.name)")
        try expectBoard(placements, for: item, rules: packing.rules, quota: packing.downWords)
      case .impossible:
        #expect(item.outcome == "impossible", "\(item.name)")
      case .undetermined:
        #expect(item.outcome == "undetermined", "\(item.name)")
      }
    }
  }

  @Test func seededPackingKeepsTheRecordedPlacementOrder() throws {
    let cases = try Self.cases().filter { $0.goldens != nil }
    #expect(!cases.isEmpty)
    for item in cases {
      let packing = item.packing
      for (seed, expected) in try #require(item.goldens).sorted(by: { $0.key < $1.key }) {
        let actual = signature(packing.pack(item.words, seed: try #require(UInt64(seed))))
        #expect(actual == expected, "\(item.name), seed \(seed)")
      }
    }
  }

  @Test func isolatedShapeCompatibilityDoesNotDependOnItsOffset() throws {
    let cases = try Self.cases().filter { $0.checksShifts == true }
    #expect(!cases.isEmpty)
    for item in cases {
      let blank: Character = "\u{E000}"
      try #require(!item.words.joined().contains(blank))
      let compatibility = PlacementCompatibility(
        columns: item.columns, rows: item.rows, rules: item.rules.map(\.wordRule),
        words: item.words, blank: blank)
      var verdicts: Set<Bool> = []
      for (index, word) in item.words.enumerated() {
        for rule in item.rules.map(\.wordRule) {
          let shapes = PathShapes(
            columns: item.columns, length: word.count, rule: rule,
            maximumShapes: Int.max, maximumRows: item.rows, visitedLimit: nil, randomized: false
          ).cells()
          for shape in shapes {
            verdicts.insert(
              try checkOffsets(shape, for: index, in: item, using: compatibility))
          }
        }
      }
      #expect(!verdicts.isEmpty, "\(item.name)")
      if item.mixedShapes == true { #expect(verdicts == [true, false], "\(item.name)") }
    }
  }

  private func checkOffsets(
    _ shape: [Cell], for index: Int, in item: PackingCase,
    using compatibility: PlacementCompatibility
  ) throws -> Bool {
    func accepts(_ cells: [Cell]) -> Bool {
      var chosen = [Placement?](repeating: nil, count: item.words.count)
      chosen[index] = Placement(word: item.words[index], cells: cells)
      return compatibility.accepts(chosen)
    }
    let height = (shape.map(\.row).max() ?? 0) + 1
    let width = (shape.map(\.column).max() ?? 0) + 1
    try #require(height <= item.rows && width <= item.columns)
    let expected = accepts(shape)
    for row in 0...(item.rows - height) {
      for column in 0...(item.columns - width) {
        let shifted = shape.map { Cell(row: $0.row + row, column: $0.column + column) }
        try #require(
          accepts(shifted) == expected,
          "\(item.name), word \(item.words[index]), offset \(row),\(column)")
      }
    }
    return expected
  }

  private func signature(_ outcome: PathPacking.Outcome) -> String {
    switch outcome {
    case .impossible: "impossible"
    case .undetermined: "undetermined"
    case .placed(let placements):
      placements.map { placement in
        placement.word + "="
          + placement.cells.map { "\($0.row),\($0.column)" }.joined(separator: ";")
      }.joined(separator: "|")
    }
  }

  private func expectBoard(
    _ placements: [Placement], for item: PackingCase, rules: [WordRule], quota: ClosedRange<Int>
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
    if item.avoidsTargetRuns == true {
      #expect(
        !Layout(rows: item.rows, placements: placements).hasForbiddenTargetRun(
          columns: item.columns))
    }
    #expect(quota.contains(placements.filter(\.direction.isVertical).count), "\(item.name)")
    let board = try Board(validating: letters, placements: placements)
    for placement in placements {
      #expect(board.hasSingleOccurrence(of: placement.word, rules: rules), "\(item.name)")
    }
  }
}
