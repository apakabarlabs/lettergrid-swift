import Testing

@testable import LetterGrid

struct BandedBoardTests {
  private let alphabet = Array("ABCDEFGH")
  private let directionSets: [[Direction]] = [
    [.right], [.down], [.right, .down], [.right, .down, .downRight],
    [.right, .down, .downRight, .downLeft], [.downRight, .downLeft],
    [.left], [.up], [.right, .left], [.down, .up], [.upLeft, .upRight],
    Direction.allCases,
  ]

  private func generator(
    directions: [Direction], downWords: ClosedRange<Int>
  ) throws -> BoardGenerator {
    var weights = Dictionary(uniqueKeysWithValues: alphabet.map { (String($0), 1.0) })
    weights["z"] = 0.5
    return BoardGenerator(
      columns: 7, rows: 7, directions: directions, filler: try LetterWeights(weights),
      dictionary: Set(alphabet.flatMap { a in alphabet.map { b in String([a, b, a]) } }),
      downWords: downWords, attempts: 0)
  }

  private func words(using random: inout SeededRandom) -> [String] {
    (0..<Int.random(in: 1...3, using: &random)).map { _ in
      String(
        (0..<Int.random(in: 2...6, using: &random)).map { _ in
          alphabet.randomElement(using: &random) ?? "A"
        })
    }
  }

  @Test func everyAcceptedRequestGetsABoardWithEachWordExactlyOnce() throws {
    var random = SeededRandom(seed: 2026)
    var built = 0
    for directions in directionSets {
      for downWords in [0...2, 1...2] {
        let generator = try generator(directions: directions, downWords: downWords)
        for _ in 0..<150 {
          let words = words(using: &random)
          let first: Direction? =
            Bool.random(using: &random) ? nil : directions.randomElement(using: &random)
          let request: BoardRequest
          do {
            request = try generator.request(for: words, firstDirection: first)
          } catch {
            continue
          }
          let board = generator.board(for: request, seed: random.next())
          built += 1
          #expect(board.columns == 7)
          #expect(board.rows >= 7)
          #expect(board.placements.map(\.word) == request.words)
          for word in request.words {
            #expect(board.occurrences(of: word, along: directions) == 1, "\(request.words)")
          }
          for placement in board.placements {
            #expect(directions.contains(placement.direction))
            #expect(board.text(along: placement.cells) == placement.word)
          }
          if let first { #expect(board.placements.first?.direction == first) }
          #expect(
            downWords.contains(board.placements.filter(\.direction.isVertical).count)
              || !directions.contains(where: \.isVertical))
        }
      }
    }
    #expect(built > 500)
  }

  @Test func downWordsStandSideBySideSoTheBoardIsOnlyAsTallAsTheLongest() throws {
    let directions: [Direction] = [.right, .down, .downRight]
    let generator = try generator(directions: directions, downWords: 2...2)
    let request = try generator.request(
      for: ["ABCDEF", "BADCFE", "CAFEBD"], firstDirection: .downRight)

    let board = generator.board(for: request, seed: 7)

    #expect(board.rows == 13)
    #expect(board.placements.filter { $0.direction == .down }.map(\.start.column) == [0, 2])
    for word in request.words {
      #expect(board.occurrences(of: word, along: directions) == 1)
    }
  }

  @Test func aWordInsideAnotherIsRejectedBecauseItWouldReadTwice() throws {
    let generator = try generator(directions: [.right, .down], downWords: 0...2)

    #expect(throws: BoardGenerator.Failure.self) {
      try generator.request(for: ["CAB", "CABBA"])
    }
  }

  @Test func wordsThatUseEveryFillerLetterAreRejected() throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down],
      filler: try LetterWeights(["a": 1, "b": 1]))

    #expect(throws: BoardGenerator.Failure.self) {
      try generator.request(for: ["AB", "BBA"])
    }
  }

  @Test func theCleanSearchStillDecidesWhenItSucceeds() throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down],
      filler: try LetterWeights(["a": 8, "e": 12, "t": 9, "s": 6, "q": 0.1]),
      dictionary: ["SAT", "TEA", "EAT", "SEA"])
    let request = try generator.request(for: ["house", "water", "cat"])

    for seed in UInt64(1)...20 {
      let board = generator.board(for: request, seed: seed)
      #expect(board.rows == 7)
      #expect(board.strayWords(of: ["SAT", "TEA", "EAT", "SEA"], along: [.right, .down]).isEmpty)
    }
  }
}
