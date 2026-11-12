import Foundation
import Testing
import Yams

@testable import LetterGrid

@MainActor
struct AlternativeReadingTests {
  struct Rule: Decodable, Sendable {
    let directions: [Direction]
    let turns: Int
    var value: WordRule { WordRule(startDirections: directions, turns: turns) }
  }

  struct Case: Decodable, Sendable, CustomTestStringConvertible {
    let name: String
    let letters: [String]
    let word: String
    let generated: [[Int]]
    let rules: [Rule]
    let drawn: [[Int]]
    let accepted: Bool

    var testDescription: String { name }

    static func cells(_ pairs: [[Int]]) -> [Cell] { pairs.map { Cell(row: $0[0], column: $0[1]) } }
  }

  nonisolated static let cases: [Case] = {
    do {
      let url = try #require(
        Bundle.module.url(
          forResource: "alternative-readings", withExtension: "yaml", subdirectory: "Fixtures"))
      return try YAMLDecoder().decode([Case].self, from: String(contentsOf: url, encoding: .utf8))
    } catch {
      preconditionFailure("alternative-readings.yaml cannot be read: \(error)")
    }
  }()

  @Test(arguments: cases)
  func aWordIsAcceptedAlongEveryPathTheOpenRulesAllow(_ example: Case) throws {
    let board = Board(
      letters: example.letters.map(Array.init),
      placements: [Placement(word: example.word, cells: Case.cells(example.generated))])
    let round = Round(board: board, rules: example.rules.map(\.value))
    let drawn = Case.cells(example.drawn)
    round.touch(drawn[0])
    for cell in drawn.dropFirst() { round.drag(to: cell) }
    #expect((round.selection == drawn) == example.accepted, "selected")
    let placement = round.release()
    guard example.accepted else {
      #expect(placement == nil)
      return
    }
    #expect(placement == Placement(word: example.word, cells: drawn))
    #expect(round.board.placements == [Placement(word: example.word, cells: drawn)])
    #expect(round.phase == .won)
  }
}
