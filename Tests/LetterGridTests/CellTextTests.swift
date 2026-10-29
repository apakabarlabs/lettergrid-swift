import Foundation
import Testing
import Yams

@testable import LetterGrid

struct CellTextTests {
  private struct Case: Decodable {
    let name: String
    let text: String
    let cells: [String]
    let letters: [Bool]
    let hintOrder: [Int]
  }

  @Test func textBecomesTheCellsEveryPortAgreesOn() throws {
    let url = try #require(
      Bundle.module.url(forResource: "cell-text", withExtension: "yaml", subdirectory: "Fixtures"))
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    for item in cases {
      let word = item.text.cellUppercased
      let cells = word.map(String.init)
      let scalars = cells.map { $0.unicodeScalars.map(\.value) }
      let composed = cells.map { $0.precomposedStringWithCanonicalMapping.unicodeScalars }
      #expect(cells == item.cells, "\(item.name)")
      #expect(scalars == composed.map { $0.map(\.value) }, "\(item.name)")
      #expect(word.map(\.isLetter) == item.letters, "\(item.name)")
      #expect(HintOrder.anyButFirst.letterIndices(of: word) == item.hintOrder, "\(item.name)")
    }
  }
}
