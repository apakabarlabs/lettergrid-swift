import Foundation
import LetterGrid
import Testing
import Yams

struct MinimumTurnsTests {
  private struct Field: Decodable {
    let name: String
    let directions: [Direction]
    let columns: Int
    let maximumRows: Int?
    let turns: [Int: Int]
    let unfit: [Int]
  }

  private static func fields() throws -> [Field] {
    let url = try #require(
      Bundle.module.url(
        forResource: "minimum-turns", withExtension: "yaml", subdirectory: "Fixtures"))
    return try YAMLDecoder().decode([Field].self, from: String(contentsOf: url, encoding: .utf8))
  }

  @Test func eachLengthNeedsTheFewestTurnsThatFitTheField() throws {
    for field in try Self.fields() {
      for (length, turns) in field.turns {
        #expect(
          WordRule.minimumTurns(
            toFit: length, startDirections: field.directions, columns: field.columns,
            maximumRows: field.maximumRows) == turns,
          "\(field.name), length \(length)")
      }
      for length in field.unfit {
        #expect(
          WordRule.minimumTurns(
            toFit: length, startDirections: field.directions, columns: field.columns,
            maximumRows: field.maximumRows) == nil,
          "\(field.name), length \(length)")
      }
    }
  }
}
