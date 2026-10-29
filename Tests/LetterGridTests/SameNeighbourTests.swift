import Testing

@testable import LetterGrid

struct SameNeighbourTests {
  private let weights: [String: Double] = ["a": 8, "e": 12, "t": 9, "s": 6, "u": 4, "q": 0.1]
  private let words = ["TUBA", "SEAT", "MUST"]

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
