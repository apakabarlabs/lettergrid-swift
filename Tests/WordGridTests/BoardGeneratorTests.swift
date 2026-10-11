import Testing

@testable import WordGrid

struct BoardGeneratorTests {
  private let filler = try! LetterWeights(["a": 8, "e": 12, "t": 9, "s": 6, "q": 0.1])
  private let words = ["house", "water", "cat", "tree", "plan"]

  private func generator(columns: Int = 7, rows: Int = 7) -> BoardGenerator {
    BoardGenerator(columns: columns, rows: rows, directions: [.right, .down], filler: filler)
  }

  @Test func placesEveryWordExactlyOnce() throws {
    let board = try generator().board(for: words, seed: 42)

    for word in words.map({ $0.uppercased() }) {
      #expect(board.occurrences(of: word, along: [.right, .down]) == 1)
    }
    #expect(board.placements.map(\.word) == words.map { $0.uppercased() })
    for placement in board.placements {
      #expect(board.text(along: placement.cells) == placement.word)
    }
  }

  @Test func fillsEveryCellWithALetter() throws {
    let board = try generator().board(for: words, seed: 7)

    #expect(board.rows == 7)
    #expect(board.columns == 7)
    let letters = board.letters.joined()
    #expect(letters.allSatisfy { $0.isLetter })
  }

  @Test func theSameSeedGivesTheSameBoard() throws {
    let first = try generator().board(for: words, seed: 99)
    let second = try generator().board(for: words, seed: 99)

    #expect(first == second)
  }

  @Test func aWordLongerThanTheBoardHasNoRoom() {
    #expect(throws: BoardGenerator.Failure.self) {
      try generator(columns: 4, rows: 4).board(for: ["elephant"], seed: 1)
    }
  }
}
