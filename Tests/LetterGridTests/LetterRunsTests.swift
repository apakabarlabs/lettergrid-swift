import Foundation
import Testing
import Yams

@testable import LetterGrid

struct LetterRunsTests {
  private struct Target: Decodable {
    let word: String
    let row: Int
    let column: Int
    let direction: Direction

    var placement: Placement {
      Placement(word: word, start: Cell(row: row, column: column), direction: direction)
    }
  }

  private struct Case: Decodable {
    let name: String
    let letters: [String]
    let placements: [Target]
    let forbidden: Bool
  }

  @Test func triplesAreAllowedOnlyAlongOneTargetPath() throws {
    let url = try #require(
      Bundle.module.url(forResource: "letter-runs", withExtension: "yaml", subdirectory: "Fixtures")
    )
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    for item in cases {
      let board = try Board(
        validating: item.letters.map(Array.init), placements: item.placements.map(\.placement))
      let runs = LetterRuns(
        placements: board.placements, columns: board.columns, rows: board.rows)
      #expect(
        runs.containsForbiddenRun(in: board.letters.map { $0.map(Optional.some) })
          == item.forbidden,
        "\(item.name)")
    }
  }
}
