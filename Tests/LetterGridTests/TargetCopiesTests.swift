import Foundation
import LetterGrid
import Testing
import Yams

struct TargetCopiesTests {
  private struct Case: Decodable {
    let name: String
    let words: [String]
    let columns: Int
    let rows: Int
    let bounded: Bool
    let rejects: Bool?
    let grows: Bool?
    let alone: [String]?
    let turns: [Int]?
    let filler: [String: Double]?
  }

  @Test func everyTargetCharacterButAOneLetterWordStandsOnTheBoardAtLeastTwice() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "target-copies", withExtension: "yaml", subdirectory: "Fixtures"))
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    for item in cases {
      let generator = BoardGenerator(
        size: BoardSize(
          columns: item.columns, rows: item.rows, maxRows: item.bounded ? item.rows : nil),
        rules: (item.turns ?? [0]).map { WordRule(startDirections: [.right, .down], turns: $0) },
        filler: Filler(weights: try LetterWeights(item.filler ?? ["X": 1, "Q": 1]))
      )
      if item.rejects == true {
        let failure = BoardGenerator.Failure.noRoom(
          words: item.words, columns: item.columns, rows: item.rows)
        #expect(throws: failure, "\(item.name)") { try generator.request(for: item.words) }
        continue
      }
      let request = try generator.request(for: item.words)
      for seed in UInt64(1)...8 {
        let board = request.board(seed: seed)
        #expect((board.rows > item.rows) == (item.grows == true), "\(item.name)")
        var onTargets: [Character: Int] = [:]
        for cell in Set(board.placements.flatMap(\.cells)) {
          onTargets[board[cell], default: 0] += 1
        }
        for (character, count) in onTargets {
          let onBoard = board.letters.joined().filter { $0 == character }.count
          let alone = item.alone?.contains(String(character)) == true
          #expect(
            onBoard == (alone ? count : max(2, count)), "\(item.name), seed \(seed): \(character)")
        }
      }
    }
  }
}
