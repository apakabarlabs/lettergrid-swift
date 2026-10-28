import Testing

@testable import LetterGrid

struct SameNeighbourTests {
  private let weights: [String: Double] = ["a": 8, "e": 12, "t": 9, "s": 6, "u": 4, "q": 0.1]
  private let words = ["TUBA", "SEAT", "MUST"]

  private func repeatedNeighbours(sameNeighbour: Double) throws -> Int {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down],
      filler: try LetterWeights(weights, sameNeighbour: sameNeighbour), downWords: 1...2,
      generationVersion: .v0p18)
    let request = try generator.request(for: words)
    var repeats = 0
    for seed in 1...40 {
      let board = request.board(seed: UInt64(seed))
      let hidden = Set(board.placements.flatMap(\.cells))
      for row in 0..<board.rows {
        for column in 0..<board.columns {
          let cell = Cell(row: row, column: column)
          for next in [
            Cell(row: row, column: column + 1), Cell(row: row + 1, column: column),
            Cell(row: row + 1, column: column + 1), Cell(row: row + 1, column: column - 1),
          ] where board.contains(next) && !(hidden.contains(cell) && hidden.contains(next)) {
            if board[cell] == board[next] { repeats += 1 }
          }
        }
      }
    }
    return repeats
  }

  @Test func aSmallSameNeighbourWeightSeparatesEqualLetters() throws {
    let plain = try repeatedNeighbours(sameNeighbour: 1)
    let separated = try repeatedNeighbours(sameNeighbour: 0.2)

    #expect(separated * 2 < plain, "plain \(plain), separated \(separated)")
  }

  @Test func theDefaultWeightLeavesBoardsAsTheyWere() throws {
    let plain = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down], filler: try LetterWeights(weights),
      downWords: 1...2)
    let explicit = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down],
      filler: try LetterWeights(weights, sameNeighbour: 1), downWords: 1...2)

    #expect(
      try plain.request(for: words).board(seed: 3)
        == explicit.request(for: words).board(seed: 3))
  }

  @Test(arguments: [0.0, -0.5, 1.5])
  func aWeightOutsideZeroToOneIsRejected(_ sameNeighbour: Double) {
    #expect(throws: LetterWeights.Failure.sameNeighbourOutsideFraction(sameNeighbour)) {
      try LetterWeights(["a": 1], sameNeighbour: sameNeighbour)
    }
  }
}
