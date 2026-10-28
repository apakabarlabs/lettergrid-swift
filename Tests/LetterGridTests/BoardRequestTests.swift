import LetterGrid
import Testing

struct BoardRequestTests {
  @Test func anEmptyTargetListCannotBecomeAPlayableRequest() throws {
    let generator = BoardGenerator(
      columns: 5, rows: 5, directions: [.right], filler: try LetterWeights(["x": 1]))
    #expect(throws: BoardGenerator.Failure.noRoom(words: [], columns: 5, rows: 5)) {
      try generator.request(for: [])
    }
  }

  @Test func aPreparedRequestRetainsItsGenerationSettings() throws {
    let request = try BoardGenerator(
      columns: 3, rows: 4, directions: [.down],
      filler: LetterWeights(["x": 1, "y": 1, "z": 1, "q": 1]),
      downWords: 2...2, attempts: 0
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

  @Test func aDictionaryCanBeSuppliedAfterPreparingTheWords() throws {
    let filler = try LetterWeights(["a": 1000, "b": 1])
    let generator = BoardGenerator(
      columns: 5, rows: 5, directions: [.right, .down], filler: filler)
    let withDictionary = BoardGenerator(
      columns: 5, rows: 5, directions: [.right, .down], filler: filler, dictionary: ["AAA"])
    let request = try generator.request(for: ["CAT", "DOG"])

    let board = request.board(seed: 7, dictionary: ["aaa"])

    #expect(board == (try withDictionary.board(for: ["CAT", "DOG"], seed: 7)))
    #expect(board.strayWords(of: ["AAA"], along: [.right, .down]).isEmpty)
  }

  @Test(arguments: [0, -1])
  func invalidDimensionsAreRejectedBeforePreparingARequest(_ dimension: Int) throws {
    let filler = try LetterWeights(["x": 1])
    let generators = [
      BoardGenerator(columns: dimension, rows: 5, directions: [.down], filler: filler),
      BoardGenerator(columns: 5, rows: dimension, directions: [.right], filler: filler),
    ]
    for generator in generators {
      #expect(throws: BoardGenerator.Failure.invalidConfiguration) {
        try generator.request(for: ["CAT"])
      }
    }
  }

  @Test func invalidLimitsAndDirectionsAreRejectedBeforePreparingARequest() throws {
    let filler = try LetterWeights(["x": 1])
    let generators = [
      BoardGenerator(columns: 5, rows: 5, directions: [], filler: filler),
      BoardGenerator(columns: 5, rows: 5, directions: [.right], filler: filler, downWords: -1...1),
      BoardGenerator(
        columns: 5, rows: 5, directions: [.right], filler: filler, layoutsPerAttempt: 0),
      BoardGenerator(columns: 5, rows: 5, directions: [.right], filler: filler, attempts: -1),
      BoardGenerator(
        columns: 5, rows: 5, directions: [.right], filler: filler, fillsPerAttempt: -1),
    ]
    for generator in generators {
      #expect(throws: BoardGenerator.Failure.invalidConfiguration) {
        try generator.request(for: ["CAT"])
      }
    }
  }
}
