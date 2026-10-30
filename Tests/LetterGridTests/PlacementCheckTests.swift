import Foundation
import LetterGrid
import Testing
import Yams

struct PlacementCheckTests {
  private struct Rule: Decodable {
    let directions: [Direction]
    let turns: Int
    var value: WordRule { WordRule(startDirections: directions, turns: turns) }
  }

  private struct Case: Decodable {
    let name: String
    let columns: Int
    let rows: Int
    let maxRows: Int?
    let directions: [Direction]?
    let rules: [Rule]?
    let firstDirection: Direction?
    let firstRule: Rule?
    let leadingRules: [Rule]?
    let weights: [String: Double]
    let downWords: [Int]
    let words: [String]
    let placement: String
    let request: String

    func generator() throws -> BoardGenerator {
      let filler = try LetterWeights(weights)
      let quota = downWords[0]...downWords[1]
      if let rules {
        return BoardGenerator(
          columns: columns, rows: rows, maxRows: maxRows, rules: rules.map(\.value),
          filler: filler, downWords: quota)
      }
      return BoardGenerator(
        columns: columns, rows: rows, maxRows: maxRows, directions: try #require(directions),
        filler: filler, downWords: quota)
    }

    func check(_ generator: BoardGenerator) throws {
      if let leadingRules {
        try generator.checkPlacement(for: words, leadingRules: leadingRules.map(\.value))
      } else {
        try generator.checkPlacement(
          for: words, firstDirection: firstDirection, firstRule: firstRule?.value)
      }
    }

    func prepare(_ generator: BoardGenerator) throws -> BoardRequest {
      if let leadingRules {
        return try generator.request(for: words, leadingRules: leadingRules.map(\.value))
      }
      return try generator.request(
        for: words, firstDirection: firstDirection, firstRule: firstRule?.value)
    }

    func failure(_ outcome: String) -> BoardGenerator.Failure {
      switch outcome {
      case "invalidConfiguration": .invalidConfiguration
      case "unsettled":
        .unsettled(words: words.map(\.cellUppercased), columns: columns, rows: maxRows ?? rows)
      default: .noRoom(words: words.map(\.cellUppercased), columns: columns, rows: rows)
      }
    }
  }

  @Test func placementAndCompletePreparationHaveSeparateGuarantees() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "placement-checks", withExtension: "yaml", subdirectory: "Fixtures"))
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    for item in cases {
      let generator = try item.generator()
      if item.placement == "placed" {
        #expect(item.request == "prepared" || item.request == "unsettled", "\(item.name)")
        try item.check(generator)
      } else {
        #expect(throws: item.failure(item.placement), "\(item.name)") { try item.check(generator) }
      }
      if item.request == "prepared" {
        let request = try item.prepare(generator)
        for seed in UInt64(0)...2 {
          #expect(
            request.board(seed: seed).placements.map(\.word) == item.words.map(\.cellUppercased))
        }
      } else {
        #expect(throws: item.failure(item.request), "\(item.name)") { try item.prepare(generator) }
      }
    }
  }
}
