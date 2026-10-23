import LetterGrid
import Testing

struct FallbackNeighbourTests {
  private func horizontalRepeats(sameNeighbour: Double) throws -> Int {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down],
      filler: try LetterWeights(["x": 8, "y": 12, "z": 9, "q": 6], sameNeighbour: sameNeighbour),
      downWords: 1...2, attempts: 0)
    return try (1...40).reduce(0) { total, seed in
      let board = try generator.board(for: ["TUBA", "SEAT", "MUST"], seed: UInt64(seed))
      return total
        + board.letters.reduce(0) { count, row in
          count + zip(row, row.dropFirst()).filter { $0 == $1 }.count
        }
    }
  }

  @Test func fallbackBoardsApplyTheSameNeighbourPenalty() throws {
    let plain = try horizontalRepeats(sameNeighbour: 1)
    let separated = try horizontalRepeats(sameNeighbour: 0.02)

    #expect(separated < plain, "plain \(plain), separated \(separated)")
  }
}
