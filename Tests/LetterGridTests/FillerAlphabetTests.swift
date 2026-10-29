import Foundation
import LetterGrid
import Testing
import Yams

struct FillerAlphabetTests {
  private struct Case: Decodable {
    let name: String
    let words: [String]
    let weights: [String: Double]
    let columns: Int
    let rows: Int
    let directions: [Direction]
    let vertical: [Int]
    let runDirections: [Direction]
    let seeds: [UInt64]
  }

  @Test func targetWordsMayUseTheWholeFillerAlphabet() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "filler-alphabet", withExtension: "yaml", subdirectory: "Fixtures"))
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    for item in cases {
      let generator = BoardGenerator(
        columns: item.columns, rows: item.rows, maxRows: item.rows,
        directions: item.directions, filler: try LetterWeights(item.weights),
        downWords: item.vertical[0]...item.vertical[1])
      #expect(generator.accepts(item.words), "\(item.name)")
      let request = try generator.request(for: item.words)
      for seed in item.seeds {
        let board = request.board(seed: seed)
        #expect(Set(board.placements.map(\.word)) == Set(item.words), "\(item.name)")
        for word in item.words {
          #expect(board.occurrences(of: word, along: item.directions) == 1, "\(item.name)")
        }
        for letter in Set(item.words.joined()) {
          #expect(board.letters.joined().filter { $0 == letter }.count >= 2, "\(item.name)")
          #expect(
            board.occurrences(
              of: String(repeating: String(letter), count: 3), along: item.runDirections) == 0,
            "\(item.name)")
        }
      }
    }
  }
}
