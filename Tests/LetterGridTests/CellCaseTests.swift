import Testing

@testable import LetterGrid

struct CellCaseTests {
  @Test func aLetterWithALongerCapitalKeepsItsCell() {
    #expect("երևան".cellUppercased == "ԵՐևԱՆ")
    #expect("straße".cellUppercased == "STRAßE")
    #expect("ու".cellUppercased == "ՈՒ")
  }

  @Test func fillerKeepsALetterWithALongerCapital() throws {
    let filler = try LetterWeights(["ե": 1, "և": 1, "ր": 1])
    var random = SeededRandom(seed: 1)

    #expect(filler.letterCount == 3)
    #expect(Set(filler.orderedLetters(using: &random)) == ["Ե", "և", "Ր"])
  }

  @Test func aWordWithALongerCapitalTakesOneCellPerLetter() throws {
    let generator = BoardGenerator(
      columns: 6, rows: 6, directions: [.right, .down],
      filler: try LetterWeights(["ա": 1, "ն": 1, "ս": 1, "տ": 1, "կ": 1]))
    let request = try generator.request(for: ["երևան", "ևս"])
    let board = generator.board(for: request, seed: 7)

    #expect(request.words == ["ԵՐևԱՆ", "ևՍ"])
    #expect(board.occurrences(of: "ԵՐևԱՆ", along: [.right, .down]) == 1)
    #expect(board.placements.map(\.cells.count).sorted() == [2, 5])
  }
}
