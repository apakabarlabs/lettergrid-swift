import LetterGrid
import Testing

struct BoardRequestTests {
  @Test func anEmptyTargetListCannotBecomeAPlayableRequest() throws {
    let generator = BoardGenerator(
      size: BoardSize(columns: 5, rows: 5),
      rules: [.straight([.right])],
      filler: Filler(weights: try LetterWeights(["x": 1]))
    )
    #expect(throws: BoardGenerator.Failure.noRoom(words: [], columns: 5, rows: 5)) {
      try generator.request(for: [])
    }
  }

  @Test func aPreparedRequestRetainsItsGenerationSettings() throws {
    let request = try BoardGenerator(
      size: BoardSize(columns: 3, rows: 4),
      rules: [.straight([.down])],
      filler: Filler(weights: LetterWeights(["x": 1, "y": 1, "z": 1, "q": 1])),
      limits: PlacementLimits(downWords: 2...2)
    ).request(for: ["CAT", "DOG"])

    let board = request.board(seed: 42)

    #expect(board.columns == 3)
    #expect(board.rows >= 4)
    #expect(board.placements.map(\.direction) == [.down, .down])
    #expect(board.placements.map(\.word) == request.words)
    for word in request.words {
      #expect(board.occurrences(of: word, along: [.down]) == 1)
    }
  }

  @Test(arguments: [0, -1])
  func invalidDimensionsAreRejectedBeforePreparingARequest(_ dimension: Int) throws {
    let filler = try LetterWeights(["x": 1])
    let generators = [
      BoardGenerator(
        size: BoardSize(columns: dimension, rows: 5),
        rules: [.straight([.down])],
        filler: Filler(weights: filler)
      ),
      BoardGenerator(
        size: BoardSize(columns: 5, rows: dimension),
        rules: [.straight([.right])],
        filler: Filler(weights: filler)
      ),
    ]
    for generator in generators {
      #expect(throws: BoardGenerator.Failure.invalidConfiguration) {
        try generator.request(for: ["CAT"])
      }
    }
  }

  @Test func invalidQuotasAndDirectionsAreRejectedBeforePreparingARequest() throws {
    let filler = try LetterWeights(["x": 1])
    let generators = [
      BoardGenerator(
        size: BoardSize(columns: 5, rows: 5),
        rules: [.straight([])],
        filler: Filler(weights: filler)
      ),
      BoardGenerator(
        size: BoardSize(columns: 5, rows: 5),
        rules: [.straight([.right])],
        filler: Filler(weights: filler),
        limits: PlacementLimits(downWords: -1...1)
      ),
    ]
    for generator in generators {
      #expect(throws: BoardGenerator.Failure.invalidConfiguration) {
        try generator.request(for: ["CAT"])
      }
    }
  }
}
