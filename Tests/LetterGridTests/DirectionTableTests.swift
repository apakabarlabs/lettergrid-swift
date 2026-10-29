import Foundation
import LetterGrid
import Testing
import Yams

struct DirectionTableTests {
  private struct Row: Decodable {
    let name: Direction
    let rowStep: Int
    let columnStep: Int
    let opposite: Direction
  }

  @Test func everyDirectionStepsAsTheTableSays() throws {
    let url = try #require(
      Bundle.module.url(forResource: "directions", withExtension: "yaml", subdirectory: "Fixtures"))
    let rows = try YAMLDecoder().decode([Row].self, from: String(contentsOf: url, encoding: .utf8))
    #expect(rows.map(\.name) == Direction.allCases)
    for row in rows {
      #expect(row.name.rowStep == row.rowStep, "\(row.name)")
      #expect(row.name.columnStep == row.columnStep, "\(row.name)")
      #expect(row.name.opposite == row.opposite, "\(row.name)")
    }
  }
}
