import Testing

@testable import LetterGrid

struct SameNeighbourTests {
  private let weights: [String: Double] = ["a": 8, "e": 12, "t": 9, "s": 6, "u": 4, "q": 0.1]
  private let words = ["TUBA", "SEAT", "MUST"]

  @Test func theDefaultWeightLeavesBoardsAsTheyWere() throws {
    let plain = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7),
      rules: [.straight([.right, .down])],
      filler: Filler(weights: try LetterWeights(weights)),
      limits: PlacementLimits(downWords: 1...2)
    )
    let explicit = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7),
      rules: [.straight([.right, .down])],
      filler: Filler(weights: try LetterWeights(weights, sameNeighbour: 1)),
      limits: PlacementLimits(downWords: 1...2)
    )

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
